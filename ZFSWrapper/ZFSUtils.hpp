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

	struct ImportablePool
	{
		std::string name;
		uint64_t guid;
		uint64_t status;
	};

	/*!
	 \brief Represents libzfs initialization
	 */
	class LibZFSHandle
	{
	public:
		/*!
		 Opens a new lib zfs handle and owns it.
		 */
		LibZFSHandle();

		/*!
		 Adopts a handle from somewhere else, no ownership is transfered
		 */
		explicit LibZFSHandle(libzfs_handle_t * handle);

		/*!
		 Closes the associated handle if it is owned.
		 */
		~LibZFSHandle();

	public:
		LibZFSHandle(LibZFSHandle && other) noexcept;
		LibZFSHandle & operator=(LibZFSHandle && other) noexcept;

	public:
		struct Version
		{
			std::uint16_t major;
			std::uint16_t minor;
			std::uint16_t patch;

			friend bool operator==(Version const & a, Version const & b)
			{
				return (a.major == b.major &&
						a.minor == b.minor &&
						a.patch == b.patch);
			}
		};

		/*!
		 \returns the version of zfs that is loaded in kernel.
		 */
		static Version versionUserland();

		/*!
		 \returns the version of zfs libraries in userland.
		 */
		static Version versionKernel();

		/*!
		 \returns the version of zfs,
		 \throws a runtime error if userland and kernel don't agree.
		 */
		static Version version();

	public:
		/*!
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

	public: // Errors
		int lastErrorCode() const;
		std::string lastErrorAction() const;
		std::string lastErrorDescription() const;
		std::string lastError() const;
		void throwLastError(std::string const & action);

	public: // requires root permission

		/*!
		 Finds importable pools.
		 */
		std::vector<ImportablePool> importablePools() const;

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
		bool m_owned;
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

		enum class FSType
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

		enum class KeyLocation
		{
			none = 0,
			prompt = 1,
			uri = 2,
		};

	public:
		ZFileSystem();

		//! \brief Copies underlying handle
		explicit ZFileSystem(ZFileSystem const & handle);

		//! \brief Takes ownership
		explicit ZFileSystem(zfs_handle_t * handle);

		//! \brief Closes the file system handle
		~ZFileSystem();

	public:
		ZFileSystem(ZFileSystem && other) noexcept;
		ZFileSystem & operator=(ZFileSystem && other) noexcept;

	public:
		LibZFSHandle libHandle() const;

	public:
		char const * name() const;
		bool mounted() const;
		bool mountable() const;
		bool automountable() const;
		FSType type() const;
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
		KeyLocation keyLocation() const;
		bool isRoot() const;

	public:
		std::uint64_t cloneCount() const;

	public:
		//! \returns all direct child filesystems
		std::vector<ZFileSystem> childFileSystems() const;

		//! \returns all direct and indirect child filesystems
		std::vector<ZFileSystem> allFileSystems() const;

		//! \returns all snapshots
		std::vector<ZFileSystem> snapshots() const;

		//! \returns all snapshots
		std::vector<ZFileSystem> dependents() const;

		//! Iterates over all direct child filesystems
		int iterChildFilesystems(std::function<int(ZFileSystem)> callback) const;

		//! Iterates over all child filesystems recursively, visiting all parent
		//! filesystems before the children, including the filesystem itself.
		int iterAllFileSystems(std::function<int(ZFileSystem)> callback) const;

		//! Iterates over all child filesystems recursively, visiting all child
		//! filesystems before the parent filesystem. Also visits the filesystem
		//! itself.
		int iterAllFileSystemsReverse(std::function<int(ZFileSystem)> callback) const;

		//! Iterates over all snapshots
		int iterSnapshots(std::function<int(ZFileSystem)> callback) const;

		//! Iterates over all dependents (clones, filesystems, snapshots)
		int iterDependents(std::function<int(ZFileSystem)> callback) const;

	public: // requires root permission
		int mount(); //!< Mount the filesystem if possible
		int automount(); //!< Only try to mount the filesystem if it can be automounted
		int unmount(bool force = false); //!< Unmounts the filesystem
		int loadKeyFile(); //!< Load key from file if the key location is uri, or returns false
		int loadKey(std::string const & key); //!< Load the given key
		int unloadKey();
		int destroy(bool force = false);

	public: // recursive
		int mountRecursive();
		int automountRecursive();
		int unmountRecursive(bool force = false);
		int destroyRecursive(bool force = false);

	public: // Snapshot related
		int snapshot(std::string const & snapName, bool recursive);
		int rollback(bool force = false); //!< Roll back to this snapshot
		int clone(std::string const & newFSName); //!< Clone the snapshot into a dependent FS

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
		uint64_t passPauseTime;
		uint64_t passPausedSeconds;
		uint64_t errors;
		uint64_t scanStartTime;
		uint64_t scanEndTime;
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
		LibZFSHandle libHandle() const;

	public:
		char const * name() const;
		uint64_t guid() const;
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

		//! Iterates over all child filesystems recursively, visiting all parent
		//! filesystems before the children. This includes the root filesystem
		int iterAllFileSystems(std::function<int(ZFileSystem)> callback) const;

		//! Iterates over all child filesystems recursively, visiting all child
		//! filesystems before the parent filesystem. This includes the root
		//! filesystem
		int iterAllFileSystemsReverse(std::function<int(ZFileSystem)> callback) const;

	public:
		//! Unmounts all filesystems and exports the pool
		void exportPool(bool force = false);

		//! Starts a scrub
		void scrub();

		//! Pauses a scrub
		void scrubPause();

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

	// Helper Functions
	inline bool operator<(ImportablePool const & a, ImportablePool const & b)
	{
		return a.guid < b.guid;
	}
}

#endif
