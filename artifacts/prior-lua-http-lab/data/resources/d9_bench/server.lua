-- d9_bench: each case has base & opt endpoints that MUST return byte-identical bodies for same state.
-- /d9_bench/<case>_<variant>?id=N   cases: cache, near, list ; /d9_bench/stats
local N = 3000
local P = {}
math.randomseed(42)
for i=1,N do P[i]={id=i,job=(i%5==0) and "police" or "civ",money=i*7,hp=200,x=math.random()*8000-4000,y=math.random()*8000-4000,z=30.0} end
local version, cache = 0, {}
local served, reqs = 0, {}
-- state mutation (same for all variants): every 100ms change 30 players' money/position
CreateThread(function()
  while true do
    Wait(100)
    for k=1,30 do local p=P[math.random(N)]; p.money=p.money+1; p.x=p.x+0.5; p.dirty=true end
    version = version + 1
  end
end)
local function rec(p) return {id=p.id,job=p.job,money=p.money,hp=p.hp} end
-- grid (rebuilt lazily when version changes)
local CS, R, R2 = 100.0, 100.0, 10000.0
local grid, gridVer = nil, -1
local floor = math.floor
local function buildGrid()
  grid = {}
  for i=1,N do local p=P[i]; local k=floor(p.x/CS)*100000+floor(p.y/CS); local c=grid[k]; if not c then c={}; grid[k]=c end; c[#c+1]=p end
  gridVer = version
end
local H = {}
H.cache_base = function(id) return json.encode(rec(P[id])) end
H.cache_opt = function(id)
  local p, c = P[id], cache[id]
  if c == nil or p.dirty then c = json.encode(rec(p)); cache[id] = c; p.dirty = false end
  return c
end
H.near_base = function(id)
  local a, n = P[id], 0
  for j=1,N do local b=P[j]; if b~=a and math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) < R then n=n+1 end end
  return '{"id":'..id..',"near":'..n..'}'
end
H.near_opt = function(id)
  if gridVer ~= version then buildGrid() end
  local a, n = P[id], 0
  local cx, cy = floor(a.x/CS), floor(a.y/CS)
  for dx=-1,1 do for dy=-1,1 do local c=grid[(cx+dx)*100000+(cy+dy)]
    if c then for j=1,#c do local b=c[j]; if b~=a then local ex,ey,ez=a.x-b.x,a.y-b.y,a.z-b.z; if ex*ex+ey*ey+ez*ez<R2 then n=n+1 end end end end end end
  return '{"id":'..id..',"near":'..n..'}'
end
-- list: 200 players as CSV-ish lines; base uses repeated .. (quadratic copies), opt uses table.concat
H.list_base = function(id)
  local s = ""
  for k=0,199 do local p=P[(id+k-1)%N+1]; s = s .. p.id .. "," .. p.job .. "," .. p.money .. "\n" end
  return s
end
H.list_opt = function(id)
  local t = {}
  for k=0,199 do local p=P[(id+k-1)%N+1]; t[k+1] = p.id .. "," .. p.job .. "," .. p.money end
  return table.concat(t, "\n") .. "\n"
end
SetHttpHandler(function(req,res)
  local name, id = req.path:match("^/([%w_]+)%?id=(%d+)")
  if req.path:find("^/stats") then res.writeHead(200,{["Content-Type"]="application/json"}); res.send(json.encode({served=served,version=version,per=reqs})); return end
  local h = name and H[name]
  if not h then res.writeHead(404); res.send("no"); return end
  id = (tonumber(id)-1)%N+1
  served = served + 1; reqs[name]=(reqs[name] or 0)+1
  res.writeHead(200,{["Content-Type"]="text/plain"}); res.send(h(id))
end)
print("d9_bench v2 loaded")
