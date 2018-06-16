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

#include "ZFSNVList.hpp"

#include <vector>
#include <functional>

// libzfs.h forward declarations
typedef struct zfs_handle zfs_handle_t;
typedef struct zpool_handle zpool_handle_t;
typedef struct libzfs_handle libzfs_handle_t;

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
		LibZFSHandle(LibZFSHandle && other) noexcept;
		LibZFSHandle & operator=(LibZFSHandle && other) noexcept;

	public:
		libzfs_handle_t * handle() const;

	private:
		libzfs_handle_t * m_handle;
	};

	/*!
	 */
	class ZFileSystem
	{
	public:
		enum Type
		{
			filesystem	= (1 << 0),
			snapshot	= (1 << 1),
			volume		= (1 << 2),
			pool		= (1 << 3),
			bookmark	= (1 << 4)
		};

		enum KeyStatus
		{
			none = 0,
			unavailable = 1,
			available = 2
		};

	public:
		explicit ZFileSystem(zfs_handle_t * handle);
		~ZFileSystem();

	public:
		ZFileSystem(ZFileSystem && other) noexcept;
		ZFileSystem & operator=(ZFileSystem && other) noexcept;

	public:
		char const * name() const;
		bool mounted() const;
		Type type() const;
		bool isEncryptionRoot() const;
		std::pair<std::string, bool> encryptionRoot() const;
		KeyStatus keyStatus() const;

	public:
		//! \returns all direct child filesystems
		std::vector<ZFileSystem> childFileSystems() const;

		//! \returns all direct and indirect child filesystems
		std::vector<ZFileSystem> allFileSystems() const;

	private:
		zfs_handle_t * m_handle;
	};

	/*!
	 \brief Represents a ZPool
	 */
	class ZPool
	{
	public:
		// Takes ownership
		explicit ZPool(zpool_handle_t * handle);
		~ZPool();

	public:
		ZPool(ZPool && other) noexcept;
		ZPool & operator=(ZPool && other) noexcept;

	public:
		char const * name() const;
		uint64_t status() const; //!< zpool_status_t
		NVList config() const;
		std::vector<zfs::NVList> vdevs() const;

	public:
		//! \returns the root filesystem
		ZFileSystem rootFileSystem() const;

		//! \returns all child filesystems, recursively
		std::vector<ZFileSystem> allFileSystems() const;

	public:
		zpool_handle_t * handle() const;

	private:
		zpool_handle_t * m_handle;
	};

	/*!
	 Returns wether the given status indicates a healty pool.
	 */
	bool healthy(uint64_t zpoolStatus);

	/*!
	 Returns a vector of all pools.
	 */
	std::vector<ZPool> zpool_list(LibZFSHandle const & handle);

	/*!
	 Iterates over all pools.
	 */
	void zpool_iter(LibZFSHandle const & handle, std::function<void(ZPool)> callback);

	/*!
	 \returns A string describing the type of the vdev
	 */
	std::string vdevType(NVList const & vdev);

	/*!
	 \returns A string describing the path of the vdev
	 */
	std::string vdevPath(NVList const & vdev);

	/*!
	 \returns The GUID of the given vdev / device config.
	 */
	uint64_t vdevGUID(NVList const & vdev);

	/*!
	 \returns the Pool GUID of the given pool.
	 */
	uint64_t poolGUID(NVList const & vdev);

	/*!
	 \returns A vector containing the children of this vdev
	 */
	std::vector<NVList> vdevChildren(NVList const & vdev);

	/*!
	 A stripped down replacement for libzfs' vdev_stat struct. It will be extended as needed when
	 more information is required.
	 */
	struct VDevStat
	{
		uint64_t state;
		uint64_t aux;
		uint64_t alloc;
		uint64_t space;
		uint64_t deflatedSpace;
		uint64_t errorRead;
		uint64_t errorWrite;
		uint64_t errorChecksum;
	};

	/*!
	 \returns A struct describing the status of the given vdev
	 */
	VDevStat vdevStat(NVList const & vdev);

	/*!
	 A stripped down replacement for libzfs' scan_stat struct. It will be extended as needed when
	 more information is required.
	 */
	struct ScanStat
	{
		enum Func { funcNone, scrub, resilver };
		enum State { stateNone, scanning, finished, canceled };
		Func func;
		State state;
		uint64_t toExamine;
		uint64_t examined;
	};

	/*!
	 \returns A struct describing the scan status of the given vdev
	 */
	ScanStat scanStat(NVList const & vdev);
}

#endif
