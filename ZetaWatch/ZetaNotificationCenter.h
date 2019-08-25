//
//  ZetaNotificationCenter.h
//  ZetaWatch
//
//  Created by cbreak on 19.08.25.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ZetaNotification : NSObject
{
}

@property (readonly) NSString * title;

@end

@interface ZetaNotificationCenter : NSObject
{
}

- (ZetaNotification*)startAction:(NSString*)title;
- (void)stopAction:(ZetaNotification*)notification;

@property (readonly) NSArray<ZetaNotification*> * inProgressActions;

@end
