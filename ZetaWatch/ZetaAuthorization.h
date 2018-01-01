//
//  ZetaAuthoized.h
//  ZetaWatch
//
//  Created by cbreak on 17.12.31.
//  Copyright © 2017 the-color-black.net. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZetaAuthorizationHelperProtocol.h"

/*!
 This class wraps privileged operations that require authorization.

 This is heavily based on apple's EvenBetterAuthorizationSample
 https://developer.apple.com/library/content/samplecode/EvenBetterAuthorizationSample/Introduction/Intro.html
 */
@interface ZetaAuthorization : NSObject <ZetaAuthorizationHelperProtocol>

//! Call this after the program finished starting
-(void)connectToAuthorization;

//! Internal function to install the helper tool if needed
-(void)autoinstall;

//! Internal function to force install the helper tool
-(void)install;

@end
