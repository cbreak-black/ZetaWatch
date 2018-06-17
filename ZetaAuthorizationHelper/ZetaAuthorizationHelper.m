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

- (NSString *)findCommand:(NSString*)command
{
	NSFileManager * manager = [NSFileManager defaultManager];
	for (NSString * prefix in self.prefixPaths)
	{
		NSString * commandPath = [prefix stringByAppendingString:command];
		if ([manager fileExistsAtPath:commandPath])
		{
			return commandPath;
		}
	}
	@throw [NSException exceptionWithName:@"CommandNotFound"
								   reason:@"Command not Found" userInfo:nil];
}

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		// Set up our XPC listener to handle requests on our Mach service.
		self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperToolMachServiceName];
		self->_listener.delegate = self;
		self.prefixPaths = @[@"/usr/local/bin/", @"/usr/local/sbin/"];
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

- (NSTask*)runCommand:(NSString *)command withArguments:(NSArray<NSString*>*)arguments
		 withReply:(void (^)(NSError *))reply
{
	@try
	{
		NSTask * task = [[NSTask alloc] init];
		task.launchPath = [self findCommand:command];;
		task.arguments = arguments;
		task.terminationHandler = ^(NSTask * task)
		{
			if (task.terminationStatus == 0)
			{
				reply(nil);
			}
			else
			{
				reply([NSError errorWithDomain:@"ZFSCLIError" code:task.terminationStatus userInfo:nil]);
			}
		};
		NSPipe * pipe = [NSPipe pipe];
		task.standardInput = pipe;
		[task launch];
		NSLog(@"runCommand: %@ %@", command, arguments);
		return task;
	}
	@catch(NSException * ex)
	{
		NSMutableDictionary * info = [NSMutableDictionary dictionary];
		[info setValue:ex.name forKey:@"ExceptionName"];
		[info setValue:ex.reason forKey:@"ExceptionReason"];
		[info setValue:ex.callStackReturnAddresses forKey:@"ExceptionCallStackReturnAddresses"];
		[info setValue:ex.callStackSymbols forKey:@"ExceptionCallStackSymbols"];
		[info setValue:ex.userInfo forKey:@"ExceptionUserInfo"];

		NSError * error = [[NSError alloc] initWithDomain:@"ZFSCLIError" code:-1 userInfo:info];
		reply(error);
	}
	return nil;
}

- (void)importPools:(NSDictionary *)importData authorization:(NSData *)authData
		  withReply:(void (^)(NSError *))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		[self runCommand:@"zpool" withArguments:@[@"import", @"-a"] withReply:reply];
	}
	else
	{
		reply(error);
	}
}

- (void)mountFilesystems:(NSDictionary *)mountData authorization:(NSData *)authData
			   withReply:(void (^)(NSError *))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		NSMutableArray * arguments = [[NSMutableArray alloc] initWithCapacity:8];
		[arguments addObject:@"mount"];
		NSString * key = [mountData objectForKey:@"key"];
		NSString * fs = [mountData objectForKey:@"filesystem"];
		if (key)
			[arguments addObjectsFromArray:@[@"-l", @"-o", @"keylocation=prompt"]];
		if (fs)
			[arguments addObject:fs];
		else
			[arguments addObject:@"-a"];
		if (key)
		{
			// Hacky send-password-once-no-matter-how-often-it-is-needed
			NSTask * task = [self runCommand:@"zfs" withArguments:arguments withReply:reply];
			NSPipe * pipe = task.standardInput;
			NSFileHandle * o = pipe.fileHandleForWriting;
			[o writeData:[key dataUsingEncoding:NSUTF8StringEncoding]];
			[o closeFile];
		}
		else
		{
			[self runCommand:@"zfs" withArguments:arguments withReply:reply];
		}
	}
	else
	{
		reply(error);
	}
}

- (void)unmountFilesystems:(NSDictionary *)mountData authorization:(NSData *)authData
				 withReply:(void (^)(NSError *))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		NSMutableArray * arguments = [[NSMutableArray alloc] initWithCapacity:8];
		[arguments addObject:@"unmount"];
		NSString * fs = [mountData objectForKey:@"filesystem"];
		if (fs)
			[arguments addObject:fs];
		else
			[arguments addObject:@"-a"];
		[self runCommand:@"zfs" withArguments:arguments withReply:reply];
	}
	else
	{
		reply(error);
	}
}

- (void)scrubPool:(NSDictionary *)poolData authorization:(NSData *)authData
		withReply:(void (^)(NSError *))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
	}
	else
	{
		reply(error);
	}
}

@end
