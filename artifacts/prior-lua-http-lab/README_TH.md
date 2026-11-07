# FXServer performance lab, 7 พ.ย. 2026 (เวลาไทย ICT)

## สถานะ
- Artifact Linux build 38435 (เป็นทั้ง recommended และ latest) URL: https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/38435-5c3065c261fb3ba82032fee6803f247198fec221/fx.tar.xz
  sha256 1b58507f68086ca3578c187f31e7b4a2259b7192d76b0c80cfc1af682fdf2be9
- ครั้งแรกที่ไม่มี key (06:04 ICT) server หยุดที่ข้อความว่าไม่มี license key ดู logs/startup_nokey.sanitized.log
- เมื่อมี key: logs/server_run1/2/3.log มีบรรทัด "Server license key authentication succeeded" ครั้งแรกประมาณ 06:13 ICT ผลทั้งหมดวัดจาก run3 (เปิดประมาณ 06:14 ICT)
- จบงานแล้วหยุด process ของ lab ทั้งหมด

## การเปิด server (bench/start_server.sh)
- key มาจาก environment variable FX_LICENSE ใช้ bash builtin printf เขียนลงไฟล์ /dev/shm/d9lab_key_<pid>.cfg (อยู่ใน RAM, umask 077) แล้วส่งให้ +exec
- ลบไฟล์นั้นทันทีที่ log ขึ้น "Authenticating" (ไม่เกิน 15 วินาที) key จึงไม่อยู่บน argv และไม่ถูกเขียนลงดิสก์
- output ของ server ผ่าน bench/redact.py (ตัด key และ ANSI) ก่อนเขียนลงไฟล์ log
- stdin ต่อจาก `sleep infinity` เพราะถ้า stdin เจอ EOF FXServer จะตีความเป็น Ctrl-C แล้วปิดตัว
- ลองแบบ FIFO และ /dev/fd แล้ว FXServer อ่านไม่ได้
- endpoint ผูกไว้ที่ 127.0.0.1:30199 เท่านั้น

## การทดสอบ HTTP (resource data/resources/d9_bench, ใช้ SetHttpHandler)
- ข้อมูลผู้เล่น 3000 record เป็นข้อมูลจำลอง ไม่มีผู้เล่นจริง มี thread เปลี่ยนเงินและตำแหน่งของ 30 record ทุก 100 ms
- แต่ละวิธีมี endpoint base และ opt:
  - cache: json.encode ทุก request เทียบกับ cache string ที่ invalidate ด้วย dirty flag
  - near: วนเช็คครบ O(N) พร้อม sqrt เทียบกับ spatial grid และระยะกำลังสอง
  - list: ต่อ string ด้วย .. ในลูปเทียบกับ table.concat
- ความเหมือนของผลลัพธ์ (bench/equiv.py): เช็ค 200 id ต่อวิธี ทั้งก่อนและหลังการทดสอบ base กับ opt ตรงกันทุก byte (mismatch 0)
  - ขอบเขตการยืนยันมีแค่ข้อมูลจำลองชุดนี้และ id ที่สุ่มเช็ค ไม่ได้พิสูจน์ว่าเหมือนกันทุกกรณี
- Load (bench/loadgen.py) ยิงเฉพาะ localhost แบบ closed-loop ใช้ HTTP/1.1 keep-alive
  - deadline 3 วินาทีต่อ request และนับสถานะ non-200, timeout, conn_error แยกกัน
  - สังเกตว่า FXServer ปิด socket หลังใช้ซ้ำครบ 6 request จึงส่งซ้ำบน socket ใหม่ 1 ครั้ง นับไว้ใน keepalive_close_retries ไม่ได้นับว่าเป็น error
  - CPU และ RSS ของ FXServer มาจาก /proc
- Matrix (bench/http_matrix.sh): 3 วิธี × concurrency 1/8/32 × 3 รอบเต็ม
  - สลับลำดับ base/opt ทุกรอบ, warmup 2 วินาที, ช่วงวัดตั้งไว้ 8 วินาที (ค่า dur_s ในผลดิบคือเวลาที่วัดได้จริงจาก monotonic clock)
  - รวม 54 run ที่ใช้ได้ (มีคู่ rerun 1 คู่ ดูด้านล่าง) ไม่ได้ทดสอบที่ concurrency 64

