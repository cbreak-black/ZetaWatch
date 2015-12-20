//
//  ZetaWatchDelegate.m
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.20.
//  Copyright © 2015 the-color-black.net. All rights reserved.
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
	_statusItem = [bar statusItemWithLength:NSVariableStatusItemLength];
	[_statusItem setTitle: NSLocalizedString(@"Zeta",@"")];
	[_statusItem setMenu:_zetaMenu];
	[_zetaMenu setDelegate:_menuDelegate];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

@end
