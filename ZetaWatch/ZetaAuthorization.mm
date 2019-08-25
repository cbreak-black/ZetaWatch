//
//  ZetaAuthoized.m
//  ZetaWatch
//
//  Created by cbreak on 17.12.31.
//  Copyright © 2017 the-color-black.net. All rights reserved.
//

#import "ZetaAuthorization.h"

#import "ZetaAuthorizationHelperProtocol.h"
#import "CommonAuthorization.h"

#import "ZetaNotificationCenter.h"

#include <ServiceManagement/ServiceManagement.h>

#include <dispatch/dispatch.h>

@interface ZetaAuthorization ()
{
	AuthorizationRef _authRef;
}

@property (atomic, copy, readwrite) NSData * authorization;
@property (atomic, strong, readwrite) NSXPCConnection * helperToolConnection;

@end

@implementation ZetaAuthorization

- (void)awakeFromNib
{
	[self connectToAuthorization];
	[self installIfNeeded];
}

-(void)connectToAuthorization
{
	// Create our connection to the authorization system.
	//
	// If we can't create an authorization reference then the app is not going
	// to be able to do anything requiring authorization. Generally this only
	// happens when you launch the app in some wacky, and typically unsupported,
	// way. We continue with self->_authRef as NULL, which will cause all
	// authorized operations to fail.

	AuthorizationExternalForm extForm = {};
	OSStatus err = AuthorizationCreate(NULL, NULL, 0, &self->_authRef);
	if (err == errAuthorizationSuccess)
	{
		err = AuthorizationMakeExternalForm(self->_authRef, &extForm);
	}
	if (err == errAuthorizationSuccess)
	{
		self.authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
	}

	// If we successfully connected to Authorization Services, add definitions
	// for our default rights (unless they're already in the database).

	if (self->_authRef)
	{
		[CommonAuthorization setupAuthorizationRights:self->_authRef];
	}
}

-(void)install
{
	// Install the helper tool into the system location. As of 10.12 this is
	// /Library/LaunchDaemons/<TOOL> and /Library/PrivilegedHelperTools/<TOOL>
	Boolean success = NO;
	CFErrorRef error = nil;

	success = SMJobBless(kSMDomainSystemLaunchd,
						 CFSTR("net.the-color-black.ZetaAuthorizationHelper"),
						 self->_authRef, &error);

	if (success)
	{
	}
	else
	{
		NSLog(@"Error installing helper tool: %@\n", error);
		CFRelease(error);
	}
}

- (void)connectToHelperTool
{
	assert([NSThread isMainThread]);
	if (self.helperToolConnection == nil)
	{
		self.helperToolConnection = [[NSXPCConnection alloc] initWithMachServiceName:kHelperToolMachServiceName options:NSXPCConnectionPrivileged];
		self.helperToolConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ZetaAuthorizationHelperProtocol)];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
		// We can ignore the retain cycle warning because a) the retain taken by the
		// invalidation handler block is released by us setting it to nil when the block
		// actually runs, and b) the retain taken by the block passed to -addOperationWithBlock:
		// will be released when that operation completes and the operation itself is deallocated
		// (notably self does not have a reference to the NSBlockOperation).
		self.helperToolConnection.invalidationHandler = ^{
			// If the connection gets invalidated then, on the main thread, nil out our
			// reference to it.  This ensures that we attempt to rebuild it the next time around.
			self.helperToolConnection.invalidationHandler = nil;
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				self.helperToolConnection = nil;
			}];
		};
#pragma clang diagnostic pop
		[self.helperToolConnection resume];
	}
}

