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
#import "ZetaImportMenuDelegate.h"
#import "ZetaPoolWatcher.h"
#import "ZetaAuthorization.h"
#import "ZetaFileSystemPropertyMenuDelegate.h"
#import "ZetaPoolPropertyMenuDelegate.h"

#include "ZFSUtils.hpp"
#include "ZFSStrings.hpp"

#include "InvariantDisks/IDDiskArbitrationUtils.hpp"

#include <type_traits>
#include <iomanip>
#include <sstream>
#include <chrono>

@interface ZetaMenuDelegate ()
{
	NSMutableArray * _dynamicMenus;
	DASessionRef _diskArbitrationSession;
}

@end

@implementation ZetaMenuDelegate

- (id)init
{
	if (self = [super init])
	{
		_dynamicMenus = [[NSMutableArray alloc] init];
		_diskArbitrationSession = DASessionCreate(nullptr);
	}
	return self;
}

- (void)dealloc
{
	CFRelease(_diskArbitrationSession);
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	[self clearDynamicMenu:menu];
	[self createPoolMenu:menu];
	[self createActionMenu:menu];
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

std::chrono::seconds getElapsed(zfs::ScanStat const & scanStat)
{
	auto elapsed = time(0) - scanStat.passStartTime;
	elapsed -= scanStat.passPausedSeconds;
	elapsed = (elapsed > 0) ? elapsed : 1;
	return std::chrono::seconds(elapsed);
}

inline std::string formatTimeRemaining(zfs::ScanStat const & scanStat, std::chrono::seconds const & time)
{
	auto bytesRemaining = scanStat.total - scanStat.issued;
	auto issued = scanStat.passIssued;
	if (issued == 0)
		issued = 1;
	auto secondsRemaining = bytesRemaining * time.count() / issued;
	std::stringstream ss;
	ss << std::setfill('0');
	ss << (secondsRemaining / (60*60*24)) << " days "
	<< std::setw(2) << ((secondsRemaining / (60*60)) % 24) << ":"
	<< std::setw(2) << ((secondsRemaining / 60) % 60) << ":"
	<< std::setw(2) << (secondsRemaining % 60);
	return ss.str();
}

#pragma mark ZFS Inspection

NSMenu * createFSMenu(zfs::ZFileSystem && fs, ZetaMenuDelegate * delegate)
{
	NSMenu * fsMenu = [[NSMenu alloc] init];
	[fsMenu setAutoenablesItems:NO];
	if (fs.type() == zfs::ZFileSystem::filesystem)
	{
		NSString * fsName = [NSString stringWithUTF8String:fs.name()];
		NSMenuItem * item;
		auto [encRoot, isRoot] = fs.encryptionRoot();
		if (isRoot && fs.keyStatus() != zfs::ZFileSystem::KeyStatus::available)
		{
			item = [fsMenu addItemWithTitle:@"Load Key"
									 action:@selector(loadKey:) keyEquivalent:@""];
			item.representedObject = fsName;
			item.target = delegate;
		}
		if (!fs.mounted())
		{
			item = [fsMenu addItemWithTitle:@"Mount"
									 action:@selector(mountFilesystem:) keyEquivalent:@""];
			item.representedObject = fsName;
			item.target = delegate;
		}
		else
		{
			item = [fsMenu addItemWithTitle:@"Unmount"
									 action:@selector(unmountFilesystem:) keyEquivalent:@""];
			item.representedObject = fsName;
			item.target = delegate;
			item = [fsMenu addItemWithTitle:@"Unmount (Force)"
									 action:@selector(forceUnmountFilesystem:) keyEquivalent:@""];
			item.representedObject = fsName;
			item.target = delegate;
		}
	}
	// Selected Properties
	[fsMenu addItem:[NSMenuItem separatorItem]];
	addMenuItem(fsMenu, delegate,
				NSLocalizedString(@"Available:          \t %s", @"FS Available Menu Entry"),
				formatBytes(fs.available()));
	addMenuItem(fsMenu, delegate,
				NSLocalizedString(@"Used:               \t %s", @"FS Used Menu Entry"),
				formatBytes(fs.used()));
	addMenuItem(fsMenu, delegate,
				NSLocalizedString(@"Referenced:         \t %s", @"FS Referenced Menu Entry"),
				formatBytes(fs.referenced()));
	addMenuItem(fsMenu, delegate,
				NSLocalizedString(@"Logical Used:       \t %s", @"FS Logically Used Menu Entry"),
				formatBytes(fs.logicalused()));
	addMenuItem(fsMenu, delegate,
				NSLocalizedString(@"Compress Ratio:     \t %1.2fx", @"FS Compress Menu Entry"),
				fs.compressRatio());
	addMenuItem(fsMenu, delegate,
				NSLocalizedString(@"Mount Point:        \t %s", @"FS Mountpoint Menu Entry"),
				fs.mountpoint());
	// All Properties
	[fsMenu addItem:[NSMenuItem separatorItem]];
	NSMenu * allProps = [[NSMenu alloc] initWithTitle:@"All Properties"];
	ZetaFileSystemPropertyMenuDelegate * pd = [[ZetaFileSystemPropertyMenuDelegate alloc] initWithFileSystem:std::move(fs)];
	allProps.delegate = pd;
	NSMenuItem * allPropsItem = [[NSMenuItem alloc] initWithTitle:@"All Properties" action:nullptr keyEquivalent:@""];
	allPropsItem.submenu = allProps;
	allPropsItem.representedObject = pd;
	[fsMenu addItem:allPropsItem];
	return fsMenu;
}

NSString * formatStatus(zfs::ZFileSystem const & fs)
{
	NSString * mountStatus = fs.mounted() ?
		NSLocalizedString(@"📌", @"mounted status") :
		NSLocalizedString(@"🕳", @"unmounted status");
	NSString * encStatus = nil;
	switch (fs.keyStatus())
	{
		case zfs::ZFileSystem::KeyStatus::none:
			encStatus = @"";
			break;
		case zfs::ZFileSystem::KeyStatus::unavailable:
			encStatus = NSLocalizedString(@", 🔒", @"locked status");
			break;
		case zfs::ZFileSystem::KeyStatus::available:
			encStatus = NSLocalizedString(@"🔑", @"unlocked status");
			break;
	}
	NSString * fsLine = [NSString stringWithFormat:NSLocalizedString(@"%s (%@%@)", @"File System Menu Entry"), fs.name(), mountStatus, encStatus];
	return fsLine;
}

NSMenuItem * addVdev(zfs::ZPool const & pool, zfs::NVList const & device,
	NSMenu * menu, DASessionRef daSession, ZetaMenuDelegate * delegate)
{
	// Menu Item
	auto stat = zfs::vdevStat(device);
	auto item = addMenuItem(menu, delegate, NSLocalizedString(@"%s (%@)", @"Device Menu Entry"),
							pool.vdevName(device), formatErrorStat(stat));
	// Submenu
	// ZFS Info
	NSMenu * subMenu = [[NSMenu alloc] init];
	addMenuItem(subMenu, delegate, formatErrorStat(stat));
	addMenuItem(subMenu, delegate,
				NSLocalizedString(@"Space:          \t %s used / %s total", @"VDev Space Menu Entry"),
				formatBytes(stat.alloc), formatBytes(stat.space));
	addMenuItem(subMenu, delegate,
				NSLocalizedString(@"Fragmentation:  \t %llu%%", @"VDev Fragmentation Menu Entry"),
				stat.fragmentation);
	addMenuItem(subMenu, delegate,
				NSLocalizedString(@"VDev GUID:      \t %llu", @"VDev GUID Menu Entry"),
				zfs::vdevGUID(device));
	std::string type = zfs::vdevType(device);
	addMenuItem(subMenu, delegate,
				NSLocalizedString(@"Device:         \t %s (%s)", @"VDev Device Menu Entry"),
				pool.vdevDevice(device), type);
	// Disk Info, only if state is at least 5 or higher, (FAULTED, DEGRADED, HEALTHY)
	if (type == "disk" && stat.state >= 5)
	{
		[subMenu addItem:[NSMenuItem separatorItem]];
		auto devicePath = pool.vdevDevice(device);
		DADiskRef daDisk = DADiskCreateFromBSDName(nullptr, daSession, devicePath.c_str());
		auto diskInfo = ID::getDiskInformation(daDisk);
		addMenuItem(subMenu, delegate,
					NSLocalizedString(@"UUID:           \t %s", @"VDev MediaUUID Menu Entry"), diskInfo.mediaUUID);
		addMenuItem(subMenu, delegate,
					NSLocalizedString(@"Model:          \t %s", @"VDev Model Menu Entry"), trim(diskInfo.deviceModel));
		addMenuItem(subMenu, delegate,
					NSLocalizedString(@"Serial:         \t %s", @"VDev Serial Menu Entry"), trim(diskInfo.ioSerial));
		CFRelease(daDisk);
	}
	item.submenu = subMenu;
	return item;
}

NSMenu * createVdevMenu(zfs::ZPool && pool, ZetaMenuDelegate * delegate, DASessionRef daSession)
{
	NSMenu * vdevMenu = [[NSMenu alloc] init];
	[vdevMenu setAutoenablesItems:NO];
	try
	{
		auto vdevs = pool.vdevs();
		auto scrub = pool.scanStat();
		if (scrub.state == zfs::ScanStat::scanning)
		{
			auto elapsed = getElapsed(scrub);
			NSString * scanLine0 = [NSString stringWithFormat:NSLocalizedString(
				@"Scrub in Progress:", @"Scrub Menu Entry 0")];
			NSString * scanLine1 = [NSString stringWithFormat:NSLocalizedString(
				@"%s scanned at %s, %s issued at %s", @"Scrub Menu Entry 1"),
									formatBytes(scrub.scanned).c_str(),
									formatRate(scrub.passScanned, elapsed).c_str(),
									formatBytes(scrub.issued).c_str(),
									formatRate(scrub.passIssued, elapsed).c_str()];
			NSString * scanLine2 = [NSString stringWithFormat:NSLocalizedString(
				@"%s total, %0.2f %% done, %s remaining, %i errors", @"Scrub Menu Entry 2"),
									formatBytes(scrub.total).c_str(),
									100.0*scrub.issued/scrub.total,
									formatTimeRemaining(scrub, elapsed).c_str(),
									scrub.errors];
			[vdevMenu addItemWithTitle:scanLine0 action:nullptr keyEquivalent:@""];
			auto m1 = [vdevMenu addItemWithTitle:scanLine1 action:nullptr keyEquivalent:@""];
			auto m2 = [vdevMenu addItemWithTitle:scanLine2 action:nullptr keyEquivalent:@""];
			m1.indentationLevel = 1;
			m2.indentationLevel = 1;
			[vdevMenu addItem:[NSMenuItem separatorItem]];
		}
		for (auto && vdev: vdevs)
		{
			// VDev
			addVdev(pool, vdev, vdevMenu, daSession, delegate);
			// Children
			auto devices = zfs::vdevChildren(vdev);
			for (auto && device: devices)
			{
				auto item = addVdev(pool, device, vdevMenu, daSession, delegate);
				[item setIndentationLevel:1];
			}
		}
		// Caches
		auto caches = pool.caches();
		if (caches.size() > 0)
		{
			[vdevMenu addItemWithTitle:@"cache" action:nullptr keyEquivalent:@""];
			for (auto && cache: caches)
			{
				auto item = addVdev(pool, cache, vdevMenu, daSession, delegate);
				[item setIndentationLevel:1];
			}
		}
		// Filesystems
		[vdevMenu addItem:[NSMenuItem separatorItem]];
		auto childFileSystems = pool.allFileSystems();
		if (childFileSystems.empty())
		{
			// This seems to happen when a pool is UNAVAIL
			NSMenuItem * item = [vdevMenu addItemWithTitle:@"No Filesystems!" action:nil keyEquivalent:@""];
			[item setEnabled:NO];
		}
		else
		{
			for (auto & fs : childFileSystems)
			{
				auto fsLine = formatStatus(fs);
				NSMenuItem * item = [vdevMenu addItemWithTitle:fsLine action:nullptr keyEquivalent:@""];
				item.representedObject = [NSString stringWithUTF8String:fs.name()];
				item.submenu = createFSMenu(std::move(fs), delegate);
			}
		}
		// Actions
		NSString * poolName = [NSString stringWithUTF8String:pool.name()];
		NSMenuItem * item = nullptr;
		[vdevMenu addItem:[NSMenuItem separatorItem]];
		if (scrub.state == zfs::ScanStat::scanning)
		{
			item = [vdevMenu addItemWithTitle:@"Scrub Stop"
									   action:@selector(scrubStopPool:) keyEquivalent:@""];
			item.representedObject = poolName;
			item.target = delegate;
		}
		else
		{
			item = [vdevMenu addItemWithTitle:@"Scrub"
									   action:@selector(scrubPool:) keyEquivalent:@""];
			item.representedObject = poolName;
			item.target = delegate;
		}
		item = [vdevMenu addItemWithTitle:@"Export"
								   action:@selector(exportPool:) keyEquivalent:@""];
		item.representedObject = poolName;
		item.target = delegate;
		item = [vdevMenu addItemWithTitle:@"Export (Force)"
								   action:@selector(forceExportPool:) keyEquivalent:@""];
		item.representedObject = poolName;
		item.target = delegate;
		// All Properties
		[vdevMenu addItem:[NSMenuItem separatorItem]];
		NSMenu * allProps = [[NSMenu alloc] initWithTitle:@"All Properties"];
		ZetaPoolPropertyMenuDelegate * pd = [[ZetaPoolPropertyMenuDelegate alloc] initWithPool:std::move(pool)];
		allProps.delegate = pd;
		NSMenuItem * allPropsItem = [[NSMenuItem alloc] initWithTitle:@"All Properties" action:nullptr keyEquivalent:@""];
		allPropsItem.submenu = allProps;
		allPropsItem.representedObject = pd;
		[vdevMenu addItem:allPropsItem];

	}
	catch (std::exception const & e)
	{
		[vdevMenu addItemWithTitle:NSLocalizedString(@"Error reading pool configuration", @"Pool Config Error Message")
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
	for (auto && pool: [[self poolWatcher] pools])
	{
		NSString * poolLine = [NSString stringWithFormat:NSLocalizedString(@"%s (%@)", @"Pool Menu Entry"),
			pool.name(), zfs::emojistring_pool_status_t(pool.status())];
		NSMenuItem * poolItem = [[NSMenuItem alloc] initWithTitle:poolLine action:NULL keyEquivalent:@""];
		NSMenu * vdevMenu = createVdevMenu(std::move(pool), self, _diskArbitrationSession);
		[poolItem setSubmenu:vdevMenu];
		[menu insertItem:poolItem atIndex:poolItemRootIdx + poolIdx];
		[_dynamicMenus addObject:poolItem];
		++poolIdx;
	}
}

- (void)createActionMenu:(NSMenu*)menu
{
	NSInteger actionMenuIdx = [menu indexOfItemWithTag:ActionAnchorMenuTag];
	if (actionMenuIdx < 0)
		return;
	// Unlock
	NSMenuItem * unlockItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Load Keys", @"Load Key Menu Entry") action:NULL keyEquivalent:@""];
	NSMenu * unlockMenu = [[NSMenu alloc] init];
	[unlockItem setSubmenu:unlockMenu];
	NSMutableArray * allEncryptionRoots = [NSMutableArray array];
	NSMenuItem * unlockAllItem = [unlockMenu addItemWithTitle:@"Load all Keys..." action:@selector(loadAllKeys:) keyEquivalent:@""];
	unlockAllItem.target = self;
	unlockAllItem.representedObject = allEncryptionRoots;
	[unlockMenu addItem:[NSMenuItem separatorItem]];
	for (auto && pool: [[self poolWatcher] pools])
	{
		for (auto & fs : pool.allFileSystems())
		{
			auto [encRoot, isRoot] = fs.encryptionRoot();
			auto keyStatus = fs.keyStatus();
			if (isRoot && keyStatus == zfs::ZFileSystem::KeyStatus::unavailable)
			{
				NSString * fsName = [NSString stringWithUTF8String:fs.name()];
				NSMenuItem * item = [unlockMenu addItemWithTitle:fsName
														  action:@selector(loadKey:) keyEquivalent:@""];
				item.representedObject = fsName;
				item.target = self;
				[allEncryptionRoots addObject:fsName];
			}
		}
	}
	if ([allEncryptionRoots count] > 0)
	{
		[menu insertItem:unlockItem atIndex:actionMenuIdx + 1];
		[_dynamicMenus addObject:unlockItem];
	}
}

- (void)clearDynamicMenu:(NSMenu*)menu
{
	for (NSMenuItem * m in _dynamicMenus)
	{
		[menu removeItem:m];
	}
	[_dynamicMenus removeAllObjects];
}

- (void)errorDetectedInPool:(std::string const &)pool
{
	NSUserNotification * notification = [[NSUserNotification alloc] init];
	notification.title = NSLocalizedString(@"ZFS Pool Error", @"ZFS Pool Error Title");
	NSString * errorFormat = NSLocalizedString(@"ZFS detected an error on pool %s.", @"ZFS Pool Error Format");
	notification.informativeText = [NSString stringWithFormat:errorFormat, pool.c_str()];
	notification.hasActionButton = NO;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void)errorDetected:(std::string const &)error
{
	NSUserNotification * notification = [[NSUserNotification alloc] init];
	notification.title = NSLocalizedString(@"ZFS Error", @"ZFS Error Title");
	NSString * errorFormat = NSLocalizedString(@"ZFS encountered an error: %s.", @"ZFS Error Format");
	notification.informativeText = [NSString stringWithFormat:errorFormat, error.c_str()];
	notification.hasActionButton = NO;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void)newPoolDetected:(const zfs::ZPool &)pool
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autoUnlock"])
	{
		for (auto & fs : pool.allFileSystems())
		{
			auto [encRoot, isRoot] = fs.encryptionRoot();
			auto keyStatus = fs.keyStatus();
			if (isRoot && keyStatus == zfs::ZFileSystem::KeyStatus::unavailable)
			{
				NSString * fsName = [NSString stringWithUTF8String:fs.name()];
				[_zetaKeyLoader unlockFileSystem:fsName];
			}
		}
	}
}

- (void)handlePoolChangeReply:(NSError*)error
{
	if (error)
		[self errorFromHelper:error];
	else
		[[self poolWatcher] checkForChanges];
}

- (void)handleFileSystemChangeReply:(NSError*)error
{
	if (error)
		[self errorFromHelper:error];
}

- (void)handleMetaDataChangeReply:(NSError*)error
{
	if (error)
		[self errorFromHelper:error];
}

#pragma mark ZFS Maintenance

- (IBAction)exportPool:(id)sender
{
	NSDictionary * opts = @{@"pool": [sender representedObject]};
	[_authorization exportPools:opts withReply:^(NSError * error)
	 {
		 [self handlePoolChangeReply:error];
	 }];
}

- (IBAction)forceExportPool:(id)sender
{
	NSDictionary * opts = @{@"pool": [sender representedObject], @"force": @YES};
	[_authorization exportPools:opts withReply:^(NSError * error)
	 {
		 [self handlePoolChangeReply:error];
	 }];
}

- (IBAction)mountAllFilesystems:(id)sender
{
	[_authorization mountFilesystems:@{} withReply:^(NSError * error)
	 {
		 [self handleFileSystemChangeReply:error];
	 }];
}

- (IBAction)mountFilesystem:(id)sender
{
	NSDictionary * opts = @{@"filesystem": [sender representedObject]};
	[_authorization mountFilesystems:opts withReply:^(NSError * error)
	 {
		 [self handleFileSystemChangeReply:error];
	 }];
}

- (IBAction)unmountFilesystem:(id)sender
{
	NSDictionary * opts = @{@"filesystem": [sender representedObject]};
	[_authorization unmountFilesystems:opts withReply:^(NSError * error)
	 {
		 [self handleFileSystemChangeReply:error];
	 }];
}

- (IBAction)forceUnmountFilesystem:(id)sender
{
	NSDictionary * opts = @{@"filesystem": [sender representedObject], @"force": @YES};
	[_authorization unmountFilesystems:opts withReply:^(NSError * error)
	 {
		 [self handleFileSystemChangeReply:error];
	 }];
}

- (IBAction)loadKey:(id)sender
{
	NSString * fs = [sender representedObject];
	[_zetaKeyLoader unlockFileSystem:fs];
}

- (IBAction)loadAllKeys:(id)sender
{
	NSArray<NSString*> * fss = [sender representedObject];
	for (NSString * fs in fss) {
		[_zetaKeyLoader unlockFileSystem:fs];
	}
}

- (IBAction)scrubPool:(id)sender
{
	NSDictionary * opts = @{@"pool": [sender representedObject]};
	[_authorization scrubPool:opts withReply:^(NSError * error)
	 {
		 [self handleMetaDataChangeReply:error];
	 }];
}

- (IBAction)scrubStopPool:(id)sender
{
	NSDictionary * opts = @{@"pool": [sender representedObject], @"stop": @YES};
	[_authorization scrubPool:opts withReply:^(NSError * error)
	 {
		 [self handleMetaDataChangeReply:error];
	 }];
}

@end
