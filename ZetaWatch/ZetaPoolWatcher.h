//
//  ZetaPoolWatcher.h
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.31.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted
//  provided that the conditions of the "3-Clause BSD" license described in the BSD.LICENSE file are met.
//  Additional licensing options are described in the README file.
//

#import <Cocoa/Cocoa.h>

#include "ZFSUtils.hpp"

#include <string>

@protocol ZetaPoolWatcherDelegate <NSObject>

- (void)newPoolDetected:(zfs::ZPool const &)pool;

@optional
- (void)errorDetectedInPool:(std::string const &)pool;
- (void)errorDetected:(std::string const &)error;

@end

@interface ZetaPoolWatcher : NSObject

- (id)init;

- (void)checkForChanges;
- (std::vector<zfs::ZPool>)pools;

- (void)keepAwake;
- (void)stopKeepingAwake;

@property (strong) NSMutableArray<id<ZetaPoolWatcherDelegate>> * delegates;

@end
