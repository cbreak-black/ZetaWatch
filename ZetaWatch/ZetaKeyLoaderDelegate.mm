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
	[self showActionInProgress:NSLocalizedString(@"Loading Key...", @"LoadingKeyStatus")];
	NSString * pass = [_passwordField stringValue];
	[self clearPassword];
	NSDictionary * opts = @{@"filesystem": _representedFileSystem, @"key": pass};
	[_authorization loadKeyForFilesystem:opts withReply:^(NSError * error)
	 {
		 [self performSelectorOnMainThread:@selector(handleLoadKeyReply:) withObject:error waitUntilDone:NO];
	 }];
}

- (void)handleLoadKeyReply:(NSError*)error
{
	[self completeAction];
	if (error)
	{
		[self showError:[error localizedDescription]];
	}
	else
	{
		[_popover performClose:self];
	}
}

- (void)showActionInProgress:(NSString*)action
{
	[_statusField setStringValue:action];
	[_statusField setTextColor:[NSColor textColor]];
	[_statusField setHidden:NO];
	[_progressIndicator startAnimation:self];
}

- (void)completeAction
{
	[_progressIndicator stopAnimation:self];
	[self hideStatus];
}

- (void)showError:(NSString*)error
{
	[_statusField setStringValue:error];
	[_statusField setTextColor:[NSColor systemRedColor]];
	[_statusField setHidden:NO];
}

- (void)hideStatus
{
	[_statusField setHidden:YES];
}

- (void)clearPassword
{
	// The password is copied all over the place by the view, the dictionary
	// and the IPC, so trying to clear it is probably a waste of time.
	[_passwordField setStringValue:@""];
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
	[self clearPassword];
	[_passwordField abortEditing];
	[self hideStatus];
}

@end
