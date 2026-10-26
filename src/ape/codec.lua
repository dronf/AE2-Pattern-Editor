-- Deterministic, binary-safe data format. Does not execute Lua when loading files.
local M = {}
local function encode(v, seen)
  local t = type(v)
  if t == 'nil' then return 'N' end
  if t == 'boolean' then return v and 'T' or 'F' end
  if t == 'number' then
    assert(v == v and math.abs(v) < math.huge, 'Non-finite number')
    return 'D' .. string.format('%.17g', v) .. ';'
  end
  if t == 'string' then return 'S' .. #v .. ':' .. v end
  assert(t == 'table' and not seen[v], 'Unsupported or cyclic data')
  seen[v] = true
  local keys = {}
  for k in pairs(v) do
    assert(type(k) == 'number' or type(k) == 'string', 'Unsupported key')
    keys[#keys+1] = k
  end
  table.sort(keys, function(a,b)
    if type(a) ~= type(b) then return type(a) < type(b) end
    return a < b
  end)
  local out = {'A', tostring(#keys), ':'}
  for _,k in ipairs(keys) do
    out[#out+1] = encode(k, seen)
    out[#out+1] = encode(v[k], seen)
  end
  seen[v] = nil
  return table.concat(out)
end
function M.encode(v) return encode(v, {}) end
function M.decode(s)
  assert(type(s) == 'string' and #s <= 16*1024*1024, 'Invalid data size')
  local p, nodes = 1, 0
  local function read(depth)
    nodes = nodes+1
    assert(depth < 64 and nodes < 1000000, 'Data too complex')
    local t = s:sub(p,p); p = p+1
    if t == 'N' then return nil end
    if t == 'T' then return true end
    if t == 'F' then return false end
    if t == 'D' then
      local e = assert(s:find(';',p,true), 'Truncated number')
      local n = assert(tonumber(s:sub(p,e-1)), 'Invalid number'); p = e+1
      assert(n == n and math.abs(n) < math.huge, 'Invalid number')
      return n
    end
    assert(t == 'S' or t == 'A', 'Invalid data tag')
    local e = assert(s:find(':',p,true), 'Truncated length')
    local token = s:sub(p,e-1)
    assert(token:match('^%d+$'), 'Invalid length')
    local n = tonumber(token); p = e+1
    assert(n <= #s, 'Invalid length')
    if t == 'S' then
      assert(p+n-1 <= #s, 'Truncated string')
      local v = s:sub(p,p+n-1); p = p+n; return v
    end
    local v = {}
    for _=1,n do
      local k = read(depth+1)
      assert(type(k)=='string' or type(k)=='number', 'Invalid key')
      assert(v[k] == nil, 'Duplicate key')
      v[k] = read(depth+1)
    end
    return v
  end
  local v = read(0)
  assert(p == #s+1, 'Trailing data')
  return v
end
function M.copy(v) return M.decode(M.encode(v)) end
function M.equal(a,b) return M.encode(a) == M.encode(b) end
function M.adler(s)
  local a,b = 1,0
  for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
  return string.format('%08x', b*65536+a)
end
return M
