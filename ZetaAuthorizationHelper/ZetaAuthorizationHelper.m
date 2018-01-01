//
//  ZetaAuthorizationHelper.m
//  ZetaAuthorizationHelper
//
//  Created by cbreak on 18.01.01.
//  Copyright © 2018 the-color-black.net. All rights reserved.
//

#import "ZetaAuthorizationHelper.h"
#import "ZetaAuthorizationHelperProtocol.h"

#import "CommonAuthorization.h"

@interface ZetaAuthorizationHelper () <NSXPCListenerDelegate, ZetaAuthorizationHelperProtocol>

@property (atomic, strong, readwrite) NSXPCListener * listener;

@end

@implementation ZetaAuthorizationHelper

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		// Set up our XPC listener to handle requests on our Mach service.
		self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperToolMachServiceName];
		self->_listener.delegate = self;
	}
	return self;
}

- (void)run
{
	// Tell the XPC listener to start processing requests.
	[self.listener resume];
	// Run the run loop forever.
	[[NSRunLoop currentRunLoop] run];
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
	assert(listener == self.listener);
	assert(newConnection != nil);

	newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ZetaAuthorizationHelperProtocol)];
	newConnection.exportedObject = self;
	[newConnection resume];

	return YES;
}

- (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command
{
	NSError * error = nil;
	AuthorizationRef authRef = NULL;

	assert(command != nil);

	// First check that authData looks reasonable.
	error = nil;
	if ((authData == nil) || ([authData length] != sizeof(AuthorizationExternalForm)))
	{
		error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
	}

	// Create an authorization ref from that the external form data contained within.
	if (error == nil)
	{
		OSStatus err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);

		// Authorize the right associated with the command.
		if (err == errAuthorizationSuccess)
		{
			AuthorizationItem oneRight = { NULL, 0, NULL, 0 };
			AuthorizationRights rights   = { 1, &oneRight };

			oneRight.name = [[CommonAuthorization authorizationRightForCommand:command] UTF8String];
			assert(oneRight.name != NULL);

			err = AuthorizationCopyRights(authRef, &rights, NULL,
				kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
				NULL);
		}
		if (err != errAuthorizationSuccess)
		{
			error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		}
	}

	if (authRef != NULL)
	{
		OSStatus junk = AuthorizationFree(authRef, 0);
		assert(junk == errAuthorizationSuccess);
	}

	return error;
}

- (void)getVersionWithReply:(void (^)(NSError * error, NSString *))reply
{
	reply(nil, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
}

- (void)importPools:(NSDictionary *)importData authorization:(NSData *)authData
		  withReply:(void (^)(NSError *))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
	}
	reply(error);
}

- (void)mountFilesystems:(NSDictionary *)mountData authorization:(NSData *)authData
			   withReply:(void (^)(NSError *))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
	}
	reply(error);
}

- (void)scrubPool:(NSDictionary *)poolData authorization:(NSData *)authData
		withReply:(void (^)(NSError *))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
	}
	reply(error);
}

@end
