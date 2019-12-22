//
//  ZetaImportMenu.m
//  ZetaWatch
//
//  Created by cbreak on 19.06.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaImportMenu.h"

#import "ZetaAuthorization.h"
#import "ZetaPoolWatcher.h"

#include "ZFSStrings.hpp"

@implementation ZetaImportMenu

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
			NSString * title = [NSString stringWithFormat:@"%s %@ (%llu)",
				pool.name.c_str(),
				zfs::emojistring_pool_status_t(pool.status),
				pool.guid];
			NSMenuItem * item = [_importMenu addItemWithTitle:title action:@selector(importPool:) keyEquivalent:@""];
			[item setAction:@selector(importPool:)];
			[item setTarget:self];
			// Communicate pool to callback
			NSNumber * guid = [NSNumber numberWithUnsignedLongLong:pool.guid];
			NSString * name = [NSString stringWithUTF8String:pool.name.c_str()];
			NSDictionary * poolDict = @{ @"poolGUID": guid, @"poolName": name };
			[item setRepresentedObject:poolDict];
		}
	}
	else
	{
		[_importMenu addItemWithTitle:NSLocalizedString(@"No importable Pools found",
														@"No Importable Pools")
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
	NSDictionary * pool = [sender representedObject];
	NSMutableDictionary * mutablePool = [pool mutableCopy];
	auto defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"useAltroot"])
	{
		[mutablePool setObject:[defaults stringForKey:@"defaultAltroot"] forKey:@"altroot"];
	}
	[_authorization importPools:mutablePool withReply:^(NSError * error)
	 {
		 if (!error)
		 {
			 NSString * title = [NSString stringWithFormat:
				NSLocalizedString(@"Pool %@ imported",
								  @"Pool Import Success short format"),
				pool[@"poolName"]];
			 NSString * text = [NSString stringWithFormat:
				NSLocalizedString(@"%@ (%@) imported",
								  @"Pool Import Success format"),
				pool[@"poolName"], pool[@"poolGUID"]];
			 [self notifySuccessWithTitle:title text:text];
		 }
		 [self handlePoolChangeReply:error];
	 }];
}

- (IBAction)importAllPools:(id)sender
{
	NSMutableDictionary * mutablePool = [NSMutableDictionary dictionary];
	auto defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"useAltroot"])
	{
		[mutablePool setObject:[defaults stringForKey:@"defaultAltroot"] forKey:@"altroot"];
	}
	[_authorization importPools:mutablePool withReply:^(NSError * error)
	 {
		 if (!error)
		 {
			 NSString * title = [NSString stringWithFormat:
				NSLocalizedString(@"All pools imported",
								  @"Pool Import Success all")];
			 [self notifySuccessWithTitle:title text:nil];
		 }
		 [self handlePoolChangeReply:error];
	 }];
}

- (void)handlePoolChangeReply:(NSError*)error
{
	if (error)
	{
		[self notifyErrorFromHelper:error];
	}
	else
	{
		[[self poolWatcher] checkForChanges];
	}
}

@end
