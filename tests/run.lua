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
  r.raw=api.read(r.endpoint); r.pattern=Model.pattern(r.raw)
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
check(d.terminal.getInterfaces()().side=='UNKNOWN','Fixture must mirror OC ForgeDirection strings')
local interfaces=api.interfaces()
check(interfaces[1].endpoint.side==2 and interfaces[2].endpoint.side==6 and interfaces[3].endpoint.side==6,
  'Normalize part and full-block interface sides')
local indexed=api.scan()
check(#indexed==4 and indexed[1].raw==nil and indexed[1].pattern==nil,
  'Network scan must retain only a compact search index')
check(Model.matchIndex(r.index,'QUANTIUM','inputs') and not Model.matchIndex(r.index,'QUANTIUM','outputs'),
  'Compact index must search the same ingredient labels')
check(not C.encode(r.index):find('renamed-item-nbt',1,true),'Search index must not retain item NBT')
local largeRaw=C.copy(r.raw)
largeRaw.tag=string.rep('pattern-nbt',500)
largeRaw.inputs[1].tag=string.rep('ingredient-nbt',500)
local compact=Model.index(largeRaw)
check(#C.encode(compact)*10<#C.encode(largeRaw),'Index should be much smaller than a pattern with NBT')
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
-- Moving a pattern may rewrite its outer stack metadata. The two independent
-- readers of the destination must agree; the original source representation
-- is not evidence that the OC adapter points at a different block.
d,api,store,tx,r=fixture()
local moveWithMetadata=api.move
api.move=function(from,to)
  moveWithMetadata(from,to)
  if Api.samePlace(to,api.station) then d.inventories[1].patterns[0].tag='repacked-pattern-metadata' end
end
tx.apply(r,Model.scale(r.pattern,2))
check(not tx.pending() and api.stageRead()==nil and api.read(r.endpoint).tag=='repacked-pattern-metadata',
  'A valid destination must not be rejected because its outer metadata changed on transfer')
-- Allow a briefly stale local Adapter read after the terminal reports a move.
d,api,store,tx,r=fixture()
local immediateStageRead=api.stageRead
local stageReads=0
api.stageRead=function()
  stageReads=stageReads+1
  if stageReads==2 or stageReads==3 then return nil end
  return immediateStageRead()
end
tx.apply(r,Model.scale(r.pattern,2))
check(stageReads>=4 and not tx.pending(),'A delayed Adapter view should be retried before stopping')
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
-- Relocation uses the terminal's first-empty-slot transfer, without touching
-- the adapter-connected editing station or overwriting destination patterns.
d,api,store,tx,r=fixture()
local destination={location=C.copy(d.inventories[3].location),side=6,slot=-1}
local moved=tx.relocate(r,destination)
check(moved.slot==2 and api.read(r.endpoint)==nil and not tx.pending(),
  'Move should choose the first empty destination slot and close its journal')
check(Model.fingerprint(api.read(moved))==Model.fingerprint(r.raw) and
  d.inventories[3].patterns[0] and d.inventories[3].patterns[1] and api.stageRead()==nil,
  'Move must preserve the complete physical pattern and existing destination slots')
-- A crafting-grid pattern can be relocated even though its ingredients are read-only.
d,api,store,tx,r=fixture()
local grid={location=C.copy(d.inventories[3].location),side=6,slot=1}
local gridRaw=api.read(grid)
local gridRecord={endpoint=grid,raw=gridRaw,pattern=Model.pattern(gridRaw)}
local partDestination={location=C.copy(d.inventories[2].location),side=2,slot=-1}
local gridMoved=tx.relocate(gridRecord,partDestination)
check(gridMoved.slot==1 and api.read(grid)==nil and api.read(gridMoved).isCraftable,
  'Move should support terminal-visible part interfaces and grid patterns')
-- Stale source and a full destination cannot silently replace any pattern.
d,api,store,tx,r=fixture()
destination={location=C.copy(d.inventories[3].location),side=6,slot=-1}
d.inventories[2].patterns[0].tag='changed'
fails(function() tx.relocate(r,destination) end,'changed since opening')
check(not tx.pending())
d,api,store,tx,r=fixture()
destination={location=C.copy(d.inventories[3].location),side=6,slot=-1}
for slot=2,8 do d.inventories[3].patterns[slot]=C.copy(d.inventories[3].patterns[0]) end
fails(function() tx.relocate(r,destination) end,'No empty slot')
check(tx.pending() and api.read(r.endpoint)~=nil)
tx.resume('restore')
check(not tx.pending() and api.read(r.endpoint)~=nil)
-- Recover a relocation interrupted before or after any journal or transfer step.
local moveCrashCases=0
for actionIndex=1,15 do
  for _,when in ipairs({'before','after'}) do
    for _,recoveryAction in ipairs({'finish','restore'}) do
      local dd,aa,ss,tt,rr=fixture()
      local target={location=C.copy(dd.inventories[3].location),side=6,slot=-1}
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
      local resets={wrap(ss,'save'),wrap(aa,'move'),wrap(ss,'finish')}
      local ok=pcall(function() tt.relocate(rr,target) end)
      for _,reset in ipairs(resets) do reset() end
      if not ok then
        moveCrashCases=moveCrashCases+1
        local resumed=Tx.new(aa,ss)
        if resumed.pending() then resumed.resume(recoveryAction) end
        check(not resumed.pending())
        local atSource=aa.read(rr.endpoint)~=nil
        local atDestination=dd.inventories[3].patterns[2]~=nil
        check(atSource~=atDestination and aa.stageRead()==nil,
          'Recovery must leave one pattern, in its source or destination')
        check(dd.inventories[3].patterns[0] and dd.inventories[3].patterns[1],
          'Recovery must not overwrite existing destination patterns')
      elseif operation<actionIndex then break end
    end
  end
end
check(moveCrashCases>=10,'Move fault injection missed transaction boundaries')
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
fails(function() tx.resume('finish') end,'Adapter/station mismatch')
check(tx.pending()~=nil)
-- Wrong physical adapter binding is recoverable without writing to an unrelated interface.
d,api,store,tx,r=fixture()
local actual=api.stageRead
api.stageRead=function() return nil end
fails(function() tx.apply(r,twice) end,'empty slot after transfer')
tx.resume('restore')
api.stageRead=actual
check(api.read(r.endpoint)~=nil and not tx.pending())
-- Terminal and Adapter may serialize the same physical pattern's outer NBT
-- differently. A disappearance/reappearance probe proves their connection.
d,api,store,tx,r=fixture()
local actualMetadata=api.stageRead
local metadataReads=0
api.stageRead=function()
  metadataReads=metadataReads+1
  local current=actualMetadata()
  if metadataReads>1 and current then current.tag='different-outer-metadata' end
  return current
end
tx.apply(r,twice)
check(not tx.pending() and api.stageRead()==nil and
  Model.signature(Model.pattern(api.read(r.endpoint)))==Model.signature(twice),
  'Different outer metadata must not prevent a physically verified edit')
check(store.data['last-original'].sourceFingerprint==Model.fingerprint(r.raw),
  'Probe must preserve the original audit snapshot')
-- A wrong Adapter may coincidentally see an identical encoded pattern. Its
-- pattern must not be edited when it fails to clear on transfer.
d,api,store,tx,r=fixture()
local actualWrong=api.stageRead
local wrongPattern=C.copy(r.raw)
local wrongReads=0
api.stageRead=function()
  wrongReads=wrongReads+1
  if wrongReads==1 then return nil end
  return C.copy(wrongPattern)
end
fails(function() tx.apply(r,twice) end,'did not clear')
check(tx.pending() and api.read(r.endpoint)~=nil and api.read(api.station)==nil,
  'Failed probe must leave the source unchanged and retain recovery')
tx.resume('restore')
api.stageRead=actualWrong
check(not tx.pending() and Model.fingerprint(api.read(r.endpoint))==Model.fingerprint(r.raw))
-- Probe movements and journal saves are recoverable on either side of a crash.
local probeCrashCases=0
for actionIndex=1,35 do
  for _,when in ipairs({'before','after'}) do
    for _,recoveryAction in ipairs({'finish','restore'}) do
      local dd,aa,ss,tt,rr=fixture()
      local actual=aa.stageRead
      aa.stageRead=function()
        local current=actual()
        if current then current.tag='adapter-serializes-differently' end
        return current
      end
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
        probeCrashCases=probeCrashCases+1
        local resumed=Tx.new(aa,ss)
        if resumed.pending() then
          local recovered,err=pcall(function() resumed.resume(recoveryAction) end)
          if not recovered then
            -- A fully returned edited pattern cannot be restored by moving
            -- it back after the return boundary; Finish closes the journal.
            check(recoveryAction=='restore' and aa.read(rr.endpoint)~=nil,
              'Probe recovery failed: '..tostring(err)..' at '..actionIndex..' '..when)
            resumed.resume('finish')
          end
        end
        check(not resumed.pending() and aa.stageRead()==nil and aa.read(rr.endpoint)~=nil,
          'Probe recovery must return one pattern to the original slot')
        local result=Model.signature(Model.pattern(aa.read(rr.endpoint)))
        check(result==Model.signature(rr.pattern) or
          result==Model.signature(Model.scale(rr.pattern,2)))
      elseif operation<actionIndex then break end
    end
  end
end
check(probeCrashCases>30,'Probe fault injection missed transaction boundaries')
-- Restore must still return an unchanged remote pattern if the unrelated or
-- disconnected adapter throws when its local slot is read.
d,api,store,tx,r=fixture()
local localRead=api.stageRead
local reads=0
api.stageRead=function()
  reads=reads+1
  if reads==1 then return nil end
  error('Adapter unavailable')
end
fails(function() tx.apply(r,twice) end,'Adapter unavailable')
tx.resume('restore')
api.stageRead=localRead
check(not tx.pending() and api.read(r.endpoint)~=nil and api.stageRead()==nil)
-- Headless screen, keyboard and real application journeys.
require('persistence_tests').run(check,fails)
require('ui_tests').run(check,fails,memoryStore)
print('PASS: '..total..' checks; '..crashCases..' edit, '..probeCrashCases..' probe and '..moveCrashCases..' move recovery cases')
