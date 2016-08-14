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

@interface ZetaWatchDelegate ()
{
	ZetaMenuDelegate * _menuDelegate;
	NSStatusItem * _statusItem;
}

@property (weak) IBOutlet NSWindow * window;
@property (weak) IBOutlet NSMenu * zetaMenu;

@end

@implementation ZetaWatchDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	_menuDelegate = [[ZetaMenuDelegate alloc] init];
	NSStatusBar * bar = [NSStatusBar systemStatusBar];
	_statusItem = [bar statusItemWithLength:NSSquareStatusItemLength];
	NSImage * zetaImage = [NSImage imageNamed:@"Zeta"];
	[zetaImage setTemplate:YES];
	_statusItem.button.image = zetaImage;
	_statusItem.menu = _zetaMenu;
	_zetaMenu.delegate = _menuDelegate;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

@end
