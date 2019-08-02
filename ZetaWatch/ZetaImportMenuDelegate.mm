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
		NSMenuItem * item = [_importMenu itemAtIndex:0];
		[item setTitle:[NSString stringWithFormat:
						@"%lu importable Pools found", [importablePools count]]];
		for (NSString * name in importablePools)
		{
			NSMenuItem * item = [_importMenu addItemWithTitle:name action:@selector(importPool:) keyEquivalent:@""];
			[item setTitle:[NSString stringWithFormat:@"%@ (%llu)", name, [importablePools[name] unsignedLongLongValue]]];
			[item setAction:@selector(importPool:)];
			[item setTarget:self];
			[item setRepresentedObject:importablePools[name]];
		}
	}
	else
	{
		NSMenuItem * item = [_importMenu itemAtIndex:0];
		[item setTitle:@"No importable Pools found"];
	}
}

- (void)importablePoolsError:(NSError*)error
{
	NSMenuItem * item = [_importMenu itemAtIndex:0];
	[item setTitle:[error localizedDescription]];
}

- (IBAction)importPool:(id)sender
{
	NSDictionary * pools = @{ @"poolGUID": [sender representedObject] };
	[_authorization importPools:pools withReply:^(NSError * error)
	 {
		 if (error)
			 [self errorFromHelper:error];
		 else
			 [[self poolWatcher] checkForChanges];
	 }];
}

@end
