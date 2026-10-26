package.path='./src/?.lua;./tests/?.lua;'..package.path
local C=require('ape.codec')
local Model=require('ape.model')
local Api=require('ape.api')
local Tx=require('ape.transaction')
local Demo=require('ape.demo')
local total=0
function check(ok,message) total=total+1; assert(ok,message or ('Check '..total..' failed')) end
function fails(fn,fragment)
  local ok,err=pcall(fn); check(not ok,'Expected failure')
  if fragment then check(tostring(err):find(fragment,1,true),'Wrong failure: '..tostring(err)) end
end
local function memoryStore()
  local data={}
  return {
    load=function(k) return data[k] and C.copy(data[k]) end,
    save=function(k,v) data[k]=C.copy(v) end,
    pending=function() return data.transaction and C.copy(data.transaction) end,
    finish=function(j) j.state='done'; data.transaction=C.copy(j) end,
    data=data}
end
local function fixture()
  local d=Demo.new(); local api=Api.new(d.terminal,d.editor,d.station)
  local store=memoryStore(); local tx=Tx.new(api,store)
  local records=api.scan(); local r
  for _,record in ipairs(records) do if record.endpoint.slot==0 and record.name=='Assembly Line' then r=record end end
  return d,api,store,tx,r
end
-- Binary-safe persistence, hostile/corrupt files and deterministic ordering.
local binary='\0\1\255\128\n\r"\\'
check(C.equal(C.decode(C.encode({[0]=binary,a=3,b=true,c={false,1e10}})),{[0]=binary,a=3,b=true,c={false,1e10}}))
check(C.encode({b=2,a=1})==C.encode({a=1,b=2}))
check(C.adler('Wikipedia')=='11e60398')
fails(function() C.decode('os.execute("bad")') end)
fails(function() C.decode('S10:a') end)
fails(function() C.decode('Nextra') end)
local cycle={}; cycle.self=cycle; fails(function() C.encode(cycle) end)
local d,api,store,tx,r=fixture()
local p=r.pattern
check(#api.scan()==4,'Includes source slots 0/8 and crafting-grid pattern, excludes editor')
check(Model.match(p,'QUANTIUM','inputs'))
check(not Model.match(p,'QUANTIUM','outputs'))
check(Model.match(p,'Mainframe','outputs'))
check(Model.match(p,'gregtech:gt.metaitem.01','both'))
local twice=Model.scale(p,2)
check(twice.inputs[1].size==16 and twice.outputs[1].size==4)
check(C.equal(Model.scale(twice,0.5),p))
check(twice.inputs[2].tag=='renamed-item-nbt','Keep exact NBT')
local odd=C.copy(p); odd.inputs[1].size=3
fails(function() Model.scale(odd,0.5) end,'whole number')
check(odd.inputs[1].size==3,'Failed divide must not partially modify draft')
local large=C.copy(p); large.inputs[1].size=Model.MAX_AMOUNT
fails(function() Model.scale(large,2) end,'range')
local catalyst=C.copy(p); catalyst.inputs[2].size=0
check(Model.scale(catalyst,0.5).inputs[2].size==0)
local removed=C.copy(p); Model.remove(removed,'inputs',2)
check(#removed.inputs==1)
fails(function() Model.remove(removed,'outputs',1) end,'Keep at least one')
local fluid=Model.stack({name='water',label='Water',amount=1000})
check(fluid.kind=='fluid' and fluid.size==1000)
local fdetail,ftype=Model.detail(fluid)
check(ftype=='fluid' and fdetail.amount==1000 and fdetail.size==1000)
local hidden=C.copy(p); hidden.inputs[2].tag=nil
fails(function() Model.validate(hidden) end,'NBT is hidden')
local taggedFluid=C.copy(p); taggedFluid.inputs[1]=Model.stack({name='water',amount=1000,hasTag=true})
fails(function() Model.validate(taggedFluid) end,'Tagged fluids')
local crafting=C.copy(p); crafting.crafting=true
fails(function() Model.validate(crafting) end,'read-only')
-- Live transfer numbering and indexed writes; swap ingredient identity and trim a tail.
tx.apply(r,twice)
check(api.stageRead()==nil)
check(Model.signature(Model.pattern(api.read(r.endpoint)))==Model.signature(twice))
check(not tx.pending() and store.data['last-original'].original.inputs[1].size==8)
check(api.read(r.endpoint).inputs[2].tag=='renamed-item-nbt')
local current=api.read(r.endpoint)
check(current.isCraftable==false and current.tag=='demo-pattern-metadata','Preserve pattern metadata')
-- Processing patterns can contain empty native NBT slots. Logical rows must target
-- their real physical indices, and deletion shifts subsequent native positions.
d,api,store,tx,r=fixture()
local raw=d.inventories[2].patterns[0]
raw.inputs[3]=raw.inputs[2]; raw.inputs[2]=nil
r.raw=C.copy(raw); r.pattern=Model.pattern(raw)
check(r.pattern.layout.inputs[2]==3)
local sparse=Model.scale(r.pattern,2)
tx.apply(r,sparse)
check(api.read(r.endpoint).inputs[2]==nil and api.read(r.endpoint).inputs[3].size==8)
r.raw=C.copy(api.read(r.endpoint)); r.pattern=Model.pattern(r.raw)
local compact=C.copy(r.pattern); Model.remove(compact,'inputs',1)
tx.apply(r,compact)
check(#Model.pattern(api.read(r.endpoint)).inputs==1)
-- Concurrent edit must be detected before any movement.
d,api,store,tx,r=fixture()
d.inventories[2].patterns[0].inputs[1].size=99
fails(function() tx.apply(r,twice) end,'changed since scanning')
check(not tx.pending() and api.stageRead()==nil)
-- Occupied station must not be overwritten.
d,api,store,tx,r=fixture()
d.inventories[1].patterns[0]=C.copy(r.raw)
fails(function() tx.apply(r,twice) end,'must be empty')
check(not tx.pending())
-- Mutation failures preserve a recoverable before/after WAL. Restore after a partial edit.
d,api,store,tx,r=fixture()
local write=api.write; local calls=0
api.write=function(...)
  calls=calls+1
  if calls==2 then error('Injected disconnect') end
  return write(...)
end
fails(function() tx.apply(r,twice) end,'Injected disconnect')
check(tx.pending() and api.read(r.endpoint)==nil and api.stageRead()~=nil)
api.write=write
tx.resume('restore')
check(Model.signature(Model.pattern(api.read(r.endpoint)))==Model.signature(r.pattern))
check(api.stageRead()==nil and not tx.pending())
-- Exhaustively inject crashes before/after every save, move, and write in the transaction.
local crashCases=0
for actionIndex=1,80 do
  for _,when in ipairs({'before','after'}) do
    for _,recoveryAction in ipairs({'finish','restore'}) do
      local dd,aa,ss,tt,rr=fixture()
      local operation=0
      local function wrap(obj,name)
        local fn=obj[name]
        obj[name]=function(...)
          operation=operation+1
          local hit=operation==actionIndex
          if hit and when=='before' then error('Power loss') end
          local result={fn(...)}
          if hit and when=='after' then error('Power loss') end
          return table.unpack(result)
        end
        return function() obj[name]=fn end
      end
      local resets={wrap(ss,'save'),wrap(aa,'move'),wrap(aa,'write'),wrap(ss,'finish')}
      local ok=pcall(function() tt.apply(rr,Model.scale(rr.pattern,2)) end)
      for _,reset in ipairs(resets) do reset() end
      if not ok then
        crashCases=crashCases+1
        local resumed=Tx.new(aa,ss)
        if resumed.pending() then
          local recoveryOk=pcall(function() resumed.resume(recoveryAction) end)
          if not recoveryOk then
            -- Once the pattern has returned, Finish acknowledges a completed save;
            -- Restore does not silently pull it out again after a crash at the return boundary.
            check(recoveryAction=='restore' and aa.read(rr.endpoint)~=nil)
            resumed.resume('finish')
          end
        end
        check(not resumed.pending())
        check(aa.stageRead()==nil and aa.read(rr.endpoint)~=nil)
        local result=Model.signature(Model.pattern(aa.read(rr.endpoint)))
        check(result==Model.signature(rr.pattern) or result==Model.signature(Model.scale(rr.pattern,2)))
      elseif operation<actionIndex then break end
    end
  end
end
check(crashCases>50,'Fault injection did not exercise enough boundaries')
-- Removing an entry must compact correctly, including appended replacements.
d,api,store,tx,r=fixture()
local draft=C.copy(r.pattern)
table.remove(draft.inputs,1)
draft.inputs[2]=Model.stack({name='minecraft:iron_ingot',label='Iron Ingot',size=3,damage=0})
tx.apply(r,draft)
check(Model.signature(Model.pattern(api.read(r.endpoint)))==Model.signature(draft))
-- Unknown station mutation and occupied return slot must be retained for manual inspection.
d,api,store,tx,r=fixture()
local move=api.move
api.move=function(a,b)
  move(a,b)
  if Api.samePlace(b,api.station) then error('Power loss') end
end
fails(function() tx.apply(r,twice) end,'Power loss')
api.move=move
d.inventories[1].patterns[0].inputs[1].size=12345
fails(function() tx.resume('finish') end,'Unexpected pattern')
check(tx.pending()~=nil)
-- Wrong physical adapter binding is recoverable without writing to an unrelated interface.
d,api,store,tx,r=fixture()
local actual=api.stageRead
api.stageRead=function() return nil end
fails(function() tx.apply(r,twice) end)
tx.resume('restore')
api.stageRead=actual
check(api.read(r.endpoint)~=nil and not tx.pending())
-- Headless screen, keyboard and real application journeys.
require('persistence_tests').run(check,fails)
require('ui_tests').run(check,fails,memoryStore)
print('PASS: '..total..' checks; '..crashCases..' injected interruption/recovery cases')
