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

#include <libzfs.h>
#include <libzfs_core.h>

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

	std::vector<ZPool> zpool_list(LibZFSHandle const & handle)
	{
		std::vector<ZPool> zpools;
		ZPoolCallback cb([&](ZPool pool)
		 {
			 zpools.push_back(std::move(pool));
		 });
		zpool_iter(handle.handle(), &ZPoolCallback::handle_s, &cb);
		return zpools;
	}

	void zpool_iter(LibZFSHandle const & handle, std::function<void(ZPool)> callback)
	{
		ZPoolCallback cb(callback);
		zpool_iter(handle.handle(), &ZPoolCallback::handle_s, &cb);
	}

	std::string vdevType(NVList const & vdev)
	{
		return vdev.lookup<std::string>(ZPOOL_CONFIG_TYPE);
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

	VDevStat vdevStat(NVList const & vdev)
	{
		auto statVec = vdev.lookup<std::vector<uint64_t>>(ZPOOL_CONFIG_VDEV_STATS);
		vdev_stat_t zfsStat = {};
		if (sizeof(zfsStat) != statVec.size() * sizeof(uint64_t))
			throw std::logic_error("Internal nvlist structure is inconsistent");
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
