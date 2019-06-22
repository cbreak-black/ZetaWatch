//
//  ZetaFileSystemPropertyMenuDelegate.h
//  ZetaWatch
//
//  Created by cbreak on 19.06.22.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "ZetaBaseDelegate.h"

#include "ZFSUtils.hpp"

NS_ASSUME_NONNULL_BEGIN

@interface ZetaFileSystemPropertyMenuDelegate : ZetaBaseDelegate <NSMenuDelegate>

- (id)initWithFileSystem:(zfs::ZFileSystem &&)fs;

- (void)menuNeedsUpdate:(NSMenu*)menu;

@end

NS_ASSUME_NONNULL_END
