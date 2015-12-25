//
//  ZetaMenuDelegate.m
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.20.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted
//  provided that the conditions of the "3-Clause BSD" license described in the BSD.LICENSE file are met.
//  Additional licensing options are described in the README file.
//

#import "ZetaMenuDelegate.h"

#include "ZFSUtils.hpp"

@interface ZetaMenuDelegate ()
{
	NSMutableArray * _poolMenus;

	// ZFS
	zfs::LibZFSHandle _zfsHandle;
	std::vector<zfs::ZPool> _pools;
}

@end

@implementation ZetaMenuDelegate

- (id)init
{
	if (self = [super init])
	{
		_poolMenus = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	[self clearPoolMenu:menu];
	[self createPoolMenu:menu];
}

- (void)createPoolMenu:(NSMenu*)menu
{
	NSInteger poolMenuIdx = [menu indexOfItemWithTag:ZPoolAnchorMenuTag];
	if (poolMenuIdx < 0)
		return;
	[self refreshPools];
	NSInteger poolItemRootIdx = poolMenuIdx + 1;
	NSUInteger poolIdx = 0;
	for (auto && pool: _pools)
	{
		zpool_status_t status = pool.status();
		NSString * poolLine = [NSString stringWithFormat:@"%s (%s)", pool.name(), zfs::to_string(status)];
		NSMenuItem * poolItem = [[NSMenuItem alloc] initWithTitle:poolLine action:NULL keyEquivalent:@""];
		[menu insertItem:poolItem atIndex:poolItemRootIdx + poolIdx];
		[_poolMenus addObject:poolItem];
		++poolIdx;
	}
}

- (void)clearPoolMenu:(NSMenu*)menu
{
	for (NSMenuItem * poolMenu in _poolMenus)
	{
		[menu removeItem:poolMenu];
	}
	[_poolMenus removeAllObjects];
}

- (void)refreshPools
{
	_pools = zfs::zpool_list(_zfsHandle);
}

@end
