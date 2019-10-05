//
//  ZetaSnapshotMenu.m
//  ZetaWatch
//
//  Created by cbreak on 19.10.05.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaSnapshotMenu.h"

@implementation ZetaSnapshotMenu
{
	zfs::ZFileSystem _fs;
}

- (id)initWithFileSystem:(zfs::ZFileSystem)fs
{
	if (self = [super init])
	{
		_fs = std::move(fs);
	}
	return self;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	[menu removeAllItems];
	auto snap = _fs.snapshots();
	if (!snap.empty())
	{
		for (auto const & s : snap)
		{
			NSString * title = [NSString stringWithFormat:NSLocalizedString(@"%s", @"Snapshot"), s.name()];
			[menu addItemWithTitle:title action:NULL keyEquivalent:@""];
		}
	}
	else
	{
		[menu addItemWithTitle:NSLocalizedString(@"No snapshots found", @"No Snapshots")
						action:NULL keyEquivalent:@""];
	}
}

@end
