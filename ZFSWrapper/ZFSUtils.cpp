//
//  ZFSUtils.cpp
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.24.
//  Copyright © 2015 the-color-black.net. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted
//  provided that the conditions of the "3-Clause BSD" license described in the BSD.LICENSE file are met.
//  Additional licensing options are described in the README file.
//

#include "ZFSUtils.hpp"

#include <stdexcept>
#include <future>

#include <libzfs.h>
#include <libzfs_core.h>

extern "C"
{
	// From #include <sys/zfs_context_userland.h>
	extern void thread_init(void);
	extern void thread_fini(void);
}

namespace zfs
{
	LibZFSHandle::LibZFSHandle() :
		m_handle(libzfs_init())
	{
		if (m_handle == nullptr)
		{
			throw std::runtime_error(libzfs_error_init(errno));
		}
	}

	LibZFSHandle::~LibZFSHandle()
	{
		if (m_handle)
			libzfs_fini(m_handle);
	}

	LibZFSHandle::LibZFSHandle(LibZFSHandle && other) noexcept :
	m_handle(other.m_handle)
	{
		other.m_handle = nullptr;
	}

	LibZFSHandle & LibZFSHandle::operator=(LibZFSHandle && other) noexcept
	{
		m_handle = other.m_handle;
		other.m_handle = nullptr;
		return *this;
	}

	libzfs_handle_t * LibZFSHandle::handle() const
	{
		return m_handle;
	}

	ZFileSystem::ZFileSystem(zfs_handle_t * handle) : m_handle(handle)
	{
	}

	ZFileSystem::~ZFileSystem()
	{
		if (m_handle)
			zfs_close(m_handle);
	}

	ZFileSystem::ZFileSystem(ZFileSystem && other) noexcept :
		m_handle(other.m_handle)
	{
		other.m_handle = nullptr;
	}

	ZFileSystem & ZFileSystem::operator=(ZFileSystem && other) noexcept
	{
		m_handle = other.m_handle;
		other.m_handle = nullptr;
		return *this;
	}

	char const * ZFileSystem::name() const
	{
		return zfs_get_name(m_handle);
	}

	bool ZFileSystem::mounted() const
	{
		return zfs_is_mounted(m_handle, nullptr);
	}

	bool ZFileSystem::mount()
	{
		return !zfs_mount(m_handle, nullptr, 0);
	}

	bool ZFileSystem::unmount()
	{
		return !zfs_unmount(m_handle, nullptr, 0);
	}

	struct Pipe
	{
		int fd[2];
		int oldStdIn;

		Pipe() : fd{-1, -1}, oldStdIn(-1)
		{
			auto r = pipe(fd);
			if (r == -1)
			{
				throw std::runtime_error("Could not create password pipe");
			}
			oldStdIn = dup(0);
			if (oldStdIn == -1)
			{
				restore();
				throw std::runtime_error("FD dup Error");
			}
			auto res = dup2(fd[0], 0);
			if (res == -1)
			{
				restore();
				throw std::runtime_error("FD dup2 Error");
			}
		}

		~Pipe()
		{
			restore();
		}

		void restore()
		{
			// Ignore errors
			if (oldStdIn != -1)
			{
				dup2(oldStdIn, 0);
				close(oldStdIn);
			}
			if (fd[0] != -1)
				close(fd[0]);
			if (fd[1] != -1)
				close(fd[1]);
		}
	};

	bool ZFileSystem::loadKey(std::string const & key)
	{
		// Hackery needed because libzfs wants to read the password from the
		// standard input instead of accepting it as argument.
		Pipe p;
		auto future = std::async([&p, &key](){
			size_t r = 0;
			r = write(p.fd[1], key.data(), key.size());
			if (r == -1)
				return false;
			r = write(p.fd[1], "\n", 1);
			if (r == -1)
				return false;
			return true;
		});
		char prompt[] = "prompt";
		auto res = zfs_crypto_load_key(m_handle, B_FALSE, prompt);
		bool writeRes = future.get();
		return res == 0 && writeRes;
	}

	bool ZFileSystem::unloadKey()
	{
		auto res = zfs_crypto_unload_key(m_handle);
		return res == 0;
	}

