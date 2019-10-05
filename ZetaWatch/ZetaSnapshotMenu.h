//
//  ZetaSnapshotMenu.h
//  ZetaWatch
//
//  Created by cbreak on 19.10.05.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZetaCommanderBase.h"

#include "ZFSUtils.hpp"

NS_ASSUME_NONNULL_BEGIN

@interface ZetaSnapshotMenu : ZetaCommanderBase <NSMenuDelegate>

- (id)initWithFileSystem:(zfs::ZFileSystem)fs;

- (void)menuNeedsUpdate:(NSMenu*)menu;

@end

NS_ASSUME_NONNULL_END
