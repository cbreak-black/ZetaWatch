//
//  ZetaKeyLoader.m
//  ZetaWatch
//
//  Created by cbreak on 19.06.16.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaKeyLoader.h"

#import <Security/Security.h>

#include "ZFSWrapper/ZFSUtils.hpp"

#include <deque>
#include <type_traits>

@interface ZetaKeyLoader ()
{
	std::deque<NSString*> filesystems;
	bool unlockInProgress;
	zfs::LibZFSHandle libZFS;
}

@end

@implementation ZetaKeyLoader

- (void)awakeFromNib
{
	unlockInProgress = false;
	if (self.poolWatcher)
	{
		[self.poolWatcher.delegates addObject:self];
	}
}

- (void)unlockFileSystem:(NSString*)filesystem
{
	[self addFilesystemToUnlock:filesystem];
	if (![_popover isShown])
		[self show];
}

- (void)show
{
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	NSView * positioningView = [_statusItem button];
	[_popover showRelativeToRect:NSMakeRect(0, 0, 0, 0)
						  ofView:positioningView
				   preferredEdge:NSRectEdgeMinY];
}

- (IBAction)loadKey:(id)sender
{
	if (!unlockInProgress)
	{
		NSString * pass = [_passwordField stringValue];
		NSString * filesystem = [self representedFilesystem];
		bool storeInKeychain = [_useKeychainCheckbox state] == NSControlStateValueOn;
		[self clearPassword];
		[self loadKey:pass forFilesystem:filesystem storeInKeychain:storeInKeychain];
	}
}

- (void)loadKey:(NSString*)password forFilesystem:(NSString*)filesystem
		  storeInKeychain:(bool)storeInKeychain
{
	[self showActionInProgress:NSLocalizedString(@"Loading Key...", @"LoadingKeyStatus")];
	NSDictionary * opts = @{@"filesystem": filesystem, @"key": password};
	[_authorization loadKeyForFilesystem:opts withReply:^(NSError * error)
	 {
		 if ([self handleLoadKeyReply:error] && storeInKeychain)
		 {
			 [self storePassword:password forFilesystem:filesystem];
		 }
	 }];
}

- (void)loadKeyFileForFilesystem:(NSString*)filesystem
{
	[self showActionInProgress:NSLocalizedString(@"Loading Keyfile...", @"LoadingKeyFileStatus")];
	NSDictionary * opts = @{@"filesystem": filesystem};
	[_authorization loadKeyForFilesystem:opts withReply:^(NSError * error)
	 {
		 if (![self handleLoadKeyReply:error])
		 {
			 // Try stored key next
			 [self tryUnlockFromStoredPassword:filesystem];
		 }
	 }];
}

- (IBAction)skipFileSystem:(id)sender
{
	if (!unlockInProgress)
		[self advanceFileSystem];
}

- (bool)handleLoadKeyReply:(NSError*)error
{
	[self completeAction];
	if (error)
	{
		if ([error.domain isEqualToString:@"ZFSKeyError"])
		{
			[self showError:[error localizedDescription]];
		}
		else
		{
			[self notifyErrorFromHelper:error];
			[self advanceFileSystem];
			return true;
		}
	}
	else
	{
		[self advanceFileSystem];
		return true;
	}
	return false;
}

- (void)showActionInProgress:(NSString*)action
{
	[_statusField setStringValue:action];
	[_statusField setTextColor:[NSColor textColor]];
	[_statusField setHidden:NO];
	[_progressIndicator startAnimation:self];
	[_loadButton setEnabled:NO];
	[_skipButton setEnabled:NO];
	unlockInProgress = true;
}

- (void)completeAction
{
	[_progressIndicator stopAnimation:self];
	[self hideStatus];
	[_loadButton setEnabled:YES];
	[_skipButton setEnabled:YES];
	unlockInProgress = false;
}

- (void)showError:(NSString*)error
{
	[_statusField setStringValue:error];
	[_statusField setTextColor:[NSColor systemRedColor]];
	[_statusField setHidden:NO];
}

- (void)hideStatus
{
	[_statusField setHidden:YES];
}

- (void)clearPassword
{
	// The password is copied all over the place by the view, the dictionary
	// and the IPC, so trying to clear it is probably a waste of time.
	[_passwordField setStringValue:@""];
}

- (BOOL)popoverShouldDetach:(NSPopover *)popover
{
	return YES;
}

- (void)tryUnlock:(NSString*)filesystem
{
	auto fs = libZFS.filesystem([filesystem UTF8String]);
	if (fs.keyLocation() == zfs::ZFileSystem::KeyLocation::uri)
	{
		[self loadKeyFileForFilesystem:filesystem];
	}
	else
	{
		[self tryUnlockFromStoredPassword:filesystem];
	}
}

- (void)tryUnlockFromStoredPassword:(NSString*)filesystem
{
	auto fs = libZFS.filesystem([filesystem UTF8String]);
	if (fs.keyLocation() == zfs::ZFileSystem::KeyLocation::uri)
	{
		[self loadKeyFileForFilesystem:filesystem];
	}
	else
	{
		NSString * password = [self retrievePasswordForFilesystem:filesystem];
		if (password)
		{
			[self loadKey:password forFilesystem:filesystem storeInKeychain:false];
		}
	}
}

