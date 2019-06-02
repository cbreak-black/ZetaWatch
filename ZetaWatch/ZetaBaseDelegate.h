//
//  ZetaBaseDelegate.h
//  ZetaWatch
//
//  Created by cbreak on 19.06.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#ifndef ZetaBaseDelegate_h
#define ZetaBaseDelegate_h

#import <Cocoa/Cocoa.h>

#import "ZetaAuthorization.h"

@interface ZetaBaseDelegate : NSObject
{
	IBOutlet ZetaAuthorization * _authorization;
}

- (void)errorFromHelper:(NSError*)error;

@end

#endif /* ZetaBaseDelegate_h */
