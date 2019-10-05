//
//  ZetaSnapshotMenu.m
//  ZetaWatch
//
//  Created by cbreak on 19.10.05.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaSnapshotMenu.h"

#import "ZetaMainMenu.h"

@implementation ZetaSnapshotMenu
{
	zfs::ZFileSystem _fs;
	ZetaMainMenu __weak * _delegate;
}

- (id)initWithFileSystem:(zfs::ZFileSystem)fs delegate:(ZetaMainMenu*)delegate
{
	if (self = [super init])
	{
		_fs = std::move(fs);
		_delegate = delegate;
	}
	return self;
}

NSMenuItem * createSnapMenu(zfs::ZFileSystem const & snap, ZetaMainMenu * delegate)
{
	NSMenu * sMenu = [[NSMenu alloc] init];
	[sMenu setAutoenablesItems:NO];
	NSString * sName = [NSString stringWithUTF8String:snap.name()];
	NSMenuItem * item;
	item = [sMenu addItemWithTitle:NSLocalizedString(@"Rollback", @"Rollback")
		action:@selector(rollbackFilesystem:) keyEquivalent:@""];
	item.representedObject = sName;
	item.target = delegate;
	item = [sMenu addItemWithTitle:NSLocalizedString(@"Rollback (Force)", @"Rollback (Force)")
		action:@selector(rollbackFilesystemForce:) keyEquivalent:@""];
	item.representedObject = sName;
	item.target = delegate;
	if (!snap.mounted())
	{
		item = [sMenu addItemWithTitle:NSLocalizedString(@"Mount", @"Mount")
								action:@selector(mountFilesystem:) keyEquivalent:@""];
		item.representedObject = sName;
		item.target = delegate;
	}
	else
	{
		item = [sMenu addItemWithTitle:NSLocalizedString(@"Unmount", @"Unmount")
								action:@selector(unmountFilesystem:) keyEquivalent:@""];
		item.representedObject = sName;
		item.target = delegate;
		item = [sMenu addItemWithTitle:NSLocalizedString(@"Unmount (Force)", @"Unmount (Force)")
								action:@selector(unmountFilesystemForce:) keyEquivalent:@""];
		item.representedObject = sName;
		item.target = delegate;
	}
	item = [[NSMenuItem alloc] initWithTitle:sName action:nullptr keyEquivalent:@""];
	item.representedObject = sName;
	item.submenu = sMenu;
	return item;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	[menu removeAllItems];
	auto snap = _fs.snapshots();
	if (!snap.empty())
	{
		for (size_t i = snap.size(); i > 0; --i)
		{
			NSMenuItem * item = createSnapMenu(snap[i-1], _delegate);
			[menu addItem:item];
		}
	}
	else
	{
		[menu addItemWithTitle:NSLocalizedString(@"No snapshots found", @"No Snapshots")
						action:NULL keyEquivalent:@""];
	}
}

@end
