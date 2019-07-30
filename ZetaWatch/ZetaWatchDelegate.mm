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

#import "ZetaMenuDelegate.h"
#import "ZetaKeyLoaderDelegate.h"

@interface ZetaWatchDelegate ()
{
	NSStatusItem * _statusItem;
}

@property (weak) IBOutlet NSWindow * window;
@property (weak) IBOutlet NSMenu * zetaMenu;
@property (weak) IBOutlet ZetaMenuDelegate * zetaMenuDelegate;
@property (weak) IBOutlet ZetaKeyLoaderDelegate * zetaKeyLoaderDelegate;

@end

@implementation ZetaWatchDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
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
		@"autoImport": @YES
	}];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

@end
