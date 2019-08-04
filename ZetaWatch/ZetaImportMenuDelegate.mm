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
	[menu addItemWithTitle:@"Searching for importable Pools..." action:NULL keyEquivalent:@""];
	[_authorization importablePoolsWithReply:^(NSError * error, NSDictionary * importablePools)
	 {
		 if (error)
		 {
			 [self importablePoolsError:error];
		 }
		 else
		 {
			 [self importablePoolsDiscovered:importablePools];
		 }
	 }];
}

- (void)importablePoolsDiscovered:(NSDictionary*)importablePools
{
	if ([importablePools count] > 0)
	{
		NSMenuItem * item = [_importMenu itemAtIndex:2];
		[item setTitle:[NSString stringWithFormat:
						@"%lu importable Pools found", [importablePools count]]];
		for (NSNumber * guid in importablePools)
		{
			NSString * title = [NSString stringWithFormat:@"%@ (%llu)", importablePools[guid], [guid unsignedLongLongValue]];
			NSMenuItem * item = [_importMenu addItemWithTitle:title action:@selector(importPool:) keyEquivalent:@""];
			[item setAction:@selector(importPool:)];
			[item setTarget:self];
			[item setRepresentedObject:guid];
		}
	}
	else
	{
		NSMenuItem * item = [_importMenu itemAtIndex:2];
		[item setTitle:@"No importable Pools found"];
	}
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
