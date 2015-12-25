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

	LibZFSHandle::LibZFSHandle(LibZFSHandle && other) :
	m_handle(other.m_handle)
	{
		other.m_handle = nullptr;
	}

	LibZFSHandle & LibZFSHandle::operator=(LibZFSHandle && other)
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
	}

	ZPool::ZPool(ZPool && other) :
		m_handle(other.m_handle)
	{
		other.m_handle = nullptr;
	}

	ZPool & ZPool::operator=(ZPool && other)
	{
		m_handle = other.m_handle;
		other.m_handle = nullptr;
		return *this;
	}

	char const * ZPool::name() const
	{
		return zpool_get_name(m_handle);
	}

	zpool_status_t ZPool::status() const
	{
		char * cp = nullptr;
		zpool_errata_t errata = {};
		zpool_status_t stat = zpool_get_status(m_handle, &cp, &errata);
		return stat;
	}

	zpool_handle_t * ZPool::handle() const
	{
		return m_handle;
	}

	bool healthy(zpool_status_t stat)
	{
		switch (stat)
		{
			case ZPOOL_STATUS_OK:
			case ZPOOL_STATUS_VERSION_OLDER:
			case ZPOOL_STATUS_FEAT_DISABLED:
				return true;
			default:
				return false;
		}
	}

	char const * to_string(zpool_status_t stat)
	{
		switch (stat)
		{
			case ZPOOL_STATUS_CORRUPT_CACHE:
				return "corrupt /kernel/drv/zpool.cache";
			case ZPOOL_STATUS_MISSING_DEV_R:
				return "missing device with replicas";
			case ZPOOL_STATUS_MISSING_DEV_NR:
				return "missing device with no replicas";
			case ZPOOL_STATUS_CORRUPT_LABEL_R:
				return "bad device label with replicas";
			case ZPOOL_STATUS_CORRUPT_LABEL_NR:
				return "bad device label with no replicas";
			case ZPOOL_STATUS_BAD_GUID_SUM:
				return "sum of device guids didn't match";
			case ZPOOL_STATUS_CORRUPT_POOL:
				return "pool metadata is corrupted";
			case ZPOOL_STATUS_CORRUPT_DATA:
				return "data errors in user (meta)data";
			case ZPOOL_STATUS_FAILING_DEV:
				return "device experiencing errors";
			case ZPOOL_STATUS_VERSION_NEWER:
				return "newer on-disk version";
			case ZPOOL_STATUS_HOSTID_MISMATCH:
				return "last accessed by another system";
			case ZPOOL_STATUS_IO_FAILURE_WAIT:
				return "failed I/O, failmode 'wait'";
			case ZPOOL_STATUS_IO_FAILURE_CONTINUE:
				return "failed I/O, failmode 'continue'";
			case ZPOOL_STATUS_BAD_LOG:
				return "cannot read log chain(s)";
			case ZPOOL_STATUS_ERRATA:
				return "informational errata available";
			case ZPOOL_STATUS_UNSUP_FEAT_READ:
				return "unsupported features for read";
			case ZPOOL_STATUS_UNSUP_FEAT_WRITE:
				return "unsupported features for write";
			case ZPOOL_STATUS_FAULTED_DEV_R:
				return "faulted device with replicas";
			case ZPOOL_STATUS_FAULTED_DEV_NR:
				return "faulted device with no replicas";
			case ZPOOL_STATUS_VERSION_OLDER:
				return "older legacy on-disk version";
			case ZPOOL_STATUS_FEAT_DISABLED:
				return "upported features are disabled";
			case ZPOOL_STATUS_RESILVERING:
				return "device being resilvered";
			case ZPOOL_STATUS_OFFLINE_DEV:
				return "device offline";
			case ZPOOL_STATUS_REMOVED_DEV:
				return "removed device";
			case ZPOOL_STATUS_OK:
				return "ok";
		}
		return "unknown status";
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
}
