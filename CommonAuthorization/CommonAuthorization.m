//
//  CommonAuthorization.m
//  ZetaWatch
//
//  Created by cbreak on 18.01.01.
//  Copyright © 2018 the-color-black.net. All rights reserved.
//

#import "CommonAuthorization.h"

#import "ZetaAuthorizationHelperProtocol.h"

@implementation CommonAuthorization

static NSString * kKeyAuthRightName    = @"authRightName";
static NSString * kKeyAuthRightDefault = @"authRightDefault";
static NSString * kKeyAuthRightDesc    = @"authRightDescription";

/*!
 +commandInfo returns a dictionary that represents everything we need to know about the
 authorized commands supported by the app.  Each dictionary key is the string form of
 the command selector.  The corresponding object is a dictionary that contains three items:

 o kKeyAuthRightName is the name of the authorization right itself.  This is used by
 both the app (when creating rights and when pre-authorizing rights) and by the tool
 (when doing the final authorization check).

 o kKeyAuthRightDefault is the default right specification, used by the app to when
 it needs to create the default right specification.  This is commonly a string contacting
 a rule a name, but it can potentially be more complex.  See the discussion of the
 rightDefinition parameter of AuthorizationRightSet.

 o kKeyAuthRightDesc is a user-visible description of the right. This is used by the
 app when it needs to create the default right specification. Actually, string is used
 to look up a localized version of the string in "CommonAuthorization.strings".
 This file is generated by the "genstrings" cli application.
 */
+ (NSDictionary *)commandInfo
{
	static dispatch_once_t sOnceToken;
	static NSDictionary * sCommandInfo;

	dispatch_once(&sOnceToken,^{
		NSDictionary * dictStop =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.stop",
		  kKeyAuthRightDefault: @kAuthorizationRuleClassAllow,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying stop its helper.",
											   @"prompt shown when user is required to authorize helper termination"
											   )
		  };
		NSDictionary * dictImport =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.import",
		  kKeyAuthRightDefault: @kAuthorizationRuleClassAllow,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to import a pool.",
											   @"prompt shown when user is required to authorize a zpool import"
											   )
		  };
		NSDictionary * dictExport =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.export",
		  kKeyAuthRightDefault: @kAuthorizationRuleClassAllow,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to export a pool.",
											   @"prompt shown when user is required to authorize a zpool export"
											   )
		  };
		NSDictionary * dictMount =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.mount",
		  kKeyAuthRightDefault: @kAuthorizationRuleClassAllow,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to mount a filesystem.",
											   @"prompt shown when user is required to authorize a zfs mount"
											   )
		  };
		NSDictionary * dictUnmount =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.unmount",
		  kKeyAuthRightDefault: @kAuthorizationRuleClassAllow,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to unmount a filesystem.",
											   @"prompt shown when user is required to authorize a zfs unmount"
											   )
		  };
		NSDictionary * dictSnapshot =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.snapshot",
		  kKeyAuthRightDefault: @kAuthorizationRuleClassAllow,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to snapshot a filesystem.",
											   @"prompt shown when user is required to authorize a zfs snapshot"
											   )
		  };
		NSDictionary * dictRollback =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.rollback",
		  kKeyAuthRightDefault: @kAuthorizationRuleAuthenticateAsAdmin,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to roll back a filesystem.",
											   @"prompt shown when user is required to authorize a zfs rollback"
											   )
		  };
		NSDictionary * dictClone =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.clone",
		  kKeyAuthRightDefault: @kAuthorizationRuleAuthenticateAsAdmin,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to clone a snapshot.",
											   @"prompt shown when user is required to authorize a zfs clone"
											   )
		  };
		NSDictionary * dictCreate =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.create",
		  kKeyAuthRightDefault: @kAuthorizationRuleAuthenticateAsAdmin,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to create a filesystem.",
											   @"prompt shown when user is required to authorize a zfs create"
											   )
		  };
		NSDictionary * dictDestroy =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.destroy",
		  kKeyAuthRightDefault: @kAuthorizationRuleAuthenticateAsAdmin,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to destroy a filesystem.",
											   @"prompt shown when user is required to authorize a zfs destroy"
											   )
		  };
		NSDictionary * dictKey =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.key",
		  kKeyAuthRightDefault: @kAuthorizationRuleClassAllow,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to operate on an encryption key.",
											   @"prompt shown when user is required to authorize a crypto key operation"
											   )
		  };
		NSDictionary * dictScrub =
		@{
		  kKeyAuthRightName: @"net.the-color-black.ZetaWatch.scrub",
		  kKeyAuthRightDefault: @kAuthorizationRuleClassAllow,
		  kKeyAuthRightDesc: NSLocalizedString(
											   @"ZetaWatch is trying to scrub a pool.",
											   @"prompt shown when user is required to authorize a zpool scrub"
											   )
		  };

		sCommandInfo =
		@{
		  NSStringFromSelector(@selector(stopHelperWithAuthorization:withReply:)): dictStop,
		  NSStringFromSelector(@selector(importPools:authorization:withReply:)): dictImport,
		  NSStringFromSelector(@selector(importablePoolsWithAuthorization:withReply:)): dictImport,
		  NSStringFromSelector(@selector(exportPools:authorization:withReply:)): dictExport,
		  NSStringFromSelector(@selector(mountFilesystems:authorization:withReply:)): dictMount,
		  NSStringFromSelector(@selector(unmountFilesystems:authorization:withReply:)): dictUnmount,
		  NSStringFromSelector(@selector(snapshotFilesystem:authorization:withReply:)):
			  dictSnapshot,
		  NSStringFromSelector(@selector(rollbackFilesystem:authorization:withReply:)):
			  dictRollback,
		  NSStringFromSelector(@selector(cloneSnapshot:authorization:withReply:)):
			  dictClone,
		  NSStringFromSelector(@selector(createFilesystem:authorization:withReply:)):
			  dictCreate,
		  NSStringFromSelector(@selector(createVolume:authorization:withReply:)):
			  dictCreate,
		  NSStringFromSelector(@selector(destroy:authorization:withReply:)):
			  dictDestroy,
		  NSStringFromSelector(@selector(loadKeyForFilesystem:authorization:withReply:)): dictKey,
		  NSStringFromSelector(@selector(unloadKeyForFilesystem:authorization:withReply:)): dictKey,
		  NSStringFromSelector(@selector(scrubPool:authorization:withReply:)): dictScrub,
		  };
	});

	return sCommandInfo;
}

