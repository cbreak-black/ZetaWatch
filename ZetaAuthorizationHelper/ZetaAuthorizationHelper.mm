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

#include "ZFSWrapper/ZFSUtils.hpp"
#include "ZetaCPPUtils.hpp"

@interface ZetaAuthorizationHelper () <NSXPCListenerDelegate, ZetaAuthorizationHelperProtocol>
{
	zfs::LibZFSHandle _zfs;
}

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
		return error;
	}

	// Create an authorization ref from that the external form data contained within.
	auto extForm = static_cast<const AuthorizationExternalForm *>([authData bytes]);
	OSStatus err = AuthorizationCreateFromExternalForm(extForm, &authRef);

	// Authorize the right associated with the command.
	if (err == errAuthorizationSuccess)
	{
		AuthorizationItem oneRight = { NULL, 0, NULL, 0 };
		AuthorizationRights rights   = { 1, &oneRight };

		auto right = [CommonAuthorization authorizationRightForCommand:command];
		if (!right)
		{
			error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
			return error;
		}

		oneRight.name = [right UTF8String];

		err = AuthorizationCopyRights(authRef, &rights, NULL,
			kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
			NULL);
	}
	if (err != errAuthorizationSuccess)
	{
		error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
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
		std::vector<std::string> failures;
		try
		{
			NSNumber * pool = [importData objectForKey:@"poolGUID"];
			if (pool != nil)
			{
				auto importedPool = _zfs.import([pool unsignedLongLongValue]);
				importedPool.iterAllFileSystems([self,&failures](zfs::ZFileSystem fs)
				{
					if (!fs.automount())
						failures.emplace_back(_zfs.lastError());
					return 0;
				});
			}
			else
			{
				auto pools = _zfs.importAllPools();
				for (auto const & pool : pools)
				{
					pool.iterAllFileSystems([self,&failures](zfs::ZFileSystem fs)
					{
						if (!fs.automount())
							failures.emplace_back(_zfs.lastError());
						return 0;
					});
				}
			}
			if (failures.empty())
			{
				reply(nullptr);
			}
			else
			{
				NSDictionary * userInfo = @{
					NSLocalizedDescriptionKey: [NSString stringWithUTF8String:
						formatForHumans(failures).c_str()]
				};
				reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);

			}
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
	}
	else
	{
		reply(error);
	}
}

- (void)importablePoolsWithAuthorization:(NSData *)authData withReply:(void (^)(NSError *, NSArray *))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		try
		{
			auto pools = _zfs.importablePools();
			NSMutableArray * poolsArray = [[NSMutableArray alloc] initWithCapacity:pools.size()];
			for (auto const & pool : pools)
			{
				NSString * name = [NSString stringWithUTF8String:pool.name.c_str()];
				NSNumber * guid = [NSNumber numberWithUnsignedLongLong:pool.guid];
				NSNumber * status = [NSNumber numberWithUnsignedLongLong:pool.status];
				NSDictionary * poolDict =
				@{@"name": name, @"guid": guid, @"status": status};
				[poolsArray addObject:poolDict];
			}
			reply(nullptr, poolsArray);
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}], nullptr);
		}
	}
	else
	{
		reply(error, nullptr);
	}
}

