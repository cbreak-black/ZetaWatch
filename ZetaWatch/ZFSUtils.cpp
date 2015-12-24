//
//  ZFSUtils.cpp
//  ZetaWatch
//
//  Created by Gerhard Röthlin on 2015.12.24.
//  Copyright © 2015 the-color-black.net. All rights reserved.
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

	zpool_handle_t * ZPool::handle() const
	{
		return m_handle;
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

	void zpool_iter(LibZFSHandle const & handle, std::function<void(ZPool)> callback)
	{
		ZPoolCallback cb(callback);
		zpool_iter(handle.handle(), &ZPoolCallback::handle_s, &cb);
	}
}
