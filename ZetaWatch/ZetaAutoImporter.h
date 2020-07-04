//
//  ZetaAutoImporter.h
//  ZetaWatch
//
//  Created by cbreak on 19.08.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZetaCommanderBase.h"
#import "ZetaPoolWatcher.h"

#include "ZFSUtils.hpp"

#include <vector>

@interface ZetaAutoImporter : ZetaCommanderBase

- (id)init;

@property (readonly) std::vector<zfs::ImportablePool> const & importablePools;

@end
