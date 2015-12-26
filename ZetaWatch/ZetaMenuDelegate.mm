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

NSString * formatErrorStat(vdev_stat_t stat)
{
	NSString * status = zfs::to_localized_nsstring(vdev_state_t(stat.vs_state), vdev_aux_t(stat.vs_aux));
	NSString * errors = nil;
	if (stat.vs_read_errors == 0 && stat.vs_write_errors == 0 && stat.vs_checksum_errors == 0)
	{
		errors = NSLocalizedString(@"No Errors", @"Format vdev_stat_t");
	}
	else
	{
		NSString * format = NSLocalizedString(@"%ll Read Errors, %ll Write Errors, %ll Checksum Errors", @"Format vdev_stat_t");
		errors = [NSString stringWithFormat:format, stat.vs_read_errors, stat.vs_write_errors, stat.vs_checksum_errors];
	}
	return [NSString stringWithFormat:@"%@, %@", status, errors];
}

NSMenu * createVdevMenu(zfs::ZPool const & pool)
{
	NSMenu * vdevMenu = [[NSMenu alloc] init];
	try
	{
		auto vdevs = pool.vdevs();
		for (auto && vdev: vdevs)
		{
			auto type = zfs::vdevType(vdev);
			[vdevMenu addItemWithTitle:[NSString stringWithUTF8String:type.c_str()]
								action:nullptr keyEquivalent:@""];
			auto devices = zfs::vdevChildren(vdev);
			for (auto && device: devices)
			{
				auto stat = zfs::vdevStat(device);
				auto path = zfs::vdevPath(device);
				NSString * devLine = [NSString stringWithFormat:@"  %s (%@)",
					path.c_str(), formatErrorStat(stat)
				];
				[vdevMenu addItemWithTitle:devLine
									action:nullptr keyEquivalent:@""];
			}
		}
	}
	catch (std::exception const & e)
	{
		[vdevMenu addItemWithTitle:NSLocalizedString(@"Error reading pool configuration", @"")
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
