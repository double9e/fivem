#include <StdInc.h>

#include <catch_amalgamated.hpp>

#include <EnetUvDatagram.h>

#include <mutex>

TEST_CASE("EnetUv retain policy respects backlog cap")
{
	SECTION("retain when queue shallow")
	{
		REQUIRE(EnetUvShouldRetainPoolBuffer(65536, 1200, 0));
		REQUIRE(EnetUvShouldRetainPoolBuffer(1400, 512, 63));
	}

	SECTION("heap copy when queue at cap")
	{
		REQUIRE_FALSE(EnetUvShouldRetainPoolBuffer(65536, 1200, kEnetUvMaxPoolRetainedQueuedDatagrams));
	}

	SECTION("heap copy for oversize uv buffer length")
	{
		REQUIRE_FALSE(EnetUvShouldRetainPoolBuffer(kEnetUvPacketPoolNodeSize + 1, 1200, 0));
	}
}

TEST_CASE("EnetUv datagram release returns pool nodes once")
{
	TEnetUvPacketPool pool(new uint8_t[TEnetUvPacketPool::kBufferSize]);
	std::mutex poolLock;

	char* node = (char*)pool.allocate(TEnetUvPacketPool::kNodeSize);
	memset(node, 0xab, 64);

	EnetUvDatagram dgram;
	dgram.data = node;
	dgram.dataFromPool = true;
	dgram.read = 64;

	dgram.ReleaseData(&pool, &poolLock);
	REQUIRE(dgram.data == nullptr);
	REQUIRE_FALSE(dgram.dataFromPool);

	void* again = pool.allocate(TEnetUvPacketPool::kNodeSize);
	REQUIRE(again == node);
	pool.deallocate(again, TEnetUvPacketPool::kNodeSize);
}

TEST_CASE("EnetUv fill uses heap path under backlog")
{
	uint8_t payload[1400];
	for (size_t i = 0; i < sizeof(payload); ++i)
	{
		payload[i] = static_cast<uint8_t>(i & 0xff);
	}

	EnetUvDatagram dgram;
	bool transferred = true;
	const size_t depth = kEnetUvMaxPoolRetainedQueuedDatagrams;

	EnetUvFillDatagramFromRecv(dgram, sizeof(payload), (const char*)payload, sizeof(payload), depth, transferred);

	REQUIRE_FALSE(transferred);
	REQUIRE_FALSE(dgram.dataFromPool);
	REQUIRE(dgram.data != nullptr);
	REQUIRE(memcmp(dgram.data, payload, sizeof(payload)) == 0);
	dgram.ReleaseData(nullptr, nullptr);
}