## ผล (results/http_summary.txt และ http_runs_final.csv)
เปอร์เซ็นต์ = (median opt − median base) / median base ของ ok req/s ทั้ง 3 รอบ
- cache: −1.5% / ±0% / +5.6% (c=1/8/32) อยู่ในช่วงแกว่ง ถือว่าไม่ได้ผล
- near: +130.7% / +217.2% / +235.7% และ p99 ที่ c=32 ลดจาก 159–183 ms เหลือ 27–29 ms
- list: +40.4% / +66.5% / +54.6% และ p99 ที่ c=32 ลดจาก 209–220 ms เหลือ 122–135 ms
- ผลแกว่งระหว่างรอบมาก (เช่น cache c=32 อยู่ที่ 6.7k–8.1k, list opt c=8 รอบ 2 = 1648) ให้ดูค่าทุกรอบประกอบ
- request ไม่สำเร็จ: 7 ครั้งใน list opt c=8 รอบ 2 นอกนั้นเป็น 0 ไม่มีการทำ rate-limit หรือปฏิเสธ request
- CPU ของ FXServer ที่ load สูงอยู่ราว 190% ของ 1 core เป็นค่าที่สังเกตได้เท่านั้น ยังไม่ได้พิสูจน์ว่า HTTP layer เป็นคอขวด
- RSS ประมาณ 130–134 MB

## run ที่ถูกตัดหรือรันใหม่
- attempt1 (results/http_runs_aborted_attempt1.jsonl): ใช้ Connection: close ทำให้ run หนึ่งยืดไปถึง 291 วินาที
- attempt2 (results/http_runs_aborted_attempt2_conn_close.jsonl): พบ TIME_WAIT มากกว่า 12k คาดว่า ephemeral port ฝั่ง client หมด จึงเลิกใช้ผลทั้งสองชุด
- ใน run หลัก คู่ list c=1 รอบ 2 ใช้เวลา 199.5 วินาที
  - ช่วงเดียวกันใน log มี hitch warning ของ sync, network และ server thread พร้อมกัน (~190–290 วินาที)
  - สงสัยว่าเป็นการรบกวนจากสภาพแวดล้อม แต่ยังไม่ได้พิสูจน์ว่า host ค้างทั้งเครื่อง และตัดสาเหตุจาก workload ออกไม่ได้
  - ตัดคู่นั้นทิ้งและรันใหม่ทั้งคู่ไว้ใน results/http_runs_rerun.jsonl (hitch_lines = null เพราะไม่ได้วัด)
- ค่า hitch_lines คือจำนวนบรรทัด "hitch" ใน log ที่เพิ่มขึ้นระหว่างแต่ละ run ใช้วัด tick ไม่ได้

## สิ่งที่ไม่ได้วัด หรือข้อจำกัด
- ไม่ได้ใช้ profiler และไม่ได้วัด tick time (stdin ถูกใช้กันไม่ให้ server ปิดตัว)
- ไม่ได้วัด UDP, game event, OneSync หรือ packet loss และ HTTP error ไม่ใช่ packet loss
- บอกไม่ได้ว่ารองรับผู้เล่น 1000–3000 คน
- ตัวยิง load รันบนเครื่องเดียวกับ server จึงแย่ง CPU กัน
- ผลที่ได้เป็นของ custom Lua script ไม่ใช่การปรับ core ของ FXServer

## ผลเก่าแบบ standalone (results/old_standalone_lua/, bench/bench.lua)
- รันด้วย PUC Lua 5.4.7 ที่ build จาก source (lua.sha256) ภาษาเป็น Lua 5.4 เหมือนกัน แต่ไม่ใช่ CfxLua และไม่ได้รันใน FXServer
- ค่า bytes/msgs ในชุดนั้นเป็นขนาด string ใน benchmark ไม่ใช่ byte ที่ส่งผ่านเครือข่ายจริง ผลแกว่งระหว่างรอบ (เช่น grid 1000: 71/71/132 ms)

## เหตุการณ์ด้านความปลอดภัย
- ระหว่างเช็คครั้งแรกเคยรัน grep โดยใส่ key เป็น argument key จึงโผล่ใน process list ของ box ชั่วครู่ (ไม่มีใน log, ไฟล์ หรือแชท)
- แนะนำให้ revoke หรือออก key ใหม่ที่ portal.cfx.re

## วิธีรันซ้ำ
bench/start_server.sh run3 → python3 bench/equiv.py → bench/http_matrix.sh run3 → python3 bench/analyze.py
แหล่งอ้างอิงอยู่ใน SOURCES.md
