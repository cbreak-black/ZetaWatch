//
//  ZetaKeyLoaderDelegate.h
//  ZetaWatch
//
//  Created by cbreak on 19.06.16.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZetaBaseDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZetaKeyLoaderDelegate : ZetaBaseDelegate <NSPopoverDelegate>

@property (weak) IBOutlet NSPopover * popover;
@property (weak) IBOutlet NSSecureTextField * passwordField;
@property (weak) IBOutlet NSTextField * queryField;
@property (weak) IBOutlet NSTextField * errorField;
@property (nonatomic) NSString * representedFileSystem;

- (IBAction)loadKey:(id)sender;

- (BOOL)popoverShouldDetach:(NSPopover *)popover;

@end

NS_ASSUME_NONNULL_END
