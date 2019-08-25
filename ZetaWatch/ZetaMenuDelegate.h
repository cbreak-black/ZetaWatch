//
//  ZetaMenuDelegate.h
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.20.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted
//  provided that the conditions of the "3-Clause BSD" license described in the BSD.LICENSE file are met.
//  Additional licensing options are described in the README file.
//

#import <Cocoa/Cocoa.h>

#import "ZetaPoolWatcher.h"
#import "ZetaBaseDelegate.h"
#import "ZetaPoolWatcher.h"
#import "ZetaAutoImporter.h"
#import "ZetaKeyLoaderDelegate.h"

@class ZetaNotificationCenter;

enum ZetaMenuTags
{
	ZPoolAnchorMenuTag = 100,
	ActionAnchorMenuTag = 101
};

@interface ZetaMenuDelegate : ZetaBaseDelegate <NSMenuDelegate,ZetaPoolWatcherDelegate>

@property (weak) IBOutlet ZetaPoolWatcher * poolWatcher;
@property (weak) IBOutlet ZetaKeyLoaderDelegate * zetaKeyLoader;
@property (weak) IBOutlet ZetaNotificationCenter * notificationCenter;

- (IBAction)mountAllFilesystems:(id)sender;

@end
