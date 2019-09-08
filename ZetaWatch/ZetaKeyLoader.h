//
//  ZetaKeyLoader.h
//  ZetaWatch
//
//  Created by cbreak on 19.06.16.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZetaMenuBase.h"
#import "ZetaPoolWatcher.h"

@interface ZetaKeyLoader : ZetaMenuBase <NSPopoverDelegate,ZetaPoolWatcherDelegate>

@property (weak) NSStatusItem * statusItem;
@property (weak) IBOutlet NSPopover * popover;
@property (weak) IBOutlet NSSecureTextField * passwordField;
@property (weak) IBOutlet NSTextField * queryField;
@property (weak) IBOutlet NSTextField * statusField;
@property (weak) IBOutlet NSProgressIndicator * progressIndicator;

@property (weak) IBOutlet ZetaPoolWatcher * poolWatcher;

- (void)unlockFileSystem:(NSString*)filesystem;

- (IBAction)loadKey:(id)sender;
- (IBAction)skipFileSystem:(id)sender;

- (BOOL)popoverShouldDetach:(NSPopover *)popover;

@end