- (void)exportPools:(NSDictionary *)exportData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		NSString * poolName = [exportData objectForKey:@"pool"];
		bool force = false;
		if (id o = [exportData objectForKey:@"force"])
			force = [o boolValue];
		if (!poolName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			auto pool = _zfs.pool(std::string(poolName.UTF8String));
			// Export Pool
			pool.exportPool(force);
			reply(nullptr);
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
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
		NSString * fsName = [mountData objectForKey:@"filesystem"];
		bool recursive = false;
		if (id o = [mountData objectForKey:@"recursive"])
			recursive = [o boolValue];
		if (!fsName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			std::vector<std::string> failures;
			auto fs = _zfs.filesystem([fsName UTF8String]);
			if (!fs.mount())
				failures.emplace_back(_zfs.lastError());
			if (recursive)
			{
				fs.iterAllFileSystems([self,&failures](zfs::ZFileSystem fs)
				{
					if (!fs.mount())
						failures.emplace_back(_zfs.lastError());
					return 0;
				});
			}
			if (failures.empty())
			{
				reply(nullptr);
			}
			else
			{
				NSDictionary * userInfo = @{
					NSLocalizedDescriptionKey: [NSString stringWithUTF8String:
						formatForHumans(failures).c_str()]
				};
				reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);
			}
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
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
		NSString * fsName = [mountData objectForKey:@"filesystem"];
		bool force = false;
		if (id o = [mountData objectForKey:@"force"])
			force = [o boolValue];
		bool recursive = false;
		if (id o = [mountData objectForKey:@"recursive"])
			recursive = [o boolValue];
		if (!fsName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			std::vector<std::string> failures;
			auto fs = _zfs.filesystem([fsName UTF8String]);
			if (recursive)
			{
				auto unmountSnap = [self,&failures,force](zfs::ZFileSystem snap)
				{
					if (!snap.unmount(force))
						failures.emplace_back(_zfs.lastError());
					return 0;
				};
				auto unmountFS = [self,&failures,force,&unmountSnap](zfs::ZFileSystem fs)
				{
					fs.iterSnapshots(unmountSnap);
					if (!fs.unmount(force))
						failures.emplace_back(_zfs.lastError());
					return 0;
				};
				fs.iterAllFileSystemsReverse(unmountFS);
				fs.iterSnapshots(unmountSnap);
			}
			if (!fs.unmount(force))
				failures.emplace_back(_zfs.lastError());
			if (failures.empty())
			{
				reply(nullptr);
			}
			else
			{
				NSDictionary * userInfo = @{
					NSLocalizedDescriptionKey: [NSString stringWithUTF8String:
						formatForHumans(failures).c_str()]
				};
				reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);
			}
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
	}
	else
	{
		reply(error);
	}
}

- (void)snapshotFilesystem:(NSDictionary *)fsData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		NSString * fsName = [fsData objectForKey:@"filesystem"];
		NSString * snapName = [fsData objectForKey:@"snapshot"];
		bool recursive = false;
		if (id o = [fsData objectForKey:@"recursive"])
			recursive = [o boolValue];
		if (!fsName || !snapName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			auto fs = _zfs.filesystem([fsName UTF8String]);
			if (fs.snapshot([snapName UTF8String], recursive))
			{
				reply(nullptr);
			}
			else
			{
				NSDictionary * userInfo = @{
					NSLocalizedDescriptionKey: [NSString stringWithUTF8String:_zfs.lastError().c_str()]
				};
				reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);
			}
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
	}
	else
	{
		reply(error);
	}
}

- (void)rollbackFilesystem:(NSDictionary *)fsData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		NSString * snapName = [fsData objectForKey:@"snapshot"];
		bool force = false;
		if (id o = [fsData objectForKey:@"force"])
			force = [o boolValue];
		if (!snapName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			auto snap = _zfs.filesystem([snapName UTF8String]);
			if (snap.rollback(force))
			{
				reply(nullptr);
			}
			else
			{
				NSDictionary * userInfo = @{
					NSLocalizedDescriptionKey: [NSString stringWithUTF8String:_zfs.lastError().c_str()]
				};
				reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);
			}
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
	}
	else
	{
		reply(error);
	}
}

- (void)cloneSnapshot:(NSDictionary *)fsData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		NSString * snapName = [fsData objectForKey:@"snapshot"];
		NSString * newFSName = [fsData objectForKey:@"newFilesystem"];
		if (!snapName || !newFSName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			std::string newFSNameStr = [newFSName UTF8String];
			auto snap = _zfs.filesystem([snapName UTF8String]);
			if (snap.clone(newFSNameStr))
			{
				auto newFS = _zfs.filesystem(newFSNameStr);
				if (newFS.mount())
				{
					reply(nullptr);
					return;
				}
			}
			NSDictionary * userInfo = @{
				NSLocalizedDescriptionKey: [NSString stringWithUTF8String:_zfs.lastError().c_str()]
			};
			reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
	}
	else
	{
		reply(error);
	}
}

- (void)createFilesystem:(NSDictionary *)fsData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
{
	reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Unimplemented"}]);
}

