//
//  ZetaImportMenu.h
//  ZetaWatch
//
//  Created by cbreak on 19.06.02.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#ifndef ZetaImportMenu_h
#define ZetaImportMenu_h

#import <Cocoa/Cocoa.h>

#import "ZetaAuthorization.h"
#import "ZetaMenuBase.h"
#import "ZetaAutoImporter.h"

@class ZetaPoolWatcher;

@interface ZetaImportMenu : ZetaMenuBase <NSMenuDelegate>

@property (weak) IBOutlet NSMenu * importMenu;
@property (weak) IBOutlet ZetaPoolWatcher * poolWatcher;
@property (weak) IBOutlet ZetaAutoImporter * autoImporter;

@end

#endif /* ZetaImportMenuDelegate_h */
