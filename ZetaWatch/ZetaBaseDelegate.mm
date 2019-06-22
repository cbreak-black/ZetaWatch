//
//  ZetaBaseDelegate.mm
//  ZetaWatch
//
//  Created by cbreak on 19.06.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaBaseDelegate.h"

@implementation ZetaBaseDelegate

- (void)errorFromHelper:(NSError*)error
{
	NSUserNotification * notification = [[NSUserNotification alloc] init];
	notification.title = NSLocalizedString(@"Helper Error", @"Helper Error notification Title");
	NSString * errorFormat = NSLocalizedString(@"Helper encountered an error: %@.", @"Helper Error notification Format");
	notification.informativeText = [NSString stringWithFormat:errorFormat, [error localizedDescription]];
	notification.hasActionButton = NO;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (IBAction)copyRepresentedObject:(id)sender
{
	NSPasteboard * pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb writeObjects:@[[sender representedObject]]];
}

@end
