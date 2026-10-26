local C=require('ape.codec')
local Model=require('ape.model')
local M={}
local directions={DOWN=0,UP=1,NORTH=2,SOUTH=3,WEST=4,EAST=5,UNKNOWN=6}
local function direction(value)
  if value==nil then return 6 end
  if type(value)=='string' then value=directions[value:upper()] end
  assert(type(value)=='number' and value%1==0 and value>=0 and value<=6,
    'Unsupported interface side from ME Interface Terminal')
  return value
end
local function endpoint(info,slot)
  local l=info.location
  assert(type(l)=='table' and l.x and l.y and l.z, 'Interface location unavailable')
  return {location=C.copy(l),side=direction(info.side),slot=slot or 0}
end
function M.samePlace(a,b)
  return a.side==b.side and C.equal(a.location,b.location)
end
function M.new(terminal,editor,station,yieldFn)
  local api={terminal=terminal,editor=editor,station=station}
  function api.wait(seconds) if yieldFn then yieldFn(seconds) end end
  local function each(iterator,fn)
    local n=0
    while true do
      local row=iterator()
      if not row then break end
      n=n+1; fn(row,n)
      if yieldFn and n%4==0 then yieldFn() end
    end
  end
  function api.interfaces()
    local out={}
    each(terminal.getInterfaces(),function(info)
      out[#out+1]={name=info.name or '(unnamed)',endpoint=endpoint(info)}
    end)
    table.sort(out,function(a,b) return a.name<b.name end)
    return out
  end
  function api.scan(progress)
    local out,skipped={},0
    local it=terminal.getInterfaces()
    each(it,function(info,n)
      local place=endpoint(info)
      if not station or not M.samePlace(place,station) then
        for k,raw in pairs(info.patterns or {}) do
          if type(k)=='number' and type(raw)=='table' then
            local ok,index=pcall(Model.index,raw)
            if ok then
              out[#out+1]={name=info.name or '(unnamed)',endpoint=endpoint(info,k),
                index=index}
            else skipped=skipped+1 end
          end
        end
      end
      if progress then progress(n,#out) end
    end)
    table.sort(out,function(a,b)
      local at,bt=a.index.title,b.index.title
      if at~=bt then return at<bt end
      if a.name~=b.name then return a.name<b.name end
      return C.encode(a.endpoint)<C.encode(b.endpoint)
    end)
    return out,skipped
  end
  function api.read(ep)
    local found=false
    local raw
    each(terminal.getInterfacesByLocation(ep.location,ep.side),function(info)
      if M.samePlace(endpoint(info),ep) then
        assert(not found, 'Ambiguous interface location')
        found=true; raw=(info.patterns or {})[ep.slot]
      end
    end)
    assert(found, 'Interface unavailable; check power, channels, chunks and terminal visibility')
    return raw
  end
  function api.patternsAt(ep)
    local found,patterns=false,nil
    each(terminal.getInterfacesByLocation(ep.location,ep.side),function(info)
      if M.samePlace(endpoint(info),ep) then
        assert(not found, 'Ambiguous interface location')
        found=true; patterns=info.patterns or {}
      end
    end)
    assert(found, 'Interface unavailable; check power, channels, chunks and terminal visibility')
    return patterns
  end
  function api.stageRead() return editor.getInterfacePattern(station.slot+1) end
  function api.move(from,to)
    local ok,slot=terminal.send(from,to)
    assert(ok==true, 'Pattern transfer failed: '..tostring(slot))
    if to.slot==-1 then
      assert(type(slot)=='number' and slot>=0 and slot%1==0,
        'Transfer returned an invalid destination slot')
    else assert(slot==to.slot, 'Transfer returned an unexpected destination slot') end
    return slot
  end
  function api.write(side,index,value)
    local method=side=='inputs' and editor.setInterfacePatternInput or editor.setInterfacePatternOutput
    local ok
    if value then
      local detail,kind=Model.detail(value)
      ok=method(station.slot+1,index,detail,kind)
    else ok=method(station.slot+1,index) end
    assert(ok==true, 'Pattern edit was rejected')
  end
  function api.catalog()
    local out,seen={},{}
    local function add(s)
      local key=Model.identity(s)
      if not seen[key] then
        seen[key]=true; local v=C.copy(s); if v.size==0 then v.size=1 end
        out[#out+1]=v
      end
    end
    -- Read identities on demand instead of retaining every full pattern during Scan.
    each(terminal.getInterfaces(),function(info)
      local place=endpoint(info)
      if not station or not M.samePlace(place,station) then
        for _,raw in pairs(info.patterns or {}) do
          if type(raw)=='table' then
            local ok,p=pcall(Model.pattern,raw)
            if ok then
              for _,side in ipairs({'inputs','outputs'}) do
                for _,s in ipairs(p[side]) do add(s) end
              end
            end
          end
        end
      end
    end)
    -- This is a deliberate user-triggered catalog refresh, never a polling loop.
    for _,s in pairs(editor.getItemsInNetwork()) do add(Model.stack(s)) end
    if editor.getFluidsInNetwork then
      for _,s in pairs(editor.getFluidsInNetwork()) do add(Model.stack(s)) end
    end
    table.sort(out,function(a,b)
      if a.label~=b.label then return a.label<b.label end
      return Model.identity(a)<Model.identity(b)
    end)
    return out
  end
  return api
end
return M
