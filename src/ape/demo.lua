-- A disconnected simulation used by --demo and the regression suite.
local C=require('ape.codec')
local M={}
function M.new()
  local station={location={x=0,y=64,z=0,dimId=0},side=6,slot=0}
  local source={location={x=10,y=64,z=0,dimId=0},side=2,slot=0}
  local function item(name,label,size,tag)
    return {name=name,label=label,size=size,damage=0,hasTag=tag~=nil,tag=tag}
  end
  local function pattern(inputs,outputs,crafting)
    return {name='appliedenergistics2:encoded_pattern',damage=0,label='Encoded Pattern',
      tag='demo-pattern-metadata',isCraftable=crafting or false,inputs=inputs,outputs=outputs}
  end
  local inventories={
    {name='Pattern Editor',location=station.location,side=6,patterns={}},
    {name='Assembly Line',location=source.location,side=2,patterns={
      [0]=pattern({item('gregtech:gt.metaitem.01','Quantium Ingot',8),
        item('gregtech:gt.metaitem.02','Superconductor Wire',4,'renamed-item-nbt')},
        {item('gregtech:gt.metaitem.03','Quantum Mainframe',2)}),
      [8]=pattern({{name='water',label='Water',size=1000,amount=1000},
        item('minecraft:iron_ingot','Iron Ingot',2)},
        {item('minecraft:gold_ingot','Demo Gold Ingot',2)})}},
    {name='Bender',location={x=20,y=64,z=0,dimId=0},side=6,patterns={
      [0]=pattern({item('gregtech:gt.metaitem.01','Quantium Ingot',2)},
        {item('gregtech:gt.metaitem.04','Quantium Plate',2)}),
      [1]=pattern({item('minecraft:iron_ingot','Iron Ingot',9)},
        {item('minecraft:iron_block','Block of Iron',1)},true)}}}
  local function find(ep)
    for _,r in ipairs(inventories) do
      if C.equal(r.location,ep.location) and r.side==ep.side then return r end
    end
  end
  local function iterator(rows)
    local i=0
    local sides={[0]='DOWN',[1]='UP',[2]='NORTH',[3]='SOUTH',[4]='WEST',[5]='EAST',[6]='UNKNOWN'}
    return function()
      i=i+1
      if not rows[i] then return nil end
      local out=C.copy(rows[i])
      out.side=sides[out.side] or out.side
      return out
    end
  end
  local terminal={}
  function terminal.getInterfaces() return iterator(inventories) end
  function terminal.getInterfacesByLocation(loc,side)
    local r=find({location=loc,side=side}); return iterator(r and {r} or {})
  end
  function terminal.send(from,to)
    local a,b=find(from),find(to)
    if not a or not b then return false,'Machine not found' end
    if not a.patterns[from.slot] then return false,'No source pattern' end
    local slot=to.slot
    if slot==-1 then
      for i=0,8 do if not b.patterns[i] then slot=i; break end end
      if slot==-1 then return false,'No empty slot in target machine' end
    end
    if slot<0 or slot>8 then return false,'Target slot out of bounds' end
    if b.patterns[slot] then return false,'Target occupied' end
    b.patterns[slot]=a.patterns[from.slot]; a.patterns[from.slot]=nil
    return true,slot
  end
  local editor={}
  function editor.getInterfacePattern(slot)
    return inventories[1].patterns[slot-1] and C.copy(inventories[1].patterns[slot-1])
  end
  local function set(side,slot,index,d,kind)
    local p=assert(inventories[1].patterns[slot-1])
    if d then
      local value=C.copy(d); value.label=d.name
      -- Real OC resolves labels from item IDs/NBT. Preserve the matching demo label.
      for _,r in ipairs(inventories) do for _,q in pairs(r.patterns) do
        for _,s in ipairs(q[side]) do if s.name==d.name and s.tag==d.tag then value.label=s.label end end
      end end
      if kind=='fluid' then value.amount=d.size; value.damage=nil else value.damage=d.damage or 0 end
      value.hasTag=d.tag~=nil
      p[side][index]=value
    else
      -- Model Java NBTTagList removal even when the Lua view has nil holes.
      local last=0; for k in pairs(p[side]) do last=math.max(last,k) end
      for i=index,last-1 do p[side][i]=p[side][i+1] end
      p[side][last]=nil
    end
    return true
  end
  function editor.setInterfacePatternInput(...) return set('inputs',...) end
  function editor.setInterfacePatternOutput(...) return set('outputs',...) end
  function editor.getItemsInNetwork() return {item('minecraft:iron_ingot','Iron Ingot',100),item('minecraft:gold_ingot','Gold Ingot',100)} end
  function editor.getFluidsInNetwork() return {{name='water',label='Water',amount=10000}} end
  return {terminal=terminal,editor=editor,station=station,source=source,inventories=inventories}
end
return M
