#pragma once

#include <EASTL/internal/fixed_pool.h>

#include <cassert>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <netinet/in.h>
#include <deque>
#include <mutex>

// Shared constants matching EnetUv.cpp receive pool geometry.
inline constexpr size_t kEnetUvPacketPoolNodeSize = 65536;
inline constexpr size_t kEnetUvPacketPoolNodeCount = 512;
inline constexpr size_t kEnetUvMaxPoolRetainedQueuedDatagrams = 64;

using TEnetUvPacketPool = eastl::fixed_node_allocator<kEnetUvPacketPoolNodeSize, kEnetUvPacketPoolNodeCount, 16, 0, true>;

struct EnetUvDatagram
{
	sockaddr_in6 from{};
	ssize_t read = 0;
	char* data = nullptr;
	bool dataFromPool = false;

	~EnetUvDatagram()
	{
		if (dataFromPool)
		{
			// Pool-backed payloads must be released with ReleaseData(pool, lock) so nodes
			// return to the fixed allocator; destructor alone cannot recover the pool.
			assert(!data && "pool-backed EnetUv datagram was not released before destruction");
			return;
		}

		delete[] data;
		data = nullptr;
	}

	EnetUvDatagram() = default;

	EnetUvDatagram(EnetUvDatagram&& other) noexcept
		: from(other.from), read(other.read), data(other.data), dataFromPool(other.dataFromPool)
	{
		other.data = nullptr;
		other.dataFromPool = false;
	}

	EnetUvDatagram& operator=(EnetUvDatagram&& other) noexcept
	{
		if (this != &other)
		{
			if (dataFromPool)
			{
				assert(!data && "assign over pool-backed datagram without release");
			}
			else
			{
				delete[] data;
				data = nullptr;
			}
			from = other.from;
			read = other.read;
			data = other.data;
			dataFromPool = other.dataFromPool;
			other.data = nullptr;
			other.dataFromPool = false;
		}
		return *this;
	}

	EnetUvDatagram(const EnetUvDatagram&) = delete;
	EnetUvDatagram& operator=(const EnetUvDatagram&) = delete;

	void ReleaseData(TEnetUvPacketPool* pool, std::mutex* poolLock)
	{
		if (!data)
		{
			return;
		}

		if (dataFromPool)
		{
			assert(pool && poolLock);
			std::unique_lock<std::mutex> lock(*poolLock);
			pool->deallocate(data, TEnetUvPacketPool::kNodeSize);
		}
		else
		{
			delete[] data;
		}

		data = nullptr;
		dataFromPool = false;
	}
};

// Decides whether to retain the libuv pool buffer vs heap-copy (correctness under backlog).
inline bool EnetUvShouldRetainPoolBuffer(size_t bufLen, size_t nread, size_t recvQueueDepth)
{
	return nread > 0 && bufLen <= kEnetUvPacketPoolNodeSize
		&& recvQueueDepth < kEnetUvMaxPoolRetainedQueuedDatagrams;
}

inline void EnetUvReleaseUvBuffer(char* base, size_t bufLen, TEnetUvPacketPool* pool, std::mutex* poolLock)
{
	if (!base)
	{
		return;
	}

	if (bufLen > kEnetUvPacketPoolNodeSize)
	{
		free(base);
		return;
	}

	if (pool && poolLock)
	{
		std::unique_lock<std::mutex> lock(*poolLock);
		pool->deallocate(base, TEnetUvPacketPool::kNodeSize);
	}
}

inline bool EnetUvFillDatagramFromRecv(EnetUvDatagram& dgram, ssize_t nread, const char* base, size_t bufLen, size_t recvQueueDepth,
	bool& transferredPoolBuffer)
{
	transferredPoolBuffer = false;

	if (nread <= 0 || !base)
	{
		return false;
	}

	if (EnetUvShouldRetainPoolBuffer(bufLen, static_cast<size_t>(nread), recvQueueDepth))
	{
		dgram.data = const_cast<char*>(base);
		dgram.dataFromPool = true;
		transferredPoolBuffer = true;
		return true;
	}

	dgram.data = new char[static_cast<size_t>(nread)];
	memcpy(dgram.data, base, static_cast<size_t>(nread));
	dgram.dataFromPool = false;
	return true;
}
