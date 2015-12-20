//
//  ZetaMenuDelegate.m
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.20.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//

#import "ZetaMenuDelegate.h"

@interface ZetaMenuDelegate ()
{
	NSMutableArray * _poolMenus;
}

@end

@implementation ZetaMenuDelegate

- (id)init
{
	if (self = [super init])
	{
		_poolMenus = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	[self clearPoolMenu:menu];
	[self createPoolMenu:menu];
}

- (void)createPoolMenu:(NSMenu*)menu
{
	NSInteger poolMenuIdx = [menu indexOfItemWithTag:ZPoolAnchorMenuTag];
	if (poolMenuIdx < 0)
		return;
	NSInteger poolItemRootIdx = poolMenuIdx + 1;
	for (NSUInteger i = 0; i < 3; ++i)
	{
		NSMenuItem * testItem = [[NSMenuItem alloc] initWithTitle:@"Test Item" action:NULL keyEquivalent:@""];
		[menu insertItem:testItem atIndex:poolItemRootIdx + i];
		[_poolMenus addObject:testItem];
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

@end
