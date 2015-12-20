//
//  ZetaWatchDelegate.m
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.20.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//

#import "ZetaWatchDelegate.h"

@interface ZetaWatchDelegate ()
{
	NSStatusItem * _statusItem;
}

@property (weak) IBOutlet NSWindow * window;
@property (weak) IBOutlet NSMenu * zetaMenu;

@end

@implementation ZetaWatchDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSStatusBar *bar = [NSStatusBar systemStatusBar];

	_statusItem = [bar statusItemWithLength:NSVariableStatusItemLength];

	[_statusItem setTitle: NSLocalizedString(@"Zeta",@"")];

	[_statusItem setHighlightMode:YES];
	[_statusItem setMenu:_zetaMenu];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

@end