- (void)installIfNeeded
{
	// Ensure that there's a helper tool connection in place.
	[self connectToHelperTool];
	id proxy = [self.helperToolConnection remoteObjectProxyWithErrorHandler:
				^(NSError * proxyError)
	{
		// Install on proxy error
		dispatch_async(dispatch_get_main_queue(), ^(){
			// Install if there's a proxy error
			[self install];
		});
	}];

	[proxy getVersionWithReply:^(NSError * error, NSString * helperVersion)
	 {
		 // Install if there's no valid helper version (because of error)
		 if (error)
		 {
			 dispatch_async(dispatch_get_main_queue(), ^(){
				 [self install];
			 });
			 return;
		 }
		 NSString * localVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		 // Install if the versions don't match exactly
		 if (![localVersion isEqualToString:helperVersion])
		 {
			 dispatch_async(dispatch_get_main_queue(), ^(){
				 [self install];
			 });
			 return;
		 }
	 }];
}

- (void)executeWhenConnected:(void(^)(NSError * error, id proxy))task
{
	// Ensure that there's a helper tool connection in place.
	[self connectToHelperTool];
	id proxy = [self.helperToolConnection remoteObjectProxyWithErrorHandler:
		^(NSError * proxyError)
	{
		task(proxyError, nil);
	}];

	task(nil, proxy);
}

- (void)dispatchReply:(void(^)(void))reply
{
	[self performSelectorOnMainThread:@selector(dispatchReplyMainThread:) withObject:reply waitUntilDone:FALSE];
}

- (void)dispatchReplyMainThread:(void(^)(void))reply
{
	reply();
}

- (void)getVersionWithReply:(void (^)(NSError * error, NSString *))reply
{
	[self executeWhenConnected:^(NSError * error, id proxy)
	 {
		 if (error)
		 {
			 [self dispatchReply:^(){ reply(error, nil); }];
		 }
		 else
		 {
			 [proxy getVersionWithReply:^(NSError * error, NSString * version)
			  {
				  [self dispatchReply:^(){ reply(error, version); }];
			  }];
		 }
	 }];
}

- (void)importPools:(NSDictionary *)importData
		  withReply:(void(^)(NSError * error))reply
{
	NSString * target = importData[@"poolGUID"];
	if (target == nil)
		target = @"all pools";
	ZetaNotification * notification = [self startNotificationForAction:
		NSLocalizedString(@"Importing", @"Importing Action") withTarget:target];
	[self executeWhenConnected:^(NSError * error, id proxy)
	 {
		 if (error)
		 {
			 [self dispatchReply:^(){
				 reply(error);
				 [self stopNotification:notification withError:error];
			 }];
		 }
		 else
		 {
			 [proxy importPools:importData authorization:self.authorization
					  withReply:^(NSError * error)
			  {
				  [self dispatchReply:^(){
					  reply(error);
					  [self stopNotification:notification withError:error];
				  }];
			  }];
		 }
	 }];
}

- (void)importablePoolsWithReply:(void(^)(NSError * error, NSArray * importablePools))reply
{
	[self executeWhenConnected:^(NSError * error, id proxy)
	 {
		 if (error)
		 {
			 [self dispatchReply:^(){ reply(error, nil); }];
		 }
		 else
		 {
			 [proxy importablePoolsWithAuthorization:self.authorization
										   withReply:^(NSError * error, NSArray * importablePools)
			  {
				  [self dispatchReply:^(){ reply(error, importablePools); }];
			  }];
		 }
	 }];
}

- (void)exportPools:(NSDictionary *)exportData
		  withReply:(void(^)(NSError * error))reply
{
	NSString * target = exportData[@"pool"];
	if (target == nil)
		target = NSLocalizedString(@"all pools", @"All Pools");
	ZetaNotification * notification = [self startNotificationForAction:
		NSLocalizedString(@"Exporting", @"Exporting Action") withTarget:target];
	[self executeWhenConnected:^(NSError * error, id proxy)
	 {
		 if (error)
		 {
			 [self dispatchReply:^(){
				 reply(error);
				 [self stopNotification:notification withError:error];
			 }];
		 }
		 else
		 {
			 [proxy exportPools:exportData authorization:self.authorization
					  withReply:^(NSError * error)
			  {
				  [self dispatchReply:^(){
					  reply(error);
					  [self stopNotification:notification withError:error];
				  }];
			  }];
		 }
	 }];
}

