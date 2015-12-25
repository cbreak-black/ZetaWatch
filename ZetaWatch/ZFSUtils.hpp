//
//  ZFSUtils.hpp
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.24.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted
//  provided that the conditions of the "3-Clause BSD" license described in the BSD.LICENSE file are met.
//  Additional licensing options are described in the README file.
//

#ifndef ZETA_ZFSUTILS_HPP
#define ZETA_ZFSUTILS_HPP

#include <libzfs.h>
#include <libzfs_core.h>

#include <vector>
#include <functional>

namespace zfs
{
	/*!
	 \brief Represents libzfs initialization
	 */
	class LibZFSHandle
	{
	public:
		LibZFSHandle();
		~LibZFSHandle();

	public:
		LibZFSHandle(LibZFSHandle && other);
		LibZFSHandle & operator=(LibZFSHandle && other);

	public:
		libzfs_handle_t * handle() const;

	private:
		libzfs_handle_t * m_handle;
	};

	/*!
	 \brief Represents a ZPool
	 */
	class ZPool
	{
	public:
		explicit ZPool(zpool_handle_t * handle);
		~ZPool();

	public:
		ZPool(ZPool && other);
		ZPool & operator=(ZPool && other);

	public:
		char const * name() const;
		zpool_status_t status() const;

	public:
		zpool_handle_t * handle() const;

	private:
		zpool_handle_t * m_handle;
	};

	/*!
	 Returns wether the given status indicates a healty pool.
	 */
	bool healthy(zpool_status_t stat);

	/*!
	 Returns a vector of all pools.
	 */
	std::vector<ZPool> zpool_list(LibZFSHandle const & handle);

	/*!
	 Iterates over all pools.
	 */
	void zpool_iter(LibZFSHandle const & handle, std::function<void(ZPool)> callback);
}

#endif
