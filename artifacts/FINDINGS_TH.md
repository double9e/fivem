# FXServer core investigation — สรุปผู้บริหาร (7 พ.ย. 2026)

## ขอบเขตงานรอบนี้
- โฟกัส **แกน C++ ของ FXServer** (รับ/ส่งเครือข่าย, threading, OneSync) **ไม่** ปรับ Lua resource
- แหล่งโค้ด: fork `double9e/fivem` ที่ commit **`5c3065c261fb3ba82032fee6803f247198fec221`** (ตรงกับ artifact Linux build **38435** ที่ lab เดิมใช้)
- Lab เดิม (`artifacts/prior-lua-http-lab/`) วัด **HTTP + SetHttpHandler ใน Lua** เท่านั้น — **ห้าม** อ้างเป็นหลักฐาน core optimization

## สถาปัตยกรรมเส้นทางเครือข่าย (สรุป)
| ชั้น | ไฟล์ | บทบาท |
|------|------|--------|
| UDP/libuv + คิวรับ | `code/components/citizen-server-impl/src/EnetUv.cpp` | รับ datagram, `recvQueue`, pool buffer ขนาด 64KiB, mutex ต่อ allocation |
| ENet service | `code/components/citizen-server-impl/src/GameServerNet.ENet.cpp` | `enet_host_service` → `ProcessPacket` |
| แยกประเภทแพ็กเก็ต | `code/components/citizen-server-impl/src/GameServer.cpp` | อ่าน `msgType`, handshake, เรียก `m_packetHandler` |
| กระจาย handler | `code/components/citizen-server-impl/include/decorators/WithPacketHandler.h` | fast-path ตาม `PacketType`; slow-path ย้าย thread (Main/Net/Sync) |
| OneSync / sync tick | `code/components/citizen-server-impl/src/GameServer.cpp`, `state/ServerGameState.cpp` | loop `svNetwork` ~30Hz tick + `svSync` ~120Hz; histogram `tickTime` |

### Permalinks (pin SHA)
- Receive queue + double copy (ก่อน patch):  
  https://github.com/double9e/fivem/blob/5c3065c261fb3ba82032fee6803f247198fec221/code/components/citizen-server-impl/src/EnetUv.cpp#L106-L252  
- `ProcessPacket` / OneSync connect:  
  https://github.com/double9e/fivem/blob/5c3065c261fb3ba82032fee6803f247198fec221/code/components/citizen-server-impl/src/GameServer.cpp#L643-L786  
- ENet receive → dispatch:  
  https://github.com/double9e/fivem/blob/5c3065c261fb3ba82032fee6803f247198fec221/code/components/citizen-server-impl/src/GameServerNet.ENet.cpp#L237-L272  
- Packet handler decorator + thread routing:  
  https://github.com/double9e/fivem/blob/5c3065c261fb3ba82032fee6803f247198fec221/code/components/citizen-server-impl/include/decorators/WithPacketHandler.h#L17-L61  
- Network / sync UV timers:  
  https://github.com/double9e/fivem/blob/5c3065c261fb3ba82032fee6803f247198fec221/code/components/citizen-server-impl/src/GameServer.cpp#L355-L478  

## การ build FXServer บน Linux (ที่รองรับจริง)
อ้างอิง CI ภายใน repo:
- `code/tools/ci/build_server_proot_alpine.sh` — **Alpine 3.16 + proot**, mirror APK ของ Cfx, `premake5 gmake2 --game=server --cc=clang`, `make config=release`, ผลที่ `bin/server/linux/release/FXServer`
- ต้องมี submodule เต็ม, mono 5.16, v8, lld, ชุดแพ็กเกจจาก `https://cfx-content.akamaized.net/mirrors/build/linux/packages/cfx`