	ZFileSystem::Type ZFileSystem::type() const
	{
		static_assert(filesystem == ZFS_TYPE_FILESYSTEM &&
					  snapshot == ZFS_TYPE_SNAPSHOT &&
					  volume == ZFS_TYPE_VOLUME &&
					  pool == ZFS_TYPE_POOL &&
					  bookmark == ZFS_TYPE_BOOKMARK,
					  "ZFileSystem::Type == zfs_type_t");
		return static_cast<Type>(zfs_get_type(m_handle));
	}

	bool ZFileSystem::isEncryptionRoot() const
	{
		boolean_t root = B_FALSE;
		if (zfs_crypto_get_encryption_root(m_handle, &root, nullptr))
		{
			return root == B_TRUE;
		}
		return false;
	}

	std::pair<std::string, bool> ZFileSystem::encryptionRoot() const
	{
		boolean_t root = B_FALSE;
		// MAXNAMELEN == 256 from spl's include/sys/sysmacros.h
		std::string rootName(256+1, '\0');
		zfs_crypto_get_encryption_root(m_handle, &root, &rootName[0]);
		rootName.resize(std::strlen(rootName.data()));
		return {rootName, root == B_TRUE};
	}

	ZFileSystem::KeyStatus ZFileSystem::keyStatus() const
	{
		static_assert(none == (int)ZFS_KEYSTATUS_NONE &&
					  unavailable == (int)ZFS_KEYSTATUS_UNAVAILABLE &&
					  available == (int)ZFS_KEYSTATUS_AVAILABLE,
					  "ZFileSystem::KeyStatus == zfs_keystatus");
		return static_cast<KeyStatus>(zfs_prop_get_int(m_handle, ZFS_PROP_KEYSTATUS));
	}

	namespace
	{
		struct ZFileSystemCallback
		{
			ZFileSystemCallback(std::function<void(ZFileSystem)> callback) :
				m_callback(callback)
			{
			}

			int handle(zfs_handle_t * fs)
			{
				m_callback(ZFileSystem(fs));
				return 0;
			}

			static int handle_s(zfs_handle_t * fs, void * stored_this)
			{
				return static_cast<ZFileSystemCallback*>(stored_this)->handle(fs);
			}

			std::function<void(ZFileSystem)> m_callback;
		};
	}

	std::vector<ZFileSystem> ZFileSystem::childFileSystems() const
	{
		std::vector<ZFileSystem> children;
		ZFileSystemCallback cb([&](ZFileSystem fs)
		{
			children.push_back(std::move(fs));
		});
		zfs_iter_filesystems(m_handle, ZFileSystemCallback::handle_s, &cb);
		return children;
	}

	std::vector<ZFileSystem> ZFileSystem::allFileSystems() const
	{
		std::vector<ZFileSystem> children;
		ZFileSystemCallback cb([&](ZFileSystem fs)
		{
			children.push_back(std::move(fs));
			zfs_iter_filesystems(children.back().m_handle, ZFileSystemCallback::handle_s, &cb);
		});
		zfs_iter_filesystems(m_handle, ZFileSystemCallback::handle_s, &cb);
		return children;
	}

	void ZFileSystem::childFilesystems(std::function<void(ZFileSystem)> callback) const
	{
		ZFileSystemCallback cb(std::move(callback));
		zfs_iter_filesystems(m_handle, ZFileSystemCallback::handle_s, &cb);
	}

	void ZFileSystem::allFileSystems(std::function<void(ZFileSystem)> callback) const
	{
		ZFileSystemCallback cb([&](ZFileSystem fs)
		{
			ZFileSystem fsc(zfs_handle_dup(fs.m_handle));
			callback(std::move(fs));
			zfs_iter_filesystems(fsc.m_handle, ZFileSystemCallback::handle_s, &cb);
		});
		zfs_iter_filesystems(m_handle, ZFileSystemCallback::handle_s, &cb);
	}

	ZPool::ZPool(zpool_handle_t * handle) :
		m_handle(handle)
	{
	}

	ZPool::~ZPool()
	{
		if (m_handle)
			zpool_close(m_handle);
	}

	ZPool::ZPool(ZPool && other) noexcept :
		m_handle(other.m_handle)
	{
		other.m_handle = nullptr;
	}

	ZPool & ZPool::operator=(ZPool && other) noexcept
	{
		m_handle = other.m_handle;
		other.m_handle = nullptr;
		return *this;
	}

	char const * ZPool::name() const
	{
		return zpool_get_name(m_handle);
	}

	uint64_t ZPool::status() const
	{
		char * cp = nullptr;
		zpool_errata_t errata = {};
		zpool_status_t stat = zpool_get_status(m_handle, &cp, &errata);
		return stat;
	}

