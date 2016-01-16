//
//  ZetaMenuDelegate.mm
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
#import "ZetaPoolWatcher.h"

#include "ZFSUtils.hpp"
#include "ZFSStrings.hpp"

@interface ZetaMenuDelegate ()
{
	NSMutableArray * _poolMenus;
	ZetaPoolWatcher * _watcher;
}

@end

@implementation ZetaMenuDelegate

- (id)init
{
	if (self = [super init])
	{
		_poolMenus = [[NSMutableArray alloc] init];
		_watcher = [[ZetaPoolWatcher alloc] init];
		_watcher.delegate = self;
	}
	return self;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	[self clearPoolMenu:menu];
	[self createPoolMenu:menu];
}

NSString * formatErrorStat(zfs::VDevStat stat)
{
	NSString * status = zfs::localized_describe_vdev_state_t(stat.state, stat.aux);
	NSString * errors = nil;
	if (stat.errorRead == 0 && stat.errorWrite == 0 && stat.errorChecksum == 0)
	{
		errors = NSLocalizedString(@"No Errors", @"Format vdev_stat_t");
	}
	else
	{
		NSString * format = NSLocalizedString(@"%llu Read Errors, %llu Write Errors, %llu Checksum Errors", @"Format vdev_stat_t");
		errors = [NSString stringWithFormat:format, stat.errorRead, stat.errorWrite, stat.errorChecksum];
	}
	return [NSString stringWithFormat:@"%@, %@", status, errors];
}

std::string genName(zfs::NVList const & vdev)
{
	auto type = zfs::vdevType(vdev);
	if (type == "file" || type == "disk")
		return zfs::vdevPath(vdev);
	else
		return type;
}

NSMenu * createVdevMenu(zfs::ZPool const & pool)
{
	NSMenu * vdevMenu = [[NSMenu alloc] init];
	try
	{
		auto vdevs = pool.vdevs();
		for (auto && vdev: vdevs)
		{
			auto stat = zfs::vdevStat(vdev);
			NSString * vdevLine = [NSString stringWithFormat:@"%s (%@)",
				genName(vdev).c_str(), formatErrorStat(stat)];
			[vdevMenu addItemWithTitle:vdevLine
								action:nullptr keyEquivalent:@""];
			auto devices = zfs::vdevChildren(vdev);
			for (auto && device: devices)
			{
				auto stat = zfs::vdevStat(device);
				NSString * devLine = [NSString stringWithFormat:@"  %s (%@)",
					genName(device).c_str(), formatErrorStat(stat)];
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
	NSInteger poolItemRootIdx = poolMenuIdx + 1;
	NSUInteger poolIdx = 0;
	for (auto && pool: [_watcher pools])
	{
		NSString * poolLine = [NSString stringWithFormat:@"%s (%@)",
			pool.name(), zfs::localized_describe_zpool_status_t(pool.status())];
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

- (void)errorDetectedInPool:(std::string const &)pool
{
	NSUserNotification * notification = [[NSUserNotification alloc] init];
	notification.title = NSLocalizedString(@"ZFS Pool Error", @"");
	NSString * errorFormat = NSLocalizedString(@"ZFS detected an error on pool %s.", @"");
	notification.informativeText = [NSString stringWithFormat:errorFormat, pool.c_str()];
	notification.hasActionButton = NO;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

@end