## สถานะ build บน Cloud VM นี้ (Ubuntu 24.04)
| ขั้นตอน | ผล |
|---------|-----|
| `premake5 gmake2 --game=server` | สำเร็จ หลัง init `vendor/msgpack-c` |
| `make CitiTest config=release` | **ล้มเหลว** — submodule ที่ยังไม่ init ~150 รายการ; `clang++` ไม่เห็น `<type_traits>` (ไม่ใช่ toolchain ของ Alpine CI) |
| Build FXServer artifact เต็ม | **ยังไม่ทำได้** โดยไม่มี proot/Alpine + APK repo ของ Cfx + submodule recursive + mono/v8 |

รายละเอียดคำสั่งและ log: `artifacts/BUILD.md`, `artifacts/build_cititest_attempt.log`

## การเปลี่ยนแปลงโค้ด (candidate patch เดียว)
**ไฟล์:** `code/components/citizen-server-impl/src/EnetUv.cpp`  
**เหตุผล:** เส้นทางรับ UDP เดิม copy จาก pool buffer ของ libuv ไป `new char[]` แล้วค่อย copy อีกครั้งเมื่อ ENet อ่าน — เสีย allocation + bandwidth บนเซิร์ฟเวอร์ที่มีแพ็กเก็ตหนาแน่น  
**การแก้:** เก็บ ownership ของ pool buffer ใน `Datagram` จน ENet อ่านเสร็จ แล้วคืน pool (พฤติกรรมโปรโตคอล/การ validate เดิม ไม่เปลี่ยน)

## การวัด (จำกัดขอบเขตอย่างตรงไปตรงมา)
- **ไม่มี** license key บน VM นี้ → **ไม่** รัน FXServer artifact จริง / ไม่วัด UDP gameplay / OneSync end-to-end
- ใช้ **ไมโครเบนช์แยก** จำลองเส้นทาง recv queue เท่านั้น (`artifacts/microbench/`) — **ไม่ใช่** throughput ของ binary FXServer

### ผลไมโครเบนช์ (ลำดับสลับ: b1, o1, o2, b2, b3, o3)
แต่ละ trial = 2,000,000 datagram ขนาด 1200 byte, `g++ -O2 -march=native`

| Trial | Mode | เวลารวม (ns) | Δ เทียบ median baseline |
|-------|------|--------------|-------------------------|
| 1 | baseline | 84,733,214 | |
| 1 | optimized | 32,855,918 | |
| 2 | baseline | 93,180,463 | |
| 2 | optimized | 41,151,155 | outlier สูงกว่า opt อื่น ~25% |
| 3 | baseline | 93,150,282 | |
| 3 | optimized | 33,538,415 | |

- Median baseline ≈ **93.15 ms** / 2M packets  
- Median optimized ≈ **33.54 ms** (ไม่รวม outlier trial 2)  
- ตีความ: ในสภาพจำลอง CPU-bound memcpy/allocation, ลดงานต่อแพ็กเก็ตได้ชัด — **ยังไม่พิสูจน์** packet loss หรือ tail latency บนเซิร์ฟเวอร์จริง

## สิ่งที่วัดไม่ได้ที่นี่
- ผู้เล่นจริง / โปรโตคอล FiveM client / OneSync replication ภายใต้โหลดกว้าง
- packet loss, RTT, queue depth ของ ENet ภายใต้ FXServer binary
- การรองรับ 1000–3000 slot (ค่า synthetic ≠ ความจุผู้เล่น)

## สิ่งที่ต้องการจากผู้ประสานงาน (parent)
1. เครื่อง build ตาม `build_server_proot_alpine.sh` หรือ CI runner ของ Cfx (Alpine + mirror APK)  
2. `FX_LICENSE` หรือ host ทดสอบ local ที่มี key (ไม่เก็บใน repo)  
3. Harness UDP/protocol-aware (ไม่ใช่ HTTP) สำหรับ 3×3 trials บน **baseline vs patched artifact** ชุดเดียวกัน

## สิ่งที่ยังไม่สันนิษฐานว่าเป็นคอขวด
 mutex บน pool ใน thread `svNetwork` เดียว, การ marshaling handler ไป `svSync`, งาน `ServerGameState.cpp` ขนาดใหญ่ — ต้องมี profiler บน artifact build ก่อนสรุป
