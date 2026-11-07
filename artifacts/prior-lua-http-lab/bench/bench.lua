-- d9 Lua hot-path bench (standalone Lua 5.4 = same VM family as FXServer Lua 5.4; NOT FXServer itself)
-- usage: lua bench.lua <case> <variant> <players> <ticks> <seed>
local case, variant, N, TICKS, SEED = arg[1], arg[2], tonumber(arg[3]), tonumber(arg[4]), tonumber(arg[5])
math.randomseed(SEED)
local clock = os.clock
-- players
local P = {}
for i=1,N do P[i]={id=i,x=math.random()*8000-4000,y=math.random()*8000-4000,z=30,hp=200,job="police",money=math.random(1,1e6),dirty=false} end

-- tiny JSON-like encoder (stand-in for json.encode/msgpack cost; same for both variants)
local concat, fmt = table.concat, string.format
local function enc(t)
  local b = {}
  for k,v in pairs(t) do b[#b+1] = fmt('"%s":%s', k, type(v)=="string" and ('"'..v..'"') or tostring(v)) end
  return "{"..concat(b,",").."}"
end
local sent_msgs, sent_bytes = 0, 0
LAST="" local function send(target, payload) LAST=payload; sent_msgs = sent_msgs + 1; sent_bytes = sent_bytes + #payload end

local function move() for i=1,N do local p=P[i]; if i%10==0 then p.x=p.x+1; p.dirty=true end end end

local tick
if case=="batch" then -- C1: per-player status event vs one batched state per tick
  if variant=="base" then
    tick=function() move(); for i=1,N do local p=P[i]; if p.dirty then send(-1, enc({id=p.id,x=p.x,y=p.y,z=p.z,hp=p.hp})); p.dirty=false end end end
  else
    tick=function() move(); local out={} ; for i=1,N do local p=P[i]; if p.dirty then out[#out+1]=fmt("[%d,%.1f,%.1f,%.1f,%d]",p.id,p.x,p.y,p.z,p.hp); p.dirty=false end end
      if #out>0 then send(-1,"["..concat(out,",").."]") end end
  end
elseif case=="cache" then -- C2: rebuild player-data table per request vs cache invalidated on change
  local REQ = 2*N -- requests per tick (e.g. callbacks asking for player data)
  local cache = {}
  if variant=="base" then
    tick=function() move(); for r=1,REQ do local p=P[(r%N)+1]; send(p.id, enc({id=p.id,job=p.job,money=p.money,hp=p.hp})) end end
  else
    tick=function() move(); for r=1,REQ do local p=P[(r%N)+1]; local c=cache[p.id]
      if c==nil or p.dirty then c=enc({id=p.id,job=p.job,money=p.money,hp=p.hp}); cache[p.id]=c end; send(p.id,c) end
      for i=1,N do P[i].dirty=false end end
  end
elseif case=="grid" then -- C3: proximity (who is within 100m) O(N^2) sqrt vs spatial grid + squared distance
  local R=100
  if variant=="base" then
    tick=function() move(); local pairs_=0
      for i=1,N do local a=P[i]; for j=1,N do if i~=j then local b=P[j]; local d=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2); if d<R then pairs_=pairs_+1 end end end end
      send(-1, tostring(pairs_)) end
  else
    local R2, CS = R*R, R
    tick=function() move(); local g={} ; local floor=math.floor
      for i=1,N do local p=P[i]; local k=floor(p.x/CS)*100000+floor(p.y/CS); local c=g[k]; if not c then c={} g[k]=c end; c[#c+1]=p end
      local pairs_=0
      for i=1,N do local a=P[i]; local cx,cy=floor(a.x/CS),floor(a.y/CS)
        for dx=-1,1 do for dy=-1,1 do local c=g[(cx+dx)*100000+(cy+dy)]; if c then for j=1,#c do local b=c[j]; if b~=a then local ex,ey,ez=a.x-b.x,a.y-b.y,a.z-b.z; if ex*ex+ey*ey+ez*ez<R2 then pairs_=pairs_+1 end end end end end end end
      send(-1, tostring(pairs_)) end
  end
end

for i=1,math.max(3,TICKS//10) do tick() end -- warmup
sent_msgs, sent_bytes = 0, 0
collectgarbage("collect"); local mem0=collectgarbage("count")
local times={}
local t0=clock()
for i=1,TICKS do local a=clock(); tick(); times[i]=(clock()-a)*1000 end
local total=(clock()-t0)*1000
table.sort(times)
local function pct(q) return times[math.max(1,math.ceil(q*#times))] end
print(fmt('{"case":"%s","variant":"%s","players":%d,"ticks":%d,"seed":%d,"total_ms":%.3f,"tick_p50_ms":%.4f,"tick_p95_ms":%.4f,"tick_p99_ms":%.4f,"tick_max_ms":%.4f,"msgs_per_tick":%.2f,"bytes_per_tick":%.1f,"heap_kb_after":%.1f,"last_payload_len":%d,"last_check":"%s"}',
 case,variant,N,TICKS,SEED,total,pct(.5),pct(.95),pct(.99),times[#times],sent_msgs/TICKS,sent_bytes/TICKS,collectgarbage("count"),#LAST,case=="grid" and LAST or "-"))
