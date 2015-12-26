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
#include "ZFSStrings.hpp"

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

NSMenu * createVdevMenu(zfs::ZPool const & pool)
{
	NSMenu * vdevMenu = [[NSMenu alloc] init];
	try
	{
		zfs::NVList config = pool.config();
		auto vdevtree = config.lookup<zfs::NVList>(ZPOOL_CONFIG_VDEV_TREE);
		auto children = vdevtree.lookup<std::vector<zfs::NVList>>(ZPOOL_CONFIG_CHILDREN);
		for (auto && vdev: children)
		{
			auto type = vdev.lookup<std::string>(ZPOOL_CONFIG_TYPE);
			[vdevMenu addItemWithTitle:[NSString stringWithUTF8String:type.c_str()]
								action:nullptr keyEquivalent:@""];
			auto children = vdev.lookup<std::vector<zfs::NVList>>(ZPOOL_CONFIG_CHILDREN);
			for (auto && device: children)
			{
				// See vdev_stat_t for layout
				auto stat = device.lookup<std::vector<uint64_t>>(ZPOOL_CONFIG_VDEV_STATS);
				auto path = device.lookup<std::string>(ZPOOL_CONFIG_PATH);
				auto found = path.find_last_of('/');
				if (found != std::string::npos && found + 1 < path.size())
					path = path.substr(found + 1);
				NSString * devLine = [NSString stringWithFormat:@"  %s (%@)",
					path.c_str(),
					zfs::to_localized_nsstring(vdev_state_t(stat[1]), vdev_aux_t(stat[2]))
				];
				[vdevMenu addItemWithTitle:devLine
									action:nullptr keyEquivalent:@""];
			}
		}
	}
	catch (std::exception const & e)
	{
		[vdevMenu addItemWithTitle:@"Error reading pool configuration"
							action:nullptr keyEquivalent:@""];
	}
	return vdevMenu;
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
		NSString * poolLine = [NSString stringWithFormat:@"%s (%@)", pool.name(), zfs::to_localized_nsstring(status)];
		NSMenuItem * poolItem = [[NSMenuItem alloc] initWithTitle:poolLine action:NULL keyEquivalent:@""];
		NSMenu * vdevMenu = createVdevMenu(pool);
		[poolItem setSubmenu:vdevMenu];
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
