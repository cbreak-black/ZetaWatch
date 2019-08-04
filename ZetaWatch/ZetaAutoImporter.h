//
//  ZetaAutoImporter.h
//  ZetaWatch
//
//  Created by cbreak on 19.08.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZetaBaseDelegate.h"
#import "ZetaPoolWatcher.h"

#include <vector>

struct PoolID
{
	uint64_t guid;
	std::string name;
};

@interface ZetaAutoImporter : ZetaBaseDelegate<ZetaPoolWatcherDelegate>

- (id)init;

@property (weak) IBOutlet ZetaPoolWatcher * poolWatcher;

@property (readonly) std::vector<PoolID> const & importablePools;

@end