	NVList ZPool::config() const
	{
		return NVList(zpool_get_config(m_handle, nullptr));
	}

	std::vector<zfs::NVList> ZPool::vdevs() const
	{
		auto vdevtree = config().lookup<zfs::NVList>(ZPOOL_CONFIG_VDEV_TREE);
		return vdevChildren(vdevtree);
	}

	std::vector<zfs::NVList> ZPool::caches() const
	{
		auto vdevtree = config().lookup<zfs::NVList>(ZPOOL_CONFIG_VDEV_TREE);
		return vdevCaches(vdevtree);
	}

	VDevStat ZPool::vdevStat() const
	{
		VDevStat vdevStat(NVList const & vdev);
		auto vdevtree = config().lookup<zfs::NVList>(ZPOOL_CONFIG_VDEV_TREE);
		return vdevStat(vdevtree);
	}

	ScanStat ZPool::scanStat() const
	{
		ScanStat scanStat(NVList const & vdev);
		auto vdevtree = config().lookup<zfs::NVList>(ZPOOL_CONFIG_VDEV_TREE);
		return scanStat(vdevtree);
	}

	ZFileSystem ZPool::rootFileSystem() const
	{
		auto lib = zpool_get_handle(m_handle);
		auto name = zpool_get_name(m_handle);
		auto fs = zfs_open(lib, name, ZFS_TYPE_FILESYSTEM);
		if (!fs)
			throw std::runtime_error("Unable to open root filesystem");
		return ZFileSystem(fs);
	}

	std::vector<ZFileSystem> ZPool::allFileSystems() const
	{
		auto root = rootFileSystem();
		std::vector<ZFileSystem> fileSystems = root.allFileSystems();
		fileSystems.insert(fileSystems.begin(), std::move(root));
		return fileSystems;
	}

	void ZPool::allFileSystems(std::function<void(ZFileSystem)> callback) const
	{
		callback(rootFileSystem());
		rootFileSystem().allFileSystems(callback);
	}

	zpool_handle_t * ZPool::handle() const
	{
		return m_handle;
	}

	bool healthy(uint64_t stat)
	{
		switch (zpool_status_t(stat))
		{
			case ZPOOL_STATUS_OK:
			case ZPOOL_STATUS_VERSION_OLDER:
			case ZPOOL_STATUS_FEAT_DISABLED:
				return true;
			default:
				return false;
		}
	}

	ZFileSystem LibZFSHandle::filesystem(std::string const & name) const
	{
		auto fs = zfs_open(handle(), name.c_str(), ZFS_TYPE_FILESYSTEM);
		if (fs == nullptr)
			throw std::runtime_error("Filesystem " + name + " does not exist");
		return ZFileSystem(fs);
	}

	namespace
	{
		struct ZPoolCallback
		{
			ZPoolCallback(std::function<void(ZPool)> callback) :
				m_callback(callback)
			{
			}

			int handle(zpool_handle_t * pool)
			{
				m_callback(ZPool(pool));
				return 0;
			}

			static int handle_s(zpool_handle_t * pool, void * stored_this)
			{
				return static_cast<ZPoolCallback*>(stored_this)->handle(pool);
			}

			std::function<void(ZPool)> m_callback;
		};
	}

	std::vector<ZPool> LibZFSHandle::pools() const
	{
		std::vector<ZPool> zpools;
		ZPoolCallback cb([&](ZPool pool)
		 {
			 zpools.push_back(std::move(pool));
		 });
		zpool_iter(handle(), &ZPoolCallback::handle_s, &cb);
		return zpools;
	}

	void LibZFSHandle::pools(std::function<void(ZPool)> callback) const
	{
		ZPoolCallback cb(callback);
		zpool_iter(handle(), &ZPoolCallback::handle_s, &cb);
	}

	std::vector<LibZFSHandle::Importable> LibZFSHandle::importablePools() const
	{
		importargs_t args = {};
		thread_init();
		auto list = NVList(zpool_search_import(handle(), &args), zfs::NVList::TakeOwnership());
		thread_fini();
		std::vector<Importable> pools;
		for (auto pair : list)
		{
			auto l = pair.convertTo<NVList>();
			pools.push_back({pair.name(), l.lookup<uint64_t>("pool_guid")});
		}
		return pools;
	}

