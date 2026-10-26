local C = require('ape.codec')
local M = {MAX_AMOUNT = 2147483647, MAX_ENTRIES = 512}
local function array(t)
  assert(type(t)=='table', 'Pattern contents unavailable')
  local keys, out = {}, {}
  for k,v in pairs(t) do if type(k)=='number' and type(v)=='table' then keys[#keys+1]=k end end
  table.sort(keys)
  for _,k in ipairs(keys) do out[#out+1]=t[k] end
  return out,keys
end
function M.stack(s)
  assert(type(s)=='table' and type(s.name)=='string', 'Unsupported item/fluid identity')
  local fluid = s.amount ~= nil and s.damage == nil
  local n = {kind=fluid and 'fluid' or 'item', name=s.name,
    label=s.label or s.name, size=s.size or s.amount or 1,
    damage=fluid and nil or (s.damage or 0), hasTag=s.hasTag == true or s.tag ~= nil,
    tag=s.tag}
  assert(n.tag == nil or type(n.tag)=='string', 'Unsupported NBT representation')
  if fluid then n.damage=nil end
  return n
end
function M.pattern(p)
  assert(type(p)=='table', 'No encoded pattern')
  local n = {crafting=p.isCraftable == true, inputs={}, outputs={},layout={inputs={},outputs={}}}
  for _,side in ipairs({'inputs','outputs'}) do
    local entries,positions=array(p[side])
    local shift=positions[1]==0 and 1 or 0
    for i,s in ipairs(entries) do
      n[side][i]=M.stack(s); n.layout[side][i]=positions[i]+shift
    end
  end
  return n
end
function M.identity(s)
  return C.encode({s.kind,s.name,s.damage,s.hasTag,s.tag,
    -- Without readable NBT, labels still distinguish the search results. Such entries cannot be written.
    s.hasTag and not s.tag and s.label or nil})
end
function M.signature(p)
  local out = {crafting=p.crafting, inputs={}, outputs={}}
  for _,side in ipairs({'inputs','outputs'}) do
    for i,s in ipairs(p[side]) do out[side][i]={M.identity(s),s.size} end
  end
  return C.encode(out)
end
function M.fingerprint(raw)
  return C.encode({name=raw.name,damage=raw.damage,tag=raw.tag,
    pattern=M.signature(M.pattern(raw))})
end
function M.validate(p)
  assert(not p.crafting, 'Crafting-grid patterns are read-only in v1; use a Pattern Terminal')
  assert(#p.inputs > 0, 'Keep at least one input')
  assert(#p.outputs > 0, 'Keep at least one output')
  for _,side in ipairs({'inputs','outputs'}) do
    assert(#p[side]<=M.MAX_ENTRIES, 'At most 512 entries per side')
    for _,s in ipairs(p[side]) do
      assert(s.kind=='item' or s.kind=='fluid', 'Unsupported stack type')
      assert(type(s.name)=='string' and #s.name>0, 'Missing registry identity')
      assert(type(s.size)=='number' and s.size>=0 and s.size==math.floor(s.size)
        and s.size<=M.MAX_AMOUNT, 'Amounts must be whole numbers from 0 to 2147483647')
      assert(side~='outputs' or s.size>0, 'Outputs must have a positive amount')
      assert(not (s.kind=='fluid' and s.hasTag), 'Tagged fluids are read-only: OC cannot preserve fluid NBT')
      assert(not s.hasTag or type(s.tag)=='string',
        'NBT is hidden: enable allowItemStackNBTTags in OC config before editing tagged items')
    end
  end
  return true
end
function M.scale(p, factor)
  local draft=C.copy(p)
  assert(factor==2 or factor==0.5, 'Use x2 or /2')
  for _,side in ipairs({'inputs','outputs'}) do
    for _,s in ipairs(draft[side]) do
      if s.size>0 then
        local amount=s.size*factor
        assert(amount>=1 and amount==math.floor(amount) and amount<=M.MAX_AMOUNT,
          'Cannot scale: every positive amount must remain a whole number in range')
        s.size=amount
      end
    end
  end
  M.validate(draft)
  return draft
end
function M.remove(p,side,index)
  assert(side=='inputs' or side=='outputs', 'Invalid side')
  assert(p[side][index], 'Select an ingredient')
  assert(#p[side]>1, 'Keep at least one '..side:sub(1,-2))
  table.remove(p[side],index)
end
function M.detail(s)
  local d={name=s.name,size=s.size}
  if s.kind=='item' then d.damage=s.damage or 0; d.tag=s.tag else d.amount=s.size; d.tag=s.tag end
  return d,s.kind
end
function M.title(p)
  local out={}
  for _,s in ipairs(p.outputs) do out[#out+1]=s.label end
  return table.concat(out,' + ')
end
function M.match(p,query,mode)
  local q=(query or ''):lower()
  if q=='' then return true end
  for _,side in ipairs({'inputs','outputs'}) do
    if mode=='both' or mode==side then
      for _,s in ipairs(p[side]) do
        if s.label:lower():find(q,1,true) or s.name:lower():find(q,1,true) then return true end
      end
    end
  end
  return false
end
function M.diff(old,new)
  local out={}
  for _,side in ipairs({'inputs','outputs'}) do
    out[#out+1]=side:upper()
    for i=1,math.max(#old[side],#new[side]) do
      local a,b=old[side][i],new[side][i]
      local function fmt(s) return s and (s.size..' '..s.label..(s.kind=='fluid' and ' mB' or '')) or '(none)' end
      if not a or not b or M.identity(a)~=M.identity(b) or a.size~=b.size then
        out[#out+1]=i..': '..fmt(a)..' -> '..fmt(b)
      end
    end
  end
  return out
end
return M
