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
	if (!snap.mounted())
	{
		item = [sMenu addItemWithTitle:@"Mount"
			action:@selector(mountFilesystem:) keyEquivalent:@""];
		item.representedObject = sName;
		item.target = delegate;
	}
	else
	{
		item = [sMenu addItemWithTitle:@"Unmount"
			action:@selector(unmountFilesystem:) keyEquivalent:@""];
		item.representedObject = sName;
		item.target = delegate;
		item = [sMenu addItemWithTitle:@"Unmount (Force)"
			action:@selector(unmountFilesystemForce:) keyEquivalent:@""];
		item.representedObject = sName;
		item.target = delegate;
	}
	item = [sMenu addItemWithTitle:@"Rollback"
		action:@selector(rollbackFilesystem:) keyEquivalent:@""];
	item.representedObject = sName;
	item.target = delegate;
	item = [sMenu addItemWithTitle:@"Rollback (Force)"
		action:@selector(rollbackFilesystemForce:) keyEquivalent:@""];
	item.representedObject = sName;
	item.target = delegate;
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
		for (auto const & s : snap)
		{
			NSMenuItem * item = createSnapMenu(s, _delegate);
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
