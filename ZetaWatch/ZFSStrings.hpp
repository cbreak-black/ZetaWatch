//
//  ZFSStrings.hpp
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.25.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted
//  provided that the conditions of the "3-Clause BSD" license described in the BSD.LICENSE file are met.
//  Additional licensing options are described in the README file.
//

#ifndef ZETA_ZFSSTRINGS_HPP
#define ZETA_ZFSSTRINGS_HPP

#include <libzfs.h>

#import <Foundation/NSString.h>

namespace zfs
{
	/*!
	 Returns a string with english human-facing description of the zpool status.
	 */
	char const * to_string(zpool_status_t stat);

	/*!
	 Returns a localized string description of the zpool status.
	 */
	NSString * to_localized_nsstring(zpool_status_t stat);

	/*!
	 Returns a string with english human-facing description of the vdev status.
	 */
	char const * to_string(vdev_state_t stat, vdev_aux_t aux);

	/*!
	 Returns a localized string description of the vdev status.
	 */
	NSString * to_localized_nsstring(vdev_state_t stat, vdev_aux_t aux);
}

#endif
