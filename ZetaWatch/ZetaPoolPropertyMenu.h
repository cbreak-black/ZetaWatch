//
//  ZetaPoolPropertyMenu.h
//  ZetaWatch
//
//  Created by cbreak on 19.06.22.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "ZetaCommanderBase.h"

#include "ZFSUtils.hpp"

@interface ZetaPoolPropertyMenu : ZetaCommanderBase <NSMenuDelegate>

- (id)initWithPool:(zfs::ZPool)pool;

- (void)menuNeedsUpdate:(NSMenu*)menu;

@end
