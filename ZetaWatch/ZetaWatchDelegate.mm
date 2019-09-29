//
//  ZetaWatchDelegate.mm
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.20.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted
//  provided that the conditions of the "3-Clause BSD" license described in the BSD.LICENSE file are met.
//  Additional licensing options are described in the README file.
//

#import "ZetaWatchDelegate.h"

#import "ZetaMainMenu.h"
#import "ZetaKeyLoader.h"

#import "ZFSUtils.hpp"

#import <Sparkle/Sparkle.h>

@interface ZetaWatchDelegate ()
{
	NSStatusItem * _statusItem;
}

@property (weak) IBOutlet NSMenu * zetaMenu;
@property (weak) IBOutlet ZetaKeyLoader * zetaKeyLoaderDelegate;
@property (weak) IBOutlet ZetaPoolWatcher * poolWatcher;
@property (weak) IBOutlet SUUpdater * updater;

@end

@implementation ZetaWatchDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Menu Item
	NSStatusBar * bar = [NSStatusBar systemStatusBar];
	_statusItem = [bar statusItemWithLength:NSSquareStatusItemLength];
	NSImage * zetaImage = [NSImage imageNamed:@"Zeta"];
	[zetaImage setTemplate:YES];
	_statusItem.button.image = zetaImage;
	_statusItem.menu = _zetaMenu;
	_zetaKeyLoaderDelegate.statusItem = _statusItem;
	// User Defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
		@"autoUnlock": @YES,
		@"autoImport": @YES,
		@"useKeychain": @NO,
	}];
	// Watcher
	[[self poolWatcher] checkForChanges];
	// User Notification Center Delegate
	[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	try
	{
		// Update Feed URL to the one matching the current ZFS version, even if
		// ZetaWatch was not compiled for it.
		auto version = zfs::LibZFSHandle::version();
		NSString * feedString = [NSString stringWithFormat:
			@"https://zetawatch.the-color-black.net/download/%i.%i/appcast.xml",
								 version.major, version.minor];
		NSURL * feedURL = [NSURL URLWithString:feedString];
		[self.updater setFeedURL:feedURL];
		// TODO: Check for compatibility
	}
	catch (std::exception const & e)
	{
		NSLog(@"Error querying ZFS Version: %s", e.what());
		// Disable auto update
		[self.updater setAutomaticallyChecksForUpdates:NO];
		[self.updater setAutomaticallyDownloadsUpdates:NO];
	}
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
	 shouldPresentNotification:(NSUserNotification *)notification
{
	return YES;
}

@end
