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

@interface ZetaPoolWatcher : NSObject
{
	// ZFS
	zfs::LibZFSHandle _zfsHandle;
	std::vector<zfs::ZPool> _pools;
}

- (id)init;
- (void)refreshPools;

- (std::vector<zfs::ZPool> const &)pools;

@end
