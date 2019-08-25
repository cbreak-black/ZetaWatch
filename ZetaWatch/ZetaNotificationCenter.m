//
//  ZetaNotificationCenter.m
//  ZetaWatch
//
//  Created by cbreak on 19.08.25.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import "ZetaNotificationCenter.h"

@implementation ZetaNotification
{
}

- (id)initWithTitle:(NSString*)title
{
	if (self = [super init])
	{
		self->title = title;
	}
	return self;
}

@synthesize title;

@end

@implementation ZetaNotificationCenter
{
	NSMutableArray<ZetaNotification*> * inProgressActions;
}

- (id)init
{
	if (self = [super init])
	{
		inProgressActions = [[NSMutableArray alloc] init];
	}
	return self;
}

- (ZetaNotification*)startAction:(NSString*)title
{
	ZetaNotification * notification = [[ZetaNotification alloc] initWithTitle:title];
	[inProgressActions addObject:notification];
	return notification;
}

- (void)stopAction:(ZetaNotification*)notification
{
	[inProgressActions removeObject:notification];
}

@synthesize inProgressActions;

@end
