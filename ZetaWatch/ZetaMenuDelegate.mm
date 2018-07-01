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

NSMenu * createFSMenu(zfs::ZFileSystem const & fs, ZetaMenuDelegate * delegate)
{
	NSMenu * fsMenu = [[NSMenu alloc] init];
	[fsMenu setAutoenablesItems:NO];
	if (fs.type() == zfs::ZFileSystem::filesystem)
	{
		NSString * fsName = [NSString stringWithUTF8String:fs.name()];
		NSMenuItem * item;
		auto [encRoot, isRoot] = fs.encryptionRoot();
		if (isRoot)
		{
			item = [fsMenu addItemWithTitle:@"Load Key"
									 action:@selector(loadKey:) keyEquivalent:@""];
			item.representedObject = fsName;
			item.target = delegate;
		}
		item = [fsMenu addItemWithTitle:@"Mount"
								 action:@selector(mountFilesystem:) keyEquivalent:@""];
		item.representedObject = fsName;
		item.target = delegate;
		item = [fsMenu addItemWithTitle:@"Unmount"
								 action:@selector(unmountFilesystem:) keyEquivalent:@""];
		item.representedObject = fsName;
		item.target = delegate;
	}
	return fsMenu;
}

NSString * formatStatus(zfs::ZFileSystem const & fs)
{
	char const * mountStatus = fs.mounted() ? "mounted" : "not mounted";
	char const * encStatus = "";
	switch (fs.keyStatus())
	{
		case zfs::ZFileSystem::none:
			encStatus = "";
			break;
		case zfs::ZFileSystem::unavailable:
			encStatus = ", locked";
			break;
		case zfs::ZFileSystem::available:
			encStatus = ", unlocked";
			break;
	}
	NSString * fsLine = [NSString stringWithFormat:@"%s (%s%s)",
						 fs.name(), mountStatus, encStatus];
	return fsLine;
}

NSMenu * createVdevMenu(zfs::ZPool const & pool, ZetaMenuDelegate * delegate)
{
	NSMenu * vdevMenu = [[NSMenu alloc] init];
	[vdevMenu setAutoenablesItems:NO];
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
			auto scrub = zfs::scanStat(vdev);
			if (scrub.state == zfs::ScanStat::scanning)
			{
				NSString * scanLine = [NSString stringWithFormat:@"Scrub in Progress: %0.2f %% (%s out of %s)",
									   100.0*scrub.examined/scrub.toExamine,
									   formatBytes(scrub.examined).c_str(),
									   formatBytes(scrub.toExamine).c_str()];
				NSMenuItem * item = [vdevMenu addItemWithTitle:scanLine
														action:nullptr keyEquivalent:@""];
				[item setIndentationLevel:1];
			}
			// Children
			auto devices = zfs::vdevChildren(vdev);
			for (auto && device: devices)
			{
				auto stat = zfs::vdevStat(device);
				NSString * devLine = [NSString stringWithFormat:@"%s (%@)",
					genName(device).c_str(), formatErrorStat(stat)];
				NSMenuItem * item = [vdevMenu addItemWithTitle:devLine
														action:nullptr keyEquivalent:@""];
				[item setIndentationLevel:1];
			}
		}
		// Filesystems
		[vdevMenu addItem:[NSMenuItem separatorItem]];
		auto childFileSystems = pool.allFileSystems();
		for (auto & fs : childFileSystems)
		{
			auto fsLine = formatStatus(fs);
			NSMenuItem * item = [vdevMenu addItemWithTitle:fsLine action:nullptr keyEquivalent:@""];
			item.representedObject = [NSString stringWithUTF8String:fs.name()];
			item.submenu = createFSMenu(fs, delegate);
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
		NSMenu * vdevMenu = createVdevMenu(pool, self);
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

- (void)errorDetected:(std::string const &)error
{
	NSUserNotification * notification = [[NSUserNotification alloc] init];
	notification.title = NSLocalizedString(@"ZFS Error", @"");
	NSString * errorFormat = NSLocalizedString(@"ZFS encountered an error: %s.", @"");
	notification.informativeText = [NSString stringWithFormat:errorFormat, error.c_str()];
	notification.hasActionButton = NO;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void)errorFromHelper:(NSError*)error
{
	NSUserNotification * notification = [[NSUserNotification alloc] init];
	notification.title = NSLocalizedString(@"Helper Error", @"");
	NSString * errorFormat = NSLocalizedString(@"Helper encountered an error: %@.", @"");
	notification.informativeText = [NSString stringWithFormat:errorFormat, [error localizedDescription]];
	notification.hasActionButton = NO;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#pragma mark ZFS Maintenance

static NSString * getPassword()
{
	auto param = @{
		(__bridge NSString*)kCFUserNotificationAlertHeaderKey: @"Mount Filesystem with Key",
		(__bridge NSString*)kCFUserNotificationAlertMessageKey: @"Enter the password for mounting encrypted filesystems",
		(__bridge NSString*)kCFUserNotificationDefaultButtonTitleKey: @"Mount",
		(__bridge NSString*)kCFUserNotificationTextFieldTitlesKey: @"Password",
	};
	SInt32 error = 0;
	auto notification = CFUserNotificationCreate(kCFAllocatorDefault, 30,
		kCFUserNotificationPlainAlertLevel | CFUserNotificationSecureTextField(0),
							 &error, (__bridge CFDictionaryRef)param);
	CFOptionFlags response = 0;
	auto ret = CFUserNotificationReceiveResponse(notification, 0, &response);
	if (ret != 0)
	{
		CFRelease(notification);
		return nil;
	}
	auto pass = CFUserNotificationGetResponseValue(notification, kCFUserNotificationTextFieldValuesKey, 0);
	CFRetain(pass);
	CFRelease(notification);
	return (__bridge_transfer NSString*)pass;
}

- (IBAction)importAllPools:(id)sender
{
	[_authorization autoinstall];
	[_authorization importPools:@{} withReply:^(NSError * error)
	 {
		 if (error)
			 [self errorFromHelper:error];
	 }];
}

- (IBAction)mountAllFilesystems:(id)sender
{
	[_authorization autoinstall];
	[_authorization mountFilesystems:@{} withReply:^(NSError * error)
	 {
		 if (error)
			 [self errorFromHelper:error];
	 }];
}

- (IBAction)mountFilesystem:(id)sender
{
	NSDictionary * opts = @{@"filesystem": [sender representedObject]};
	[_authorization autoinstall];
	[_authorization mountFilesystems:opts withReply:^(NSError * error)
	 {
		 if (error)
			 [self errorFromHelper:error];
	 }];
}

- (IBAction)unmountFilesystem:(id)sender
{
	NSDictionary * opts = @{@"filesystem": [sender representedObject]};
	[_authorization autoinstall];
	[_authorization unmountFilesystems:opts withReply:^(NSError * error)
	 {
		 if (error)
			 [self errorFromHelper:error];
	 }];
}

- (IBAction)loadKey:(id)sender
{
	[_authorization autoinstall];
	NSString * fs = [sender representedObject];
	auto pass = getPassword();
	if (!pass)
		return;
	NSDictionary * opts = @{@"filesystem": fs, @"key": pass};
	[_authorization loadKeyForFilesystem:opts withReply:^(NSError * error)
	 {
		 if (error)
			 [self errorFromHelper:error];
	 }];
}

@end
