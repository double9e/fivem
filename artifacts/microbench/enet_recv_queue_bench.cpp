// Isolated microbenchmark: models EnetUv UDP recv queue path (NOT FXServer artifact timing).
// Compares baseline (pool alloc + memcpy into new[] + memcpy to ENet)
// vs optimized (retain pool buffer + single memcpy to ENet).

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <vector>

static constexpr size_t kPoolNodeSize = 65536;
static constexpr size_t kPacketSize = 1200;
static constexpr size_t kPacketsPerTrial = 2'000'000;
static constexpr size_t kEnetBufSize = 1400;

struct Pool
{
	std::vector<char*> freeList;
	char* slab = nullptr;

	Pool()
	{
		slab = new char[kPoolNodeSize * 512];
		for (size_t i = 0; i < 512; ++i)
		{
			freeList.push_back(slab + i * kPoolNodeSize);
		}
	}

	~Pool() { delete[] slab; }

	char* allocate()
	{
		if (freeList.empty())
		{
			return new char[kPoolNodeSize];
		}
		char* p = freeList.back();
		freeList.pop_back();
		return p;
	}

	void deallocate(char* p)
	{
		if (p >= slab && p < slab + kPoolNodeSize * 512)
		{
			freeList.push_back(p);
		}
		else
		{
			delete[] p;
		}
	}
};

static uint64_t bench_baseline()
{
	Pool pool;
	char enetBuf[kEnetBufSize];

	auto t0 = std::chrono::steady_clock::now();
	for (size_t i = 0; i < kPacketsPerTrial; ++i)
	{
		char* uvBuf = pool.allocate();
		// simulate libuv filling buffer
		memset(uvBuf, static_cast<int>(i & 0xff), kPacketSize);

		char* heap = new char[kPacketSize];
		memcpy(heap, uvBuf, kPacketSize);
		pool.deallocate(uvBuf);

		size_t n = std::min(kPacketSize, kEnetBufSize);
		memcpy(enetBuf, heap, n);
		delete[] heap;
	}
	auto t1 = std::chrono::steady_clock::now();
	return std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count();
}

static uint64_t bench_optimized()
{
	Pool pool;
	char enetBuf[kEnetBufSize];

	auto t0 = std::chrono::steady_clock::now();
	for (size_t i = 0; i < kPacketsPerTrial; ++i)
	{
		char* uvBuf = pool.allocate();
		memset(uvBuf, static_cast<int>(i & 0xff), kPacketSize);

		size_t n = std::min(kPacketSize, kEnetBufSize);
		memcpy(enetBuf, uvBuf, n);
		pool.deallocate(uvBuf);
	}
	auto t1 = std::chrono::steady_clock::now();
	return std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count();
}

int main(int argc, char** argv)
{
	const char* mode = (argc > 1) ? argv[1] : "both";
	const int trial = (argc > 2) ? std::atoi(argv[2]) : 0;

	// warmup
	bench_baseline();
	bench_optimized();

	if (mode == std::string("baseline"))
	{
		std::cout << "trial=" << trial << " mode=baseline ns=" << bench_baseline() << " packets=" << kPacketsPerTrial << std::endl;
	}
	else if (mode == std::string("optimized"))
	{
		std::cout << "trial=" << trial << " mode=optimized ns=" << bench_optimized() << " packets=" << kPacketsPerTrial << std::endl;
	}
	else
	{
		auto b = bench_baseline();
		auto o = bench_optimized();
		std::cout << "baseline_ns=" << b << " optimized_ns=" << o
		          << " delta_pct=" << (100.0 * (static_cast<double>(b) - o) / static_cast<double>(b)) << std::endl;
	}
	return 0;
}
