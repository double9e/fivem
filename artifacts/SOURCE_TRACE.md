# Network / OneSync source trace (FXServer)

## Thread model (libuv path, default on Linux)
```
svNetwork (UvLoopManager)
  uv_timer 1000/30 ms  -> OnNetworkTick(); GameServerNet::Process(); send list
  UDP recv callback    -> EnetUv recvQueue -> enet_socket_receive

svSync
  uv_timer 1000/120 ms -> OnSyncTick() -> ServerGameState replication work

Main (svMain)
  resource tick, scripting callbacks via gscomms_execute_callback_on_main_thread
```

Legacy fallback when `!SupportsUvUdp()`: dedicated `std::thread` + `enet_host_service` in `InitializeNetThread()`.

## Receive → dispatch chain
1. `uv_udp_recv_start` (`EnetUv.cpp`) pushes `Datagram` to per-socket `recvQueue`
2. `enet_socket_receive` copies payload into ENet buffer
3. `GameServerNetImplENet::ProcessHost` → `GameServer::ProcessPacket`
4. `WithPacketHandler` lambda dispatches by `packetId` to OneSync handlers under `packethandlers/` and `state/`

## OneSync entry points (non-exhaustive)
- Connect path slot IDs: `GameServer.cpp` `IsOneSync()` branches (~L699-L757)
- Handlers: `GameStateAckPacketHandler`, `GameStateNAckPacketHandler`, `ArrayUpdatePacketHandler`, `StateBagPacketHandler`, `NetGameEventPacketHandler`, `RequestObjectIdsPacketHandler`
- Sync tick registration: `ServerGameState.cpp` connects `OnSyncTick`

## Locking / queues worth profiling (not proven bottlenecks)
- `packetAllocatorLock`, `sendPacketAllocatorLock` on every UDP alloc/free (`EnetUv.cpp`)
- `ConcurrentQueue` / rate limiters in packet handlers (drop client on overflow — correctness-sensitive)
- `m_netSendList` processed on net timer (`GameServer.cpp`)

## Metrics hooks already in tree
- Prometheus histogram `tickTime` for `svNetwork` / `svSync` (`GameServer.cpp`)
- ENet per-peer stats exposed via scripting API (`GameServerNet.ENet.cpp` `GetENetStatistics`)
- Structured trace on thread hitch >150ms (network) / >100ms (sync)
