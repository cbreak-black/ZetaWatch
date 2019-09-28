//
//  ZetaCommanderBase.h
//  ZetaWatch
//
//  Created by cbreak on 19.06.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#ifndef ZetaMenuBase_h
#define ZetaMenuBase_h

#import <Cocoa/Cocoa.h>

#import "ZetaAuthorization.h"

#include "ZetaFormatHelpers.hpp"

@interface ZetaCommanderBase : NSObject
{
	IBOutlet ZetaAuthorization * _authorization;
}

- (void)notifySuccessWithTitle:(NSString*)title text:(NSString*)text;
- (void)notifyErrorFromHelper:(NSError*)error;

- (IBAction)copyRepresentedObject:(id)sender;

@end

// C++ Variadic Templates and Objective-C Vararg functions don't work well together
inline NSString * formatNSString(NSString * format)
{
	return format;
}

template<typename T>
NSString * formatNSString(NSString * format, T const & t)
{
	return [NSString stringWithFormat:format, toFormatable(t)];
}

template<typename T, typename U>
NSString * formatNSString(NSString * format, T const & t, U const & u)
{
	return [NSString stringWithFormat:format, toFormatable(t), toFormatable(u)];
}

template<typename T, typename U, typename V>
NSString * formatNSString(NSString * format, T const & t, U const & u, V const & v)
{
	return [NSString stringWithFormat:format, toFormatable(t), toFormatable(u), toFormatable(v)];
}

template<typename... T>
NSMenuItem * addMenuItem(NSMenu * menu, ZetaCommanderBase * delegate,
						 NSString * format, T const & ... t)
{
	auto title = formatNSString(format, t...);
	auto item = [menu addItemWithTitle:title action:@selector(copyRepresentedObject:) keyEquivalent:@""];
	item.representedObject = title;
	item.target = delegate;
	return item;
}

#endif /* ZetaMenuBase_h */
