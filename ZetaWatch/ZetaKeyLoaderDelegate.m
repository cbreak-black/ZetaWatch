//
//  ZetaKeyLoaderDelegate.m
//  ZetaWatch
//
//  Created by cbreak on 19.06.16.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaKeyLoaderDelegate.h"

@interface ZetaKeyLoaderDelegate ()

@end

@implementation ZetaKeyLoaderDelegate

- (IBAction)loadKey:(id)sender
{
	// The password is copied all over the place by the view, the dictionary
	// and the IPC, so trying to clear it is probably a waste of time.
	NSString * pass = [_passwordField stringValue];
	NSDictionary * opts = @{@"filesystem": _representedFileSystem, @"key": pass};
	[_authorization loadKeyForFilesystem:opts withReply:^(NSError * error)
	 {
		 [self performSelectorOnMainThread:@selector(handleLoadKeyReply:) withObject:error waitUntilDone:NO];
	 }];
}

- (void)handleLoadKeyReply:(NSError*)error
{
	if (error)
	{
		[self.errorField setStringValue:[error localizedDescription]];
		[self.errorField setHidden:NO];
	}
	else
	{
		[self.popover performClose:self];
	}
}

- (BOOL)popoverShouldDetach:(NSPopover *)popover
{
	return YES;
}

- (NSString*)representedFilesystem
{
	return _representedFileSystem;
}

- (void)setRepresentedFileSystem:(NSString *)representedFileSystem
{
	_representedFileSystem = representedFileSystem;
	[_queryField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Enter the password for %@", @"Password Query"), _representedFileSystem]];
}

- (void)popoverWillShow:(NSNotification *)notification
{
}

- (void)popoverDidClose:(NSNotification *)notification
{
	[_passwordField setStringValue:@""];
	[_passwordField abortEditing];
	[_errorField setHidden:YES];
}

@end