- (void)destroyFilesystem:(NSDictionary *)fsData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		NSString * fsName = [fsData objectForKey:@"filesystem"];
		bool recursive = false;
		if (id o = [fsData objectForKey:@"recursive"])
			recursive = [o boolValue];
		bool force = false;
		if (id o = [fsData objectForKey:@"force"])
			force = [o boolValue];
		if (!fsName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			auto fs = _zfs.filesystem([fsName UTF8String]);
			bool success = true;
			if (recursive)
			{
				success = fs.destroyRecursive(force);
			}
			else
			{
				auto dependents = fs.dependents();
				if (dependents.empty())
				{
					success = fs.destroy(force);
				}
				else
				{
					NSDictionary * userInfo = @{
						NSLocalizedDescriptionKey: @"Filesystem has Dependents"
					};
					reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);
					return;
				}
			}
			if (success)
			{
				reply(nullptr);
			}
			else
			{
				NSDictionary * userInfo = @{
					NSLocalizedDescriptionKey: [NSString stringWithUTF8String:_zfs.lastError().c_str()]
				};
				reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);
			}
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
	}
	else
	{
		reply(error);
	}
}

- (void)loadKeyForFilesystem:(NSDictionary *)loadData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		NSString * fsName = [loadData objectForKey:@"filesystem"];
		NSString * key = [loadData objectForKey:@"key"];
		if (!fsName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			auto fs = _zfs.filesystem([fsName UTF8String]);
			bool success = true;
			if (key)
			{
				success = fs.loadKey([key UTF8String]);
			}
			else if (fs.keyLocation() == zfs::ZFileSystem::KeyLocation::uri)
			{
				success = fs.loadKeyFile();
			}
			else
			{
				reply([NSError errorWithDomain:@"ZFSKeyError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Key"}]);
				return;
			}
			if (success)
			{
				std::vector<std::string> failures;
				// Encryption Root Filesystem itself
				if (!fs.automount())
					failures.emplace_back(_zfs.lastError());
				// All contained filesystems recursively
				fs.iterAllFileSystems([self,&failures](zfs::ZFileSystem fs)
				{
					if (!fs.automount())
						failures.emplace_back(_zfs.lastError());
					return 0;
				});
				if (failures.empty())
				{
					reply(nullptr);
				}
				else
				{
					NSDictionary * userInfo = @{
						NSLocalizedDescriptionKey: [NSString stringWithUTF8String:formatForHumans(failures).c_str()]
					};
					reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);
				}
			}
			else
			{
				NSDictionary * userInfo = @{
					NSLocalizedDescriptionKey: [NSString stringWithUTF8String:_zfs.lastError().c_str()]
				};
				reply([NSError errorWithDomain:@"ZFSKeyError" code:-1 userInfo:userInfo]);
			}
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
	}
	else
	{
		reply(error);
	}
}

- (void)unloadKeyForFilesystem:(NSDictionary *)unloadData authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
{
	NSError * error = [self checkAuthorization:authData command:_cmd];
	if (error == nil)
	{
		NSString * fsName = [unloadData objectForKey:@"filesystem"];
		if (!fsName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			std::vector<std::string> failures;
			auto fs = _zfs.filesystem([fsName UTF8String]);
			fs.iterAllFileSystemsReverse([self,&failures](zfs::ZFileSystem fs)
			{
				if (!fs.unmount())
					failures.emplace_back(_zfs.lastError());
				return 0;
			});
			if (!fs.unmount())
				failures.emplace_back(_zfs.lastError());
			if (failures.empty())
			{
				if (!fs.unloadKey())
					failures.emplace_back("Unload Key failed");
			}
			if (failures.empty())
			{
				reply(nullptr);
			}
			else
			{
				NSDictionary * userInfo = @{
					NSLocalizedDescriptionKey: [NSString stringWithUTF8String:
						formatForHumans(failures).c_str()]
				};
				reply([NSError errorWithDomain:@"ZFSError" code:-1 userInfo:userInfo]);
			}
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
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
		NSString * poolName = [poolData objectForKey:@"pool"];
		NSString * command = [poolData objectForKey:@"command"];
		if (!poolName)
		{
			reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing Arguments"}]);
			return;
		}
		try
		{
			auto pool = _zfs.pool(std::string(poolName.UTF8String));
			if (command)
			{
				if ([command isEqualToString:@"stop"])
					pool.scrubStop();
				else if ([command isEqualToString:@"pause"])
					pool.scrubPause();
				// No other commands are supported
				else
					reply([NSError errorWithDomain:@"ZFSArgError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid Scrub Command"}]);
			}
			else
			{
				pool.scrub();
			}
			reply(nullptr);
		}
		catch (std::exception const & e)
		{
			reply([NSError errorWithDomain:@"ZFSException" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}]);
		}
	}
	else
	{
		reply(error);
	}
}

@end