- (NSString*)retrievePasswordForFilesystem:(NSString*)filesystem
{
	void const * keys[] = {
		kSecClass,
		kSecAttrService,
		kSecMatchLimit,
		kSecReturnData,
	};
	void const * values[] = {
		kSecClassGenericPassword,
		(__bridge CFStringRef)filesystem,
		kSecMatchLimitOne,
		kCFBooleanTrue,
	};
	static_assert(std::extent_v<decltype(keys)> == std::extent_v<decltype(values)>);
	constexpr size_t attributeCount = std::extent_v<decltype(keys)>;
	CFDictionaryRef attributes =  CFDictionaryCreate(nullptr,
		&keys[0], &values[0], attributeCount,
		&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	void const * data = nullptr;
	OSStatus result = SecItemCopyMatching(attributes, &data);
	CFRelease(attributes);
	if (result != errSecSuccess)
	{
		return nullptr;
	}
	NSString * password = [[NSString alloc] initWithData:CFBridgingRelease((CFDataRef)data)
encoding:NSUTF8StringEncoding];
	return password;
}

- (bool)deletePasswordForFilesystem:(NSString*)filesystem
{
	void const * keys[] = {
		kSecClass,
		kSecAttrService,
		kSecMatchLimit,
	};
	void const * values[] = {
		kSecClassGenericPassword,
		(__bridge CFStringRef)filesystem,
		kSecMatchLimitAll,
	};
	static_assert(std::extent_v<decltype(keys)> == std::extent_v<decltype(values)>);
	constexpr size_t attributeCount = std::extent_v<decltype(keys)>;
	CFDictionaryRef attributes =  CFDictionaryCreate(nullptr,
		&keys[0], &values[0], attributeCount,
		&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	OSStatus result = SecItemDelete(attributes);
	CFRelease(attributes);
	if (result != errSecSuccess)
	{
		return false;
	}
	return true;
}

- (bool)storePassword:(NSString*)password forFilesystem:(NSString*)filesystem
{
	[self deletePasswordForFilesystem:filesystem];
	NSData * passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
	NSString * label = [NSString stringWithFormat:@"ZetaWatch Password for ZFS filesystem %@", filesystem];
	void const * keys[] = {
		kSecClass,
		kSecAttrLabel,
		kSecAttrService,
		kSecValueData,
	};
	void const * values[] = {
		kSecClassGenericPassword,
		(__bridge CFStringRef)label,
		(__bridge CFStringRef)filesystem,
		(__bridge CFDataRef)passwordData,
	};
	static_assert(std::extent_v<decltype(keys)> == std::extent_v<decltype(values)>);
	constexpr size_t attributeCount = std::extent_v<decltype(keys)>;
	CFDictionaryRef attributes =  CFDictionaryCreate(nullptr,
		&keys[0], &values[0], attributeCount,
		&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	OSStatus result = SecItemAdd(attributes, nil);
	CFRelease(attributes);
	if (result != errSecSuccess)
	{
		CFStringRef errorString = SecCopyErrorMessageString(result, nullptr);
		NSError * error = [NSError errorWithDomain:NSOSStatusErrorDomain
											  code:result userInfo:
		@{
			NSLocalizedDescriptionKey: CFBridgingRelease(errorString)
		}];
		[self notifyErrorFromHelper:error];
		return false;
	}
	return true;
}

- (void)addFilesystemToUnlock:(NSString*)filesystem
{
	filesystems.push_back(filesystem);
	if (filesystems.size() == 1)
	{
		[self updateFileSystem];
		[self tryUnlock:filesystem];
	}
}

- (NSString*)representedFilesystem
{
	if (filesystems.empty())
		return nullptr;
	return filesystems.front();
}

- (void)advanceFileSystem
{
	filesystems.pop_front();
	[self updateFileSystem];
	if (filesystems.empty())
	{
		[_popover performClose:self];
	}
	else
	{
		[self tryUnlock:filesystems.front()];
	}
}

- (void)updateFileSystem
{
	if (filesystems.empty())
	{
		[_queryField setStringValue:@""];
	}
	else
	{
		[_queryField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Enter the password for %@", @"Password Query"), filesystems.front()]];
		bool useKeychain = [[NSUserDefaults standardUserDefaults] boolForKey:@"useKeychain"];
		[_useKeychainCheckbox setState:useKeychain ? NSControlStateValueOn : NSControlStateValueOff];
	}
}

- (BOOL)popoverShouldClose:(NSPopover *)popover
{
	if (!filesystems.empty())
	{
		filesystems.pop_front();
		[self updateFileSystem];
		if (filesystems.empty())
			return YES;
		return NO;
	}
	else
	{
		return YES;
	}
}

- (void)popoverWillShow:(NSNotification *)notification
{
}

- (void)popoverDidClose:(NSNotification *)notification
{
	[self clearPassword];
	[_passwordField abortEditing];
	[self hideStatus];
	filesystems.clear();
	[self updateFileSystem];
}


- (void)newPoolDetected:(const zfs::ZPool &)pool
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autoUnlock"])
	{
		for (auto & fs : pool.allFileSystems())
		{
			auto [encRoot, isRoot] = fs.encryptionRoot();
			auto keyStatus = fs.keyStatus();
			if (isRoot && keyStatus == zfs::ZFileSystem::KeyStatus::unavailable)
			{
				NSString * fsName = [NSString stringWithUTF8String:fs.name()];
				[self unlockFileSystem:fsName];
			}
		}
	}
}

@end
