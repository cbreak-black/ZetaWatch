//
//  ZetaAutoImporter.h
//  ZetaWatch
//
//  Created by cbreak on 19.08.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZetaMenuBase.h"
#import "ZetaPoolWatcher.h"

#include "ZFSUtils.hpp"

#include <vector>

@interface ZetaAutoImporter : ZetaMenuBase<ZetaPoolWatcherDelegate>

- (id)init;

@property (weak) IBOutlet ZetaPoolWatcher * poolWatcher;

@property (readonly) std::vector<zfs::ImportablePool> const & importablePools;

@end