	static bool import_with_args(libzfs_handle_t * handle, importargs_t * args)
	{
		thread_init();
		auto list = NVList(zpool_search_import(handle, args), zfs::NVList::TakeOwnership());
		thread_fini();
		bool success = true;
		for (auto pair : list)
		{
			auto l = pair.convertTo<NVList>();
			auto r = zpool_import(handle, l.toList(), nullptr, nullptr);
			success = (r == 0) && success;
		}
		return success;
	}

	bool LibZFSHandle::importAllPools() const
	{
		importargs_t args = {};
		return import_with_args(handle(), &args);
	}

	bool LibZFSHandle::import(std::string const & name) const
	{
		importargs_t args = {};
		args.poolname = const_cast<char*>(name.c_str());
		return import_with_args(handle(), &args);
	}

	bool LibZFSHandle::import(uint64_t guid) const
	{
		importargs_t args = {};
		args.guid = guid;
		return import_with_args(handle(), &args);
	}

	std::string vdevType(NVList const & vdev)
	{
		return vdev.lookup<std::string>(ZPOOL_CONFIG_TYPE);
	}

	bool vdevIsLog(NVList const & vdev)
	{
		uint64_t isLog = 0;
		vdev.lookup(ZPOOL_CONFIG_IS_LOG, isLog);
		return isLog;
	}

	std::string vdevPath(NVList const & vdev)
	{
		auto path = vdev.lookup<std::string>(ZPOOL_CONFIG_PATH);
		auto found = path.find_last_of('/');
		if (found != std::string::npos && found + 1 < path.size())
			path = path.substr(found + 1);
		return path;
	}

	uint64_t vdevGUID(NVList const & vdev)
	{
		return vdev.lookup<uint64_t>(ZPOOL_CONFIG_GUID);
	}

	uint64_t poolGUID(NVList const & vdev)
	{
		return vdev.lookup<uint64_t>(ZPOOL_CONFIG_POOL_GUID);
	}

	std::vector<NVList> vdevChildren(NVList const & vdev)
	{
		std::vector<zfs::NVList> children;
		vdev.lookup<std::vector<zfs::NVList>>(ZPOOL_CONFIG_CHILDREN, children);
		return children;
	}

	std::vector<NVList> vdevCaches(NVList const & vdev)
	{
		std::vector<zfs::NVList> caches;
		vdev.lookup<std::vector<zfs::NVList>>(ZPOOL_CONFIG_L2CACHE, caches);
		return caches;
	}

	VDevStat vdevStat(NVList const & vdev)
	{
		auto statVec = vdev.lookup<std::vector<uint64_t>>(ZPOOL_CONFIG_VDEV_STATS);
		vdev_stat_t zfsStat = {};
		if (sizeof(zfsStat) != statVec.size() * sizeof(uint64_t))
			throw std::logic_error("Internal nvlist structure size does not match vdev_stat_t size");
		// Note: this is somewhat non-portable but the equivalent C Code does the same
		std::copy(statVec.begin(), statVec.end(), reinterpret_cast<uint64_t*>(&zfsStat));
		VDevStat interfaceStat = {
			zfsStat.vs_state, zfsStat.vs_aux,
			zfsStat.vs_alloc, zfsStat.vs_space, zfsStat.vs_dspace,
			zfsStat.vs_read_errors, zfsStat.vs_write_errors, zfsStat.vs_checksum_errors
		};
		return interfaceStat;
	}

	ScanStat scanStat(NVList const & vdev)
	{
		ScanStat interfaceStat = { ScanStat::funcNone, ScanStat::stateNone };
		std::vector<uint64_t> statVec;
		if (!vdev.lookup<std::vector<uint64_t>>(ZPOOL_CONFIG_SCAN_STATS, statVec))
			return interfaceStat;
		pool_scan_stat_t scanStat = {};
		// Internal nvlist structure is inconsistent, not critical
		if (sizeof(scanStat) != statVec.size() * sizeof(uint64_t))
			return interfaceStat;
		// Note: this is somewhat non-portable but the equivalent C Code does the same
		std::copy(statVec.begin(), statVec.end(), reinterpret_cast<uint64_t*>(&scanStat));
		interfaceStat.func = static_cast<ScanStat::Func>(scanStat.pss_func);
		interfaceStat.state = static_cast<ScanStat::State>(scanStat.pss_state);
		interfaceStat.toExamine = scanStat.pss_to_examine;
		interfaceStat.examined = scanStat.pss_examined;
		return interfaceStat;
	}

}
