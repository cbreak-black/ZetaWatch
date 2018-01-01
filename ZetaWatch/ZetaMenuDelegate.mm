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
#import "ZetaAuthorization.h"

#include "ZFSUtils.hpp"
#include "ZFSStrings.hpp"

#include <type_traits>
#include <iomanip>
#include <sstream>

@interface ZetaMenuDelegate ()
{
	NSMutableArray * _poolMenus;
	ZetaPoolWatcher * _watcher;
	ZetaAuthorization * _authorization;
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
		_authorization = [[ZetaAuthorization alloc] init];
	}
	return self;
}

- (void)awakeFromNib
{
	[_authorization connectToAuthorization];
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	[self clearPoolMenu:menu];
	[self createPoolMenu:menu];
}

#pragma mark Formating

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

struct MetricPrefix
{
	uint64_t factor;
	char const * prefix;
};

MetricPrefix metricPrefixes[] = {
	{ 1000000000000000000, "E" },
	{    1000000000000000, "P" },
	{       1000000000000, "T" },
	{	       1000000000, "G" },
	{             1000000, "M" },
	{                1000, "k" },
};

size_t prefixCount = std::extent<decltype(metricPrefixes)>::value;

std::string formatPrefixedValue(uint64_t size)
{
	for (size_t p = 0; p < prefixCount; ++p)
	{
		if (size > metricPrefixes[p].factor)
		{
			double scaledSize = size / double(metricPrefixes[p].factor);
			std::stringstream ss;
			ss << std::setprecision(2) << std::fixed << scaledSize << " " << metricPrefixes[p].prefix;
			return ss.str();
		}
	}
	return std::to_string(size) + " ";
}

std::string formatBytes(uint64_t bytes)
{
	return formatPrefixedValue(bytes) + "B";
}

#pragma mark ZFS Inspection

NSMenu * createVdevMenu(zfs::ZPool const & pool)
{
	NSMenu * vdevMenu = [[NSMenu alloc] init];
	try
	{
		auto vdevs = pool.vdevs();
		for (auto && vdev: vdevs)
		{
			// VDev
			auto stat = zfs::vdevStat(vdev);
			NSString * vdevLine = [NSString stringWithFormat:@"%s (%@)",
				genName(vdev).c_str(), formatErrorStat(stat)];
			[vdevMenu addItemWithTitle:vdevLine
								action:nullptr keyEquivalent:@""];
			try
			{
				auto scrub = zfs::scanStat(vdev);
				if (scrub.state == zfs::ScanStat::scanning)
				{
					NSString * scanLine = [NSString stringWithFormat:@"    Scrub in Progress: %0.2f %% (%s out of %s)",
										   100.0*scrub.examined/scrub.toExamine,
										   formatBytes(scrub.examined).c_str(),
										   formatBytes(scrub.toExamine).c_str()];
					[vdevMenu addItemWithTitle:scanLine
										action:nullptr keyEquivalent:@""];
				}
			}
			catch (std::out_of_range const &)
			{
				// scan stat not-found errors are non-critical and can be ignored
			}
			// Children
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

#pragma mark ZFS Maintenance

- (IBAction)importAllPools:(id)sender
{
	[_authorization autoinstall];
}

- (IBAction)mountAllFilesystems:(id)sender
{

}

@end
