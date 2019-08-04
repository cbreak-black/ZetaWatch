//
//  ZetaImportMenuDelegate.m
//  ZetaWatch
//
//  Created by cbreak on 19.06.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaImportMenuDelegate.h"

#import "ZetaAuthorization.h"
#import "ZetaPoolWatcher.h"

@implementation ZetaImportMenuDelegate

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	[menu removeAllItems];
	NSMenuItem * importAllItem = [menu addItemWithTitle:@"Import all Pools" action:@selector(importAllPools:) keyEquivalent:@""];
	importAllItem.target = self;
	[menu addItem:[NSMenuItem separatorItem]];
	auto importablePools = [self.autoImporter importablePools];
	if (importablePools.size() > 0)
	{
		for (auto const & pool : importablePools)
		{
			NSString * title = [NSString stringWithFormat:@"%s (%llu)",
								pool.name.c_str(), pool.guid];
			NSMenuItem * item = [_importMenu addItemWithTitle:title action:@selector(importPool:) keyEquivalent:@""];
			[item setAction:@selector(importPool:)];
			[item setTarget:self];
			[item setRepresentedObject:[NSNumber numberWithUnsignedLongLong:pool.guid]];
		}
	}
	else
	{
		[_importMenu addItemWithTitle:@"No importable Pools found"
							   action:NULL keyEquivalent:@""];
	}
}

- (void)importablePoolsDiscovered:(NSDictionary*)importablePools
{
}

- (void)importablePoolsError:(NSError*)error
{
	NSMenuItem * item = [_importMenu itemAtIndex:2];
	[item setTitle:[error localizedDescription]];
}

- (IBAction)importPool:(id)sender
{
	NSDictionary * pools = @{ @"poolGUID": [sender representedObject] };
	[_authorization importPools:pools withReply:^(NSError * error)
	 {
		 [self handlePoolChangeReply:error];
	 }];
}

- (IBAction)importAllPools:(id)sender
{
	[_authorization importPools:@{} withReply:^(NSError * error)
	 {
		 [self handlePoolChangeReply:error];
	 }];
}

- (void)handlePoolChangeReply:(NSError*)error
{
	if (error)
		[self errorFromHelper:error];
	else
		[[self poolWatcher] checkForChanges];
}

@end
