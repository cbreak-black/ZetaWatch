//
//  ZetaPoolWatcher.mm
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.31.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted
//  provided that the conditions of the "3-Clause BSD" license described in the BSD.LICENSE file are met.
//  Additional licensing options are described in the README file.
//

#import "ZetaPoolWatcher.h"

#import <IOKit/pwr_mgt/IOPMLib.h>

#include <map>

CFStringRef powerAssertionName = CFSTR("ZFSScrub");
CFStringRef powerAssertionReason = CFSTR("ZFS Scrub in progress");

@interface ZetaPoolWatcher ()
{
	// ZFS
	zfs::LibZFSHandle _zfsHandle;
	std::vector<zfs::ZPool> _pools;

	// Statistics
	std::map<uint64_t,zfs::VDevStat> _errorStats;

	// Sleep Prevention
	IOPMAssertionID assertionID;
	bool keptAwake;

	// Timing
	NSTimer * _autoUpdateTimer;
}

@end

bool containsMoreErrors(zfs::VDevStat const & a, zfs::VDevStat const & b)
{
	return b.errorRead > a.errorRead
		|| b.errorWrite > a.errorWrite
		|| b.errorChecksum > a.errorChecksum;
}

@implementation ZetaPoolWatcher

- (id)init
{
	if (self = [super init])
	{
		_autoUpdateTimer = [NSTimer timerWithTimeInterval:60
			target:self selector:@selector(timedUpdate:) userInfo:nil repeats:YES];
		_autoUpdateTimer.tolerance = 8;
		[[NSRunLoop currentRunLoop] addTimer:_autoUpdateTimer forMode:NSDefaultRunLoopMode];
		[self refreshPools];
	}
	return self;
}

- (void)dealloc
{
	[_autoUpdateTimer invalidate];
	_autoUpdateTimer = nil;
	[self stopKeepingAwake];
}

- (void)timedUpdate:(NSTimer*)timer
{
	try
	{
		[self refreshPools];
		[self checkForNewErrors];
		auto scrubCounter = [self countScrubsInProgress];
		if (scrubCounter > 0)
			[self keepAwake];
		else
			[self stopKeepingAwake];
	}
	catch (std::exception const & e)
	{
		NSLog(@"Update Error: %s", e.what());
	}
}

- (void)refreshPools
{
	try
	{
		_pools = _zfsHandle.pools();
	}
	catch (std::exception const & e)
	{
		[[self delegate] errorDetected:e.what()];
	}
}

- (bool)checkDev:(zfs::NVList const &)dev
{
	auto guid = vdevGUID(dev);
	auto newStat = vdevStat(dev);
	auto & oldStat = _errorStats[guid];
	bool error = containsMoreErrors(oldStat, newStat);
	oldStat = newStat;
	return error;
}

- (bool)checkForNewErrors
{
	try
	{
		for (auto && pool: _pools)
		{
			auto vdevs = pool.vdevs();
			for (auto && vdev: vdevs)
			{
				if ([self checkDev:vdev])
				{
					[[self delegate] errorDetectedInPool:pool.name()];
					return true;
				}

				auto devices = zfs::vdevChildren(vdev);
				for (auto && device: devices)
				{
					if ([self checkDev:device])
					{
						[[self delegate] errorDetectedInPool:pool.name()];
						return true;
					}
				}
			}
		}
	}
	catch (std::exception const & e)
	{
		[[self delegate] errorDetected:e.what()];
	}
	return false;
}

- (uint64_t)countScrubsInProgress
{
	uint64_t scrubsInProgress = 0;
	try
	{
		for (auto && pool: _pools)
		{
			auto vdevs = pool.vdevs();
			auto scan = pool.scanStat();
			if (scan.state == zfs::ScanStat::scanning)
				++scrubsInProgress;
		}
	}
	catch (std::exception const & e)
	{
		[[self delegate] errorDetected:e.what()];
	}
	return scrubsInProgress;
}

- (std::vector<zfs::ZPool> const &)pools
{
	[self refreshPools];
	[self checkForNewErrors];
	return _pools;
}

- (void)keepAwake
{
	if (!keptAwake)
	{
		IOReturn success = IOPMAssertionCreateWithDescription(
			kIOPMAssertPreventUserIdleSystemSleep,
			powerAssertionName, powerAssertionReason, 0, 0, 0, 0, &assertionID);
		if (success == kIOReturnSuccess)
		{
			keptAwake = true;
		}
		else
		{
			keptAwake = false;
			assertionID = 0;
		}
	}
}

- (void)stopKeepingAwake
{
	if (keptAwake)
	{
		IOReturn success = IOPMAssertionRelease(assertionID);
		if (success == kIOReturnSuccess)
		{
			keptAwake = false;
			assertionID = 0;
		}
	}
}

@synthesize delegate;

@end