+ (NSString *)authorizationRightForCommand:(SEL)command
{
	return [self commandInfo][NSStringFromSelector(command)][kKeyAuthRightName];
}

+ (void)enumerateRightsUsingBlock:(void (^)(NSString * authRightName, id authRightDefault, NSString * authRightDesc))block
{
	[self.commandInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL * stop)
	{
		NSDictionary * commandDict = (NSDictionary *) obj;
		assert([commandDict isKindOfClass:[NSDictionary class]]);

		NSString * authRightName = [commandDict objectForKey:kKeyAuthRightName];
		assert([authRightName isKindOfClass:[NSString class]]);

		id authRightDefault = [commandDict objectForKey:kKeyAuthRightDefault];
		assert(authRightDefault != nil);

		NSString * authRightDesc = [commandDict objectForKey:kKeyAuthRightDesc];
		assert([authRightDesc isKindOfClass:[NSString class]]);

		block(authRightName, authRightDefault, authRightDesc);
	}];
}

+ (void)setupAuthorizationRights:(AuthorizationRef)authRef
// See comment in header.
{
	assert(authRef != NULL);
	[CommonAuthorization enumerateRightsUsingBlock:^(NSString * authRightName, id authRightDefault, NSString * authRightDesc)
	{
		// First get the right.  If we get back errAuthorizationDenied that means there's
		// no current definition, so we add our default one.

		OSStatus blockErr = AuthorizationRightGet([authRightName UTF8String], NULL);
		if (blockErr == errAuthorizationDenied)
		{
			blockErr = AuthorizationRightSet(authRef, [authRightName UTF8String],
											 (__bridge CFTypeRef)authRightDefault,
											 (__bridge CFStringRef)authRightDesc,
											 NULL, CFSTR("CommonAuthorization")
											 );
			assert(blockErr == errAuthorizationSuccess);
		}
	}];
}

@end