- (void)mountFilesystems:(NSDictionary *)mountData
			   withReply:(void(^)(NSError * error))reply
{
	NSString * target = mountData[@"filesystem"];
	if (target == nil)
		target = NSLocalizedString(@"all filesystems", @"All Filesystems");
	ZetaNotification * notification = [self startNotificationForAction:
		NSLocalizedString(@"Mounting", @"Mounting Action") withTarget:target];
	[self executeWhenConnected:^(NSError * error, id proxy)
	 {
		 if (error)
		 {
			 [self dispatchReply:^(){
				 reply(error);
				 [self stopNotification:notification withError:error];
			 }];
		 }
		 else
		 {
			 [proxy mountFilesystems:mountData authorization:self.authorization
						   withReply:^(NSError * error)
			  {
				  [self dispatchReply:^(){
					  reply(error);
					  [self stopNotification:notification withError:error];
				  }];
			  }];
		 }
	 }];
}

- (void)unmountFilesystems:(NSDictionary *)mountData
			   withReply:(void(^)(NSError * error))reply
{
	NSString * target = mountData[@"filesystem"];
	if (target == nil)
		target = NSLocalizedString(@"all filesystems", @"All Filesystems");
	ZetaNotification * notification = [self startNotificationForAction:
		NSLocalizedString(@"Unmounting", @"Unmounting Action") withTarget:target];
	[self executeWhenConnected:^(NSError * error, id proxy)
	 {
		 if (error)
		 {
			 [self dispatchReply:^(){
				 reply(error);
				 [self stopNotification:notification withError:error];
			 }];
		 }
		 else
		 {
			 [proxy unmountFilesystems:mountData authorization:self.authorization
							 withReply:^(NSError * error)
			  {
				  [self dispatchReply:^(){
					  reply(error);
					  [self stopNotification:notification withError:error];
				  }];
			  }];
		 }
	 }];
}

- (void)loadKeyForFilesystem:(NSDictionary *)data
					withReply:(void(^)(NSError * error))reply
{
	NSString * target = data[@"filesystem"];
	if (target == nil)
		target = NSLocalizedString(@"all filesystems", @"All Filesystems");
	ZetaNotification * notification = [self startNotificationForAction:
		NSLocalizedString(@"Loading Key for", @"LoadKey Action") withTarget:target];
	[self executeWhenConnected:^(NSError * error, id proxy)
	 {
		 if (error)
		 {
			 [self dispatchReply:^(){
				 reply(error);
				 [self stopNotification:notification withError:error];
			 }];
		 }
		 else
		 {
			 [proxy loadKeyForFilesystem:data authorization:self.authorization
							   withReply:^(NSError * error)
			  {
				  [self dispatchReply:^(){
					  reply(error);
					  [self stopNotification:notification withError:error];
				  }];
			  }];
		 }
	 }];
}

- (void)scrubPool:(NSDictionary *)poolData
		withReply:(void(^)(NSError * error))reply
{
	[self executeWhenConnected:^(NSError * error, id proxy)
	 {
		 if (error)
		 {
			 [self dispatchReply:^(){ reply(error); }];
		 }
		 else
		 {
			 [proxy scrubPool:poolData authorization:self.authorization
					withReply:^(NSError * error)
			  {
				  [self dispatchReply:^(){ reply(error); }];
			  }];
		 }
	 }];
}

- (ZetaNotification*)startNotificationForAction:(NSString*)action withTarget:(NSString*)target
{
	NSString * titleFormat = NSLocalizedString(@"%@ %@", @"Helper Status notification Title Format");
	NSString * title = [NSString stringWithFormat:titleFormat, action, target];
	return [self.notificationCenter startAction:title];
}

- (void)stopNotification:(ZetaNotification*)notification withError:(NSError*)error
{
	[self.notificationCenter stopAction:notification withError:error];
}

@end
