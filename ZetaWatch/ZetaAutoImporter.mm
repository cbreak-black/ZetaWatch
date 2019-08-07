//
//  ZetaIDWatcher.cpp
//  ZetaWatch
//
//  Created by cbreak on 19.08.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaAutoImporter.h"

#include "IDDiskArbitrationDispatcher.hpp"
#include "IDDiskArbitrationHandler.hpp"

#include <vector>
#include <set>
#include <string>
#include <algorithm>

/*!
 If Auto-Import is configured:
 Discovered importable pools get classified into known and new pools. Pools that
 have not been seen recently are importable and are imported automatically. This
 set prevents attempting to import a pool multiple times in case of an error.
 Pools that were imported previously are added to the knownPools set and are
 not imported. They are ignored until they vanish from being importable, at
 which point they are removed from the known pools set.
 */
@interface ZetaAutoImporter ()
{
	// ID
	ID::DiskArbitrationDispatcher _idDispatcher;
	NSTimer * checkTimer;

	// Management
	std::vector<zfs::ImportablePool> _importable;
	std::vector<zfs::ImportablePool> _importableKnown;
	std::set<zfs::ImportablePool> _knownPools;
}

- (void)scheduleChecking;

@end

class ZetaIDHandler : public ID::DiskArbitrationHandler
{
public:
	ZetaIDHandler(ZetaAutoImporter * watcher) : watcher(watcher)
	{
		scheduleChecking();
	}

public:
	virtual void diskAppeared(DADiskRef disk, ID::DiskInformation const & info)
	{
		scheduleChecking();
	}

	virtual void diskDisappeared(DADiskRef disk, ID::DiskInformation const & info)
	{
		scheduleChecking();
	}

private:
	void scheduleChecking()
	{
		[watcher scheduleChecking];
	}

private:
	ZetaAutoImporter __weak * watcher;
};

@implementation ZetaAutoImporter

- (id)init
{
	if (self = [super init])
	{
		// ID
		_idDispatcher.addHandler(std::make_shared<ZetaIDHandler>(self));
		_idDispatcher.start();
	}
	return self;
}

- (void)awakeFromNib
{
	if (self.poolWatcher)
	{
		[self.poolWatcher.delegates addObject:self];
	}
}

- (void)dealloc
{
	_idDispatcher.stop();
}

- (void)scheduleChecking
{
	if (checkTimer && [checkTimer isValid])
	{
		return;
	}
	checkTimer = [NSTimer timerWithTimeInterval:4 target:self
		selector:@selector(checkForImportablePools) userInfo:nil repeats:NO];
	checkTimer.tolerance = 2;
	[[NSRunLoop currentRunLoop] addTimer:checkTimer forMode:NSDefaultRunLoopMode];
}

- (void)checkForImportablePools
{
	[_authorization importablePoolsWithReply:
	 ^(NSError * error, NSArray * importablePools)
	 {
		if (error)
			[self errorFromHelper:error];
		else
			[self handleImportablePools:importablePools];
	 }];
}

std::vector<zfs::ImportablePool> arrayToPoolVec(NSArray * poolsArray)
{
	std::vector<zfs::ImportablePool> pools;
	for (NSDictionary * poolDict in poolsArray)
	{
		pools.push_back({
			[poolDict[@"name"] UTF8String],
			[poolDict[@"guid"] unsignedLongLongValue],
			[poolDict[@"status"] unsignedLongLongValue]
		});
	}
	std::sort(pools.begin(), pools.end());
	return pools;
}

- (void)handleImportablePools:(NSArray*)importablePools
{
	std::vector<zfs::ImportablePool> importableAll = arrayToPoolVec(importablePools);
	// Find the pools that had not been imported before
	std::vector<zfs::ImportablePool> importableFresh;
	std::set_difference(importableAll.begin(), importableAll.end(),
						_knownPools.begin(), _knownPools.end(),
						std::back_inserter(importableFresh));
	// Find the pools that had been imported before
	std::vector<zfs::ImportablePool> importableKnown;
	std::set_difference(importableAll.begin(), importableAll.end(),
						importableFresh.begin(), importableFresh.end(),
						std::back_inserter(importableKnown));
	// Find new importable pools
	std::vector<zfs::ImportablePool> importableNew;
	std::set_difference(importableFresh.begin(), importableFresh.end(),
						_importable.begin(), _importable.end(),
						std::back_inserter(importableNew));
	// Find no longer importable pools that were known before
	std::vector<zfs::ImportablePool> importableKnownRemoved;
	std::set_difference(_importableKnown.begin(), _importableKnown.end(),
						importableAll.begin(), importableAll.end(),
						std::back_inserter(importableKnownRemoved));
	// Update currently importable pools collection
	_importable = std::move(importableAll);
	_importableKnown = std::move(importableKnown);
	[self handleNewImportablePools:importableNew];
	[self handleRemovedKnownImportablePools:importableKnownRemoved];
}

- (void)handleNewImportablePools:(std::vector<zfs::ImportablePool> const &)importableNew
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autoImport"])
	{
		for (auto const & pool : importableNew)
		{
			if (!zfs::healthy(pool.status))
				continue; // skip pools that aren't healthy
			NSLog(@"Auto-Importing pool %s", pool.name.c_str());
			NSDictionary * pools = @{ @"poolGUID": [NSNumber numberWithUnsignedLongLong:pool.guid] };
			[_authorization importPools:pools withReply:^(NSError * error)
			 {
				 [self handlePoolImportReply:error forPool:pool];
			 }];
		}
	}
}

- (void)handleRemovedKnownImportablePools:(std::vector<zfs::ImportablePool> const &)importableKnownRemoved
{
	for (auto const & p : importableKnownRemoved)
	{
		_knownPools.erase(p);
	}
}

- (void)newPoolDetected:(zfs::ZPool const &)pool
{
	_knownPools.insert({pool.name(), pool.guid(), 0});
	// An imported pool might have changed which pools can be imported
	[self scheduleChecking];
}

- (void)handlePoolImportReply:(NSError*)error forPool:(zfs::ImportablePool const &)pool
{
	if (error)
	{
		[self errorFromHelper:error];
	}
	else
	{
		[[self poolWatcher] checkForChanges];
	}
}

- (std::vector<zfs::ImportablePool> const &)importablePools
{
	return _importable;
}

@end
