-- Every mutation has a durable before/after record. Recovery checks physical inventories.
local C=require('ape.codec')
local Model=require('ape.model')
local M={}
local function signature(raw) return raw and Model.signature(Model.pattern(raw)) end
local function same(raw,p) return raw and signature(raw)==Model.signature(p) end
function M.new(api,store)
  local self={}
  local function save(j) store.save('transaction',j) end
  local function moveMatch(j,patterns)
    local matches={}
    for slot,raw in pairs(patterns) do
      if type(slot)=='number' and type(raw)=='table' and not j.occupied[slot] and
        (not j.movedSlot or slot==j.movedSlot) and
        Model.fingerprint(raw)==j.sourceFingerprint then
        matches[#matches+1]=slot
      end
    end
    assert(#matches<=1,'Multiple matching new destination patterns; inspect interfaces before recovery')
    return matches[1]
  end
  local function resumeMove(action,j)
    local source=api.read(j.source)
    local slot=moveMatch(j,api.patternsAt(j.destination))
    assert(not (source and slot),'Pattern appears in both interfaces; preserve the journal')
    if source then
      assert(Model.fingerprint(source)==j.sourceFingerprint,
        'Original pattern changed; preserve the journal')
      if j.state=='returning' or action=='restore' then
        store.finish(j); return j.source
      end
      local target=C.copy(j.destination); target.slot=-1
      j.movedSlot=api.move(j.source,target)
      j.state='moved'; save(j)
      return resumeMove(action,j)
    end
    assert(slot,'Pattern missing from both interfaces; preserve the journal')
    local target=C.copy(j.destination); target.slot=slot
    if action=='restore' then
      j.state='returning'; save(j)
      api.move(target,j.source)
      local returned=api.read(j.source)
      assert(returned and Model.fingerprint(returned)==j.sourceFingerprint and
        api.read(target)==nil,'Return verification failed; preserve the journal')
      store.finish(j); return j.source
    end
    j.movedSlot=slot; j.state='moved'; save(j)
    store.finish(j); return target
  end
  local function allowed(j,raw)
    local s=signature(raw)
    local layout=raw and Model.pattern(raw).layout
    return (s==Model.signature(j.current) and C.equal(layout,j.current.layout)) or
      (j.next and s==Model.signature(j.next) and C.equal(layout,j.next.layout))
  end
  local function adapterRead(expected)
    local raw
    for attempt=1,4 do
      raw=api.stageRead()
      if (raw==nil)==(expected=='empty') then break end
      if attempt<4 then api.wait(0.1) end
    end
    return raw
  end
  local function probeBinding(j)
    -- Terminal and Adapter can serialize the outer encoded-pattern stack
    -- differently. Observe the physical slot transition before trusting a
    -- recipe-only comparison; an unrelated identical pattern will not clear.
    assert(j.state=='prepared' or j.state=='staged' or j.state=='probing',
      'Cannot probe after editing has begun')
    j.state='probing'; save(j)
    assert(api.read(j.source)==nil, 'Original slot became occupied; journal retained')
    api.move(j.station,j.source)
    assert(api.read(j.station)==nil and same(api.read(j.source),j.original),
      'Probe return verification failed; preserve the journal')
    assert(adapterRead('empty')==nil,
      'Editing Adapter did not clear when the pattern left; use Restore original')
    j.probeCleared=true; save(j)
    api.move(j.source,j.station)
    assert(api.read(j.source)==nil and same(api.read(j.station),j.original),
      'Probe staging verification failed; preserve the journal')
    local localStage=adapterRead('present')
    assert(localStage and same(localStage,j.original) and
      C.equal(Model.pattern(localStage).layout,j.original.layout),
      'Editing Adapter did not show the returned pattern; use Restore original')
    j.bindingVerified=true; j.state='staged'; save(j)
    return localStage
  end
  local function rewrite(j,target)
    local raw=assert(api.stageRead(), 'Editing station is empty')
    assert(allowed(j,raw), 'Station contents changed unexpectedly; automatic editing stopped')
    j.current=Model.pattern(raw); j.next=nil; save(j)
    local function step(side,index,value)
      local nextState=C.copy(j.current)
      local positions=nextState.layout[side]
      local physical=positions[index] or ((positions[#positions] or 0)+1)
      assert(physical<=512,'Native pattern slot limit reached')
      if value then nextState[side][index]=C.copy(value); positions[index]=physical
      else
        table.remove(nextState[side],index); table.remove(positions,index)
        for i,pos in ipairs(positions) do if pos>physical then positions[i]=pos-1 end end
      end
      j.next=nextState; j.state='editing'; save(j)
      api.write(side,physical,value)
      local actual=api.stageRead()
      assert(same(actual,nextState) and C.equal(Model.pattern(actual).layout,nextState.layout),
        'Read-back mismatch; recovery journal retained')
      j.current=nextState; j.next=nil; save(j)
    end
    for _,side in ipairs({'inputs','outputs'}) do
      -- Rewrite by index, then remove surplus entries from the END: OC removal shifts indices.
      for i,s in ipairs(target[side]) do
        local old=j.current[side][i]
        if not old or Model.identity(old)~=Model.identity(s) or old.size~=s.size then step(side,i,s) end
      end
      for i=#j.current[side],#target[side]+1,-1 do step(side,i,nil) end
    end
    assert(same(api.stageRead(),target), 'Final Adapter verification mismatch')
    assert(same(api.read(j.station),target),
      'Final terminal verification mismatch; preserve the journal')
  end
  function self.pending()
    local j=store.pending()
    if j and j.state~='done' then return j end
  end
  function self.relocate(record,destination)
    assert(not self.pending(), 'Resolve the previous transaction first')
    assert(not require('ape.api').samePlace(record.endpoint,destination),
      'Choose a different interface')
    assert(not require('ape.api').samePlace(api.station,destination),
      'The editing station cannot be a destination')
    local raw=assert(api.read(record.endpoint),'Original pattern is missing')
    assert(Model.fingerprint(raw)==Model.fingerprint(record.raw),
      'Pattern changed since opening; rescan first')
    local occupied={}
    for slot,pattern in pairs(api.patternsAt(destination)) do
      if type(slot)=='number' and type(pattern)=='table' then occupied[slot]=true end
    end
    local j={version=1,kind='move',state='prepared',source=C.copy(record.endpoint),
      destination=C.copy(destination),occupied=occupied,
      sourceFingerprint=Model.fingerprint(raw),original=Model.pattern(raw)}
    j.destination.slot=-1
    store.save('last-move',j); save(j)
    return resumeMove('finish',j)
  end
  function self.apply(record,draft)
    assert(not self.pending(), 'Resolve the previous transaction first')
    Model.validate(record.pattern); Model.validate(draft)
    for _,side in ipairs({'inputs','outputs'}) do
      local positions=record.pattern.layout[side]
      assert((positions[#positions] or 0)+math.max(0,#draft[side]-#positions)<=512,
        'Native pattern slot limit reached; compact this pattern in an AE terminal first')
    end
    assert(Model.signature(record.pattern)~=Model.signature(draft), 'No changes to save')
    assert(not require('ape.api').samePlace(record.endpoint,api.station), 'Cannot edit the staging interface')
    local raw=assert(api.read(record.endpoint), 'Original pattern is missing')
    assert(type(raw.tag)=='string', 'OC hides pattern NBT; enable allowItemStackNBTTags before editing')
    assert(Model.fingerprint(raw)==Model.fingerprint(record.raw), 'Pattern changed since scanning; rescan first')
    assert(api.read(api.station)==nil and api.stageRead()==nil, 'Editing slot must be empty')
    local j={version=1,state='prepared',source=C.copy(record.endpoint),station=C.copy(api.station),
      original=C.copy(record.pattern),draft=C.copy(draft),current=C.copy(record.pattern),
      sourceFingerprint=Model.fingerprint(raw)}
    -- Permanent audit backup before moving the physical pattern.
    store.save('last-original',j)
    save(j)
    api.move(j.source,j.station)
    j.state='staged'; save(j)
    local remote=assert(api.read(j.station),'Transferred pattern is not visible in the selected editing interface')
    assert(same(remote,j.original),'Transferred pattern changed unexpectedly; use Restore original')
    local staged=adapterRead('present')
    if not staged then
      error('Editing Adapter sees an empty slot after transfer; use Restore original, then check Adapter selection')
    end
    if signature(staged)~=signature(remote) or
      not C.equal(Model.pattern(staged).layout,Model.pattern(remote).layout) then
      error('Adapter sees a different recipe than the selected editing interface; use Restore original')
    end
    return self.resume('finish')
  end
  function self.resume(action)
    assert(action=='finish' or action=='restore', 'Choose finish or restore')
    local j=assert(self.pending(), 'No interrupted transaction')
    if j.kind=='move' then return resumeMove(action,j) end
    assert(C.equal(j.station,api.station), 'Reconnect the original editing station before recovery')
    local source=api.read(j.source)
    local remoteStage=api.read(j.station)
    if not remoteStage then
      assert(source and (same(source,j.original) or same(source,j.draft)),
        'Pattern is missing or changed; preserve the journal and inspect both interfaces')
      -- A crash after returning the pattern is resolved by inspecting its actual state.
      local wanted=action=='restore' and j.original or j.draft
      if same(source,wanted) and (action=='restore' or j.state=='returning') then
        store.finish(j); return true
      end
      assert(j.state=='prepared' or j.state=='probing',
        'Pattern already returned with different contents; rescan before another edit')
      if j.state=='probing' then
        assert(same(source,j.original), 'Probe source changed; preserve the journal')
        assert(adapterRead('empty')==nil,
          'Editing Adapter did not clear when the pattern left; use Restore original')
        j.probeCleared=true; save(j)
      else
        assert(Model.fingerprint(source)==j.sourceFingerprint, 'Source was modified during interruption')
      end
      api.move(j.source,j.station)
      remoteStage=api.read(j.station)
    else assert(not source, 'Original slot is occupied; never overwrite it') end
    local readOk,localStage=pcall(api.stageRead)
    if not readOk then
      if action~='restore' then error(localStage) end
      localStage=nil
    end
    if localStage and not j.bindingVerified and j.probeCleared and
      same(localStage,j.original) and
      C.equal(Model.pattern(localStage).layout,j.original.layout) and
      same(remoteStage,j.original) then
      j.bindingVerified=true; j.state='staged'; save(j)
    end
    -- Older journals can already be mid-edit; they cannot safely be moved
    -- through a fresh probe, so keep their exact-read recovery contract.
    if localStage and not j.bindingVerified and j.state=='editing' and
      Model.fingerprint(localStage)==Model.fingerprint(remoteStage) then
      j.bindingVerified=true; save(j)
    end
    if localStage and not j.bindingVerified and action=='finish' and
      same(localStage,j.original) and same(remoteStage,j.original) and
      C.equal(Model.pattern(localStage).layout,Model.pattern(remoteStage).layout) then
      localStage=probeBinding(j)
      remoteStage=api.read(j.station)
    end
    if not localStage or not j.bindingVerified or
      signature(localStage)~=signature(remoteStage) or
      not C.equal(Model.pattern(localStage).layout,Model.pattern(remoteStage).layout) then
      -- Wrong adapter: no edits have been made through it if the station remains original.
      assert(action=='restore' and same(remoteStage,j.original),
        'Adapter/station mismatch; select Restore original to return an unchanged pattern')
      j.state='returning'; save(j); api.move(j.station,j.source)
      assert(same(api.read(j.source),j.original), 'Return verification failed')
      store.finish(j); return true
    end
    assert(allowed(j,localStage), 'Unexpected pattern in editing slot; refusing to modify it')
    local target=action=='restore' and j.original or j.draft
    rewrite(j,target)
    j.state='returning'; save(j)
    assert(api.read(j.source)==nil, 'Original slot became occupied; journal retained')
    api.move(j.station,j.source)
    assert(same(api.read(j.source),target) and api.read(j.station)==nil, 'Return verification failed')
    store.finish(j)
    return true
  end
  return self
end
return M
