//
//  ZetaFileSystemPropertyMenu.h
//  ZetaWatch
//
//  Created by cbreak on 19.06.22.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "ZetaMenuBase.h"

#include "ZFSUtils.hpp"

@interface ZetaFileSystemPropertyMenu : ZetaMenuBase <NSMenuDelegate>

- (id)initWithFileSystem:(zfs::ZFileSystem &&)fs;

- (void)menuNeedsUpdate:(NSMenu*)menu;

@end
