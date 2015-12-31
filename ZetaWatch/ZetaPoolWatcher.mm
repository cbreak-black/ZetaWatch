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

#include <map>

@interface ZetaPoolWatcher ()
{
	// ZFS
	zfs::LibZFSHandle _zfsHandle;
	std::vector<zfs::ZPool> _pools;

	// Statistics
	std::map<std::string,zfs::VDevStat> _errorStats;
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
		[self refreshPools];
	}
	return self;
}

- (void)refreshPools
{
	_pools = zfs::zpool_list(_zfsHandle);
}

- (void)checkForNewErrors
{
	for (auto && pool: _pools)
	{
		auto vdevs = pool.vdevs();
		for (auto && vdev: vdevs)
		{
			auto devices = zfs::vdevChildren(vdev);
			for (auto && device: devices)
			{
				auto stat = zfs::vdevStat(device);
				auto path = zfs::vdevPath(device);
				auto & oldStat = _errorStats[path];
				if (containsMoreErrors(oldStat, stat))
				{
					oldStat = stat;
					[[self delegate] errorDetectedInPool:pool.name() onDevice:path];
				}
			}
		}
	}
}

- (std::vector<zfs::ZPool> const &)pools
{
	[self refreshPools];
	[self checkForNewErrors];
	return _pools;
}

@synthesize delegate;

@end
