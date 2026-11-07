# EnetUv pool-buffer retention audit (experimental)

## Behavior matrix

| Case | Handling |
|------|----------|
| `nread < 0` | Return UV buffer to pool via `EnetUvReleaseUvBuffer` (fix vs prior silent leak) |
| `nread == 0` | No enqueue; UV buffer returned to pool |
| Non-IPv6 source | No enqueue; UV buffer returned |
| Normal packet | Pool retain if `bufLen <= 64KiB` and `recvQueue.size() < 64`; else heap copy of `nread` bytes |
| Oversize `buf->len` | Heap `new[]` copy; UV buffer freed separately |
| After ENet read | `ReleaseData(pool, lock)` always in `enet_socket_receive` |
| Socket destroy | `DrainRecvQueue()` before map erase |
| `UdpSocket` destructor | Drains queue |

## Memory / backlog tradeoff

- **Old:** queued datagram ≈ `nread` bytes (heap).
- **New (retain path):** each queued datagram holds one **64 KiB** pool node until consumed.
- **Mitigation:** retain only while `recvQueue.size() < kEnetUvMaxPoolRetainedQueuedDatagrams` (64); deeper backlog falls back to heap copy (same memory shape as baseline).

## Pool exhaustion

- Pool size: 512 × 64 KiB nodes.
- Worst case retained in queues: 64 nodes × 64 KiB ≈ 4 MiB pinned (cap), not `queue_depth × 64KiB` unbounded.

## Threading

- Receive callbacks run on `svNetwork` UV loop (single-threaded per loop); pool mutex retained for allocators shared with send path.

## Tests

- `code/tests/server/TestEnetUvDatagram.cpp` (Catch2): policy, pool recycle, backlog heap fallback.
- Built with `CitiTest` target when Alpine server build succeeds.

## Status

**Experimental / not production-ready** until FXServer artifact build + protocol-level validation complete.
