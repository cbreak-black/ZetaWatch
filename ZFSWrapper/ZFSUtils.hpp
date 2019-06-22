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
#include <string>

// libzfs.h forward declarations
typedef struct zfs_handle zfs_handle_t;
typedef struct zpool_handle zpool_handle_t;
typedef struct libzfs_handle libzfs_handle_t;

namespace zfs
{
	class ZPool;
	class ZFileSystem;

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
		/*
		 Returns a filesystem loaded by name.
		 */
		ZFileSystem filesystem(std::string const & name) const;

	public:
		/*!
		 Returns a vector of all pools.
		 */
		std::vector<ZPool> pools() const;

		/*!
		 Iterates over all pools.
		 */
		void iterPools(std::function<void(ZPool)> callback) const;

		/*!
		 Returns the pool with the given name.
		 */
		ZPool pool(std::string const & name) const;

	public: // requires root permission
		struct Importable
		{
			std::string name;
			uint64_t guid;
		};

		/*!
		 Finds importable pools.
		 */
		std::vector<Importable> importablePools() const;

		/*!
		 Imports all pools.
		 */
		std::vector<ZPool> importAllPools() const;

		/*!
		 Imports a pool by name
		 */
		ZPool import(std::string const & name) const;

		/*!
		 Imports a pool by guid
		 */
		ZPool import(uint64_t guid) const;

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
		struct Property
		{
			std::string name;
			std::string value;
			std::string source;
		};

		enum Type
		{
			filesystem	= (1 << 0),
			snapshot	= (1 << 1),
			volume		= (1 << 2),
			pool		= (1 << 3),
			bookmark	= (1 << 4)
		};

		enum class KeyStatus
		{
			none = 0,
			unavailable = 1,
			available = 2
		};

	public:
		ZFileSystem();

		//! \brief Takes ownership
		explicit ZFileSystem(zfs_handle_t * handle);

		//! \brief Closes the file system handle
		~ZFileSystem();

	public:
		ZFileSystem(ZFileSystem && other) noexcept;
		ZFileSystem & operator=(ZFileSystem && other) noexcept;

	public:
		char const * name() const;
		bool mounted() const;
		Type type() const;
		std::uint64_t used() const;
		std::uint64_t available() const;
		std::uint64_t referenced() const;
		std::uint64_t logicalused() const;
		float compressRatio() const;
		std::string mountpoint() const;
		std::vector<Property> properties() const;
		bool isEncryptionRoot() const;
		std::pair<std::string, bool> encryptionRoot() const;
		KeyStatus keyStatus() const;

	public:
		//! \returns all direct child filesystems
		std::vector<ZFileSystem> childFileSystems() const;

		//! \returns all direct and indirect child filesystems
		std::vector<ZFileSystem> allFileSystems() const;

		//! Iterates over all direct child filesystems
		void iterChildFilesystems(std::function<void(ZFileSystem)> callback) const;

		//! Iterates over all child filesystems recursively
		void iterAllFileSystems(std::function<void(ZFileSystem)> callback) const;

	public: // requires root permission
		bool mount(); //!< Mount the filesystem if possible
		bool automount(); //!< Only try to mount the filesystem if it can be automounted
		bool unmount();
		bool loadKey(std::string const & key);
		bool unloadKey();

	private:
		zfs_handle_t * m_handle;
	};

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
		uint64_t fragmentation;
	};

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
		uint64_t total;
		uint64_t scanned;
		uint64_t issued;
		uint64_t passScanned;
		uint64_t passExamined;
		uint64_t passIssued;
		uint64_t passStartTime;
		uint64_t passPausedSeconds;
		uint64_t errors;
	};

	/*!
	 \brief Represents a ZPool
	 */
	class ZPool
	{
	public:
		struct Property
		{
			std::string name;
			std::string value;
		};

	public:
		ZPool();

		// Takes ownership
		explicit ZPool(zpool_handle_t * handle);

		// Opens a new pool handle
		explicit ZPool(libzfs_handle_t * zfsHandle, std::string const & name);

		// Closes pool handle
		~ZPool();

	public:
		ZPool(ZPool && other) noexcept;
		ZPool & operator=(ZPool && other) noexcept;

	public:
		char const * name() const;
		uint64_t status() const; //!< zpool_status_t
		NVList config() const;

	public:
		/*!
		 \returns A vector containing the children of this pool
		 */
		std::vector<zfs::NVList> vdevs() const;

		/*!
		 \returns A vector containing the cache devices of this pool
		 */
		std::vector<zfs::NVList> caches() const;

		/*!
		 \returns A struct describing the status of the pool
		 */
		VDevStat vdevStat() const;

		/*!
		 \returns A struct describing the scan status of the pool
		 */
		ScanStat scanStat() const;

		/*!
		 \returns The normal name of the given vdev
		 */
		std::string vdevName(zfs::NVList const & vdev) const;

		/*!
		 \returns The path to the underlying device
		 */
		std::string vdevDevice(zfs::NVList const & vdev) const;

		/*!
		 \returns All properties of this pool
		 */
		std::vector<Property> properties() const;

	public:
		//! \returns the root filesystem
		ZFileSystem rootFileSystem() const;

		//! \returns all child filesystems, recursively
		std::vector<ZFileSystem> allFileSystems() const;

		//! Iterates over all child filesystems recursively
		void iterAllFileSystems(std::function<void(ZFileSystem)> callback) const;

	public:
		//! Unmounts all filesystems and exports the pool
		void exportPool(bool force = false);

		//! Starts a scrub
		void scrub();

		//! Stops a scrub
		void scrubStop();

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
	 \returns A string describing the type of the vdev
	 */
	std::string vdevType(NVList const & vdev);

	/*!
	 \returns whether this vdev is a log vdev
	 */
	bool vdevIsLog(NVList const & vdev);

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
	 \returns A vector containing the cache devices of this vdev
	 */
	std::vector<NVList> vdevCaches(NVList const & vdev);

	/*!
	 \returns A struct describing the status of the given vdev
	 */
	VDevStat vdevStat(NVList const & vdev);

	/*!
	 \returns A struct describing the scan status of the given vdev
	 */
	ScanStat scanStat(NVList const & vdev);
}

#endif
