//
//  ZetaKeyLoaderDelegate.m
//  ZetaWatch
//
//  Created by cbreak on 19.06.16.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaKeyLoaderDelegate.h"

#include <deque>

@interface ZetaKeyLoaderDelegate ()
{
	std::deque<NSString*> filesystems;
}

@end

@implementation ZetaKeyLoaderDelegate

- (void)unlockFileSystem:(NSString*)filesystem
{
	[self addFilesystemToUnlock:filesystem];
	if (![_popover isShown])
		[self show];
}

- (void)show
{
	[self updateFileSystem];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	[_popover showRelativeToRect:NSMakeRect(0, 0, 0, 0)
						  ofView:[_statusItem button]
				   preferredEdge:NSRectEdgeMinY];
}

- (IBAction)loadKey:(id)sender
{
	[self showActionInProgress:NSLocalizedString(@"Loading Key...", @"LoadingKeyStatus")];
	NSString * pass = [_passwordField stringValue];
	[self clearPassword];
	NSDictionary * opts = @{@"filesystem": [self representedFilesystem], @"key": pass};
	[_authorization loadKeyForFilesystem:opts withReply:^(NSError * error)
	 {
		 [self performSelectorOnMainThread:@selector(handleLoadKeyReply:) withObject:error waitUntilDone:NO];
	 }];
}

- (IBAction)skipFileSystem:(id)sender
{
	[self advanceFileSystem];
}

- (void)handleLoadKeyReply:(NSError*)error
{
	[self completeAction];
	if (error)
	{
		if ([error.domain isEqualToString:@"ZFSKeyError"])
		{
			[self showError:[error localizedDescription]];
		}
		else
		{
			[self errorFromHelper:error];
			[self advanceFileSystem];
		}
	}
	else
	{
		[self advanceFileSystem];
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

- (void)addFilesystemToUnlock:(NSString*)filesystem
{
	filesystems.push_back(filesystem);
}

- (NSString*)representedFilesystem
{
	if (filesystems.empty())
		return nullptr;
	return filesystems.front();
}

- (void)advanceFileSystem
{
	filesystems.pop_front();
	if (filesystems.empty())
	{
		[_popover performClose:self];
	}
	else
	{
		[self updateFileSystem];
	}
}

- (void)updateFileSystem
{
	if (filesystems.empty())
	{
		[_queryField setStringValue:@""];
	}
	else
	{
		[_queryField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Enter the password for %@", @"Password Query"), filesystems.front()]];
	}
}

- (BOOL)popoverShouldClose:(NSPopover *)popover
{
	if (!filesystems.empty())
	{
		filesystems.pop_front();
		if (filesystems.empty())
			return YES;
		[self updateFileSystem];
		return NO;
	}
	else
	{
		return YES;
	}
}

- (void)popoverWillShow:(NSNotification *)notification
{
}

- (void)popoverDidClose:(NSNotification *)notification
{
	[self clearPassword];
	[_passwordField abortEditing];
	[self hideStatus];
	filesystems.clear();
}

@end
