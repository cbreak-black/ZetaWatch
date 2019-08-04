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

bool operator<(PoolID const & a, PoolID const & b)
{
	return a.guid < b.guid;
}

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
	std::vector<PoolID> _importable;
	std::vector<PoolID> _importableKnown;
	std::set<PoolID> _knownPools;
}

- (void)scheduleChecking;

@end

class ZetaIDHandler : public ID::DiskArbitrationHandler
{
public:
	ZetaIDHandler(ZetaAutoImporter * watcher) : watcher(watcher)
	{
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
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autoImport"])
	{
		[_authorization importablePoolsWithReply:
		 ^(NSError * error, NSDictionary * importablePools)
		 {
			if (error)
				[self errorFromHelper:error];
			else
				[self handleImportablePools:importablePools];
		 }];
	}
}

std::vector<PoolID> dictToPoolVec(NSDictionary * poolDict)
{
	std::vector<PoolID> pools;
	for (NSNumber * guidNum in poolDict)
	{
		pools.push_back({
			[guidNum unsignedLongLongValue],
			[poolDict[guidNum] UTF8String]
		});
	}
	std::sort(pools.begin(), pools.end());
	return pools;
}

- (void)handleImportablePools:(NSDictionary*)importablePools
{
	std::vector<PoolID> importableAll = dictToPoolVec(importablePools);
	// Find the pools that had not been imported before
	std::vector<PoolID> importableFresh;
	std::set_difference(importableAll.begin(), importableAll.end(),
						_knownPools.begin(), _knownPools.end(),
						std::back_inserter(importableFresh));
	// Find the pools that had been imported before
	std::vector<PoolID> importableKnown;
	std::set_difference(importableAll.begin(), importableAll.end(),
						importableFresh.begin(), importableFresh.end(),
						std::back_inserter(importableKnown));
	// Find new importable pools
	std::vector<PoolID> importableNew;
	std::set_difference(importableFresh.begin(), importableFresh.end(),
						_importable.begin(), _importable.end(),
						std::back_inserter(importableNew));
	// Find no longer importable pools that were known before
	std::vector<PoolID> importableKnownRemoved;
	std::set_difference(_importableKnown.begin(), _importableKnown.end(),
						importableAll.begin(), importableAll.end(),
						std::back_inserter(importableKnownRemoved));
	// Update currently importable pools collection
	_importable = std::move(importableAll);
	_importableKnown = std::move(importableKnown);
	[self handleNewImportablePools:importableNew];
	[self handleRemovedKnownImportablePools:importableKnownRemoved];
}

- (void)handleNewImportablePools:(std::vector<PoolID> const &)importableNew
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autoImport"])
	{
		for (auto const & pool : importableNew)
		{
			NSLog(@"Auto-Importing pool %s", pool.name.c_str());
			NSDictionary * pools = @{ @"poolGUID": [NSNumber numberWithUnsignedLongLong:pool.guid] };
			[_authorization importPools:pools withReply:^(NSError * error)
			 {
				 [self handlePoolImportReply:error forPool:pool];
			 }];
		}
	}
}

- (void)handleRemovedKnownImportablePools:(std::vector<PoolID> const &)importableKnownRemoved
{
	for (auto const & p : importableKnownRemoved)
	{
		_knownPools.erase(p);
	}
}

- (void)newPoolDetected:(zfs::ZPool const &)pool
{
	_knownPools.insert({pool.guid(), pool.name()});
	// An imported pool might have changed which pools can be imported
	[self scheduleChecking];
}

- (void)handlePoolImportReply:(NSError*)error forPool:(PoolID)pool
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

- (std::vector<PoolID> const &)importablePools
{
	return _importable;
}

@end
