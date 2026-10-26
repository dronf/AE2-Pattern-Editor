local C=require('ape.codec')
local Model=require('ape.model')
local Api=require('ape.api')
local M={VERSION='1.0.2'}
function M.run(options)
  options=options or {}
  local component=options.component or require('component')
  local event=options.event or require('event')
  local keyboard=options.keyboard or require('keyboard')
  local unicode=options.unicode or require('unicode')
  local gpu=options.gpu or component.gpu
  local store=options.store or require('ape.store').new(options.dir or '/home/.ae2-pattern-editor')
  local config=store.load('settings')
  local ui=require('ape.ui').new(gpu,event,keyboard,unicode)
  local keys=keyboard.keys
  local oldW,oldH=gpu.getResolution()
  local maxW,maxH=gpu.maxResolution()
  assert(maxW>=50 and maxH>=16,'A screen/GPU supporting at least 50x16 is required')
  gpu.setResolution(maxW,maxH)
  local running=true
  local state={mode='main',records={},results={},selected=1,side='inputs',entry=1,
    search={text=''},match='both',status='Press Scan to read patterns. No background polling.',page=1}
  local api,tx,catalog
  local draw
  local function status(s) state.status=s end
  local function mode(s) state.mode=s; ui.blur() end
  local function errorBox(err)
    state.error=tostring(err); state.returnMode=state.mode; mode('error')
  end
  local function progress(s) status(s); if draw then draw() end end
  local function connect()
    if options.demo then
      local d=options.demo
      api=Api.new(d.terminal,d.editor,d.station,options.yieldFn)
    else
      assert(config,'Run Setup first')
      local terminal=component.proxy(config.terminal)
      local editor=component.proxy(config.editor)
      assert(terminal.getInterfaces and terminal.getInterfacesByLocation and terminal.send,'Terminal integration unavailable')
      for _,method in ipairs({'getInterfacePattern','setInterfacePatternInput','setInterfacePatternOutput','getItemsInNetwork'}) do
        assert(editor[method],'Editing interface missing '..method)
      end
      api=Api.new(terminal,editor,config.station,function() os.sleep(0) end)
    end
    tx=require('ape.transaction').new(api,store)
  end
  local function filter()
    state.results={}
    for _,r in ipairs(state.records) do
      if Model.match(r.pattern,state.search.text,state.match) then state.results[#state.results+1]=r end
    end
    state.selected=math.max(1,math.min(state.selected,#state.results))
  end
  local function scan()
    assert(api,'Run Setup first')
    assert(not tx.pending(),'Resolve the interrupted save first')
    progress('Scanning interface patterns...')
    local skipped
    state.records,skipped=api.scan(function(n,p)
      if n%4==0 then progress('Scanning '..n..' interfaces; '..p..' patterns') end
    end)
    catalog=nil; filter()
    state.scanned=os.date and os.date('%H:%M:%S') or 'now'
    status(#state.records..' patterns cached at '..state.scanned..'; '..skipped..' unsupported skipped')
    mode('main')
  end
  local function recovery()
    local j=store.pending()
    return j and j.state~='done'
  end
  local function choose(title,items,callback,back)
    state.choice={title=title,items=items,callback=callback,back=back,selected=1}
    mode('choose')
  end
  local function components(method)
    local out={}
    for address,kind in component.list() do
      local proxy=component.proxy(address)
      if proxy[method] then out[#out+1]={label=kind..' '..address,value=address} end
    end
    table.sort(out,function(a,b) return a.label<b.label end)
    return out
  end
  local function setup()
    assert(not options.demo,'Demo already has a simulated setup')
    assert(not recovery(),'Keep the existing station connected until recovery finishes')
    local terms=components('getInterfaces')
    assert(#terms>0,'No ME Interface Terminal detected. Adapter must touch its cable block.')
    local function terminalSelected(t)
      local editors=components('getInterfacePattern')
      assert(#editors>0,'No normal full-block ME Interface touching an OC Adapter')
      local function editorSelected(e)
        local temp=Api.new(component.proxy(t.value),component.proxy(e.value))
        progress('Reading interfaces for setup...')
        local candidates={}
        for _,i in ipairs(temp.interfaces()) do
          if i.endpoint.side==6 then
            local l=i.endpoint.location
            candidates[#candidates+1]={label=i.name..' @ '..l.x..','..l.y..','..l.z,value=i.endpoint}
          end
        end
        assert(#candidates>0,'No terminal-visible full-block interface; check channels and visibility')
        choose('Select the EMPTY interface physically touching the editing Adapter',candidates,function(s)
          assert(temp.read(s.value)==nil,'Selected interface slot 1 is occupied')
          assert(component.proxy(e.value).getInterfacePattern(1)==nil,'Local editing slot 1 is occupied')
          config={terminal=t.value,editor=e.value,station=s.value}
          store.save('settings',config); connect()
          status('Setup saved. Keep the editing interface dedicated and empty.'); mode('main')
        end,function() mode('main') end)
      end
      if #editors==1 then editorSelected(editors[1]) else choose('Choose editing Adapter component',editors,editorSelected,function() mode('main') end) end
    end
    if #terms==1 then terminalSelected(terms[1]) else choose('Choose Interface Terminal component',terms,terminalSelected,function() mode('main') end) end
  end
  local function open()
    local r=assert(state.results[state.selected],'Select a pattern')
    state.record=r; state.original=C.copy(r.pattern); state.draft=C.copy(r.pattern)
    state.side='inputs'; state.entry=1; mode('edit')
    status(r.pattern.crafting and 'Crafting-grid pattern: read-only. Use the AE Pattern Terminal to edit.' or 'Draft only. Preview, then Apply to save.')
  end
  local function selectedStack() return state.draft[state.side][state.entry] end
  local function editable() return state.draft and not state.draft.crafting end
  local function quantity()
    assert(editable(),'Read-only pattern')
    local s=assert(selectedStack(),'Select an ingredient')
    state.amount={text=tostring(s.size),limit=10}; mode('amount'); ui.focus(state.amount,true)
  end
  local function saveQuantity()
    local text=state.amount.text
    local n=text:match('^%d+$') and tonumber(text)
    assert(n and n<=Model.MAX_AMOUNT,'Enter a whole amount from 0 to 2147483647')
    assert(state.side~='outputs' or n>0,'Output amount must be positive')
    selectedStack().size=n; mode('edit'); status('Amount changed in draft')
  end
  local function remove()
    assert(editable(),'Read-only pattern')
    local s=assert(selectedStack(),'Select an ingredient')
    state.confirm={text='Remove '..s.label..' from '..state.side..'?',yes=function()
      Model.remove(state.draft,state.side,state.entry)
      state.entry=math.min(state.entry,#state.draft[state.side]); mode('edit'); status('Removed from draft')
    end,no=function() mode('edit') end}
    mode('confirm')
  end
  local function pick(replace)
    assert(editable(),'Read-only pattern')
    if replace then assert(selectedStack(),'Select an ingredient') end
    if not catalog then progress('Reading stored items, fluids and cached pattern ingredients...'); catalog=api.catalog(state.records) end
    state.picker={search={text=''},selected=1,replace=replace}
    mode('picker'); ui.focus(state.picker.search)
  end
  local function pickerResults()
    local out={}; local q=state.picker.search.text:lower()
    for _,s in ipairs(catalog or {}) do
      if s.label:lower():find(q,1,true) or s.name:lower():find(q,1,true) then out[#out+1]=s end
    end
    state.picker.selected=math.max(1,math.min(state.picker.selected,#out))
    return out
  end
  local function pickDone()
    local s=C.copy(assert(pickerResults()[state.picker.selected],'Select an item/fluid'))
    assert(not s.hasTag or s.tag,'NBT is hidden; this identity cannot be copied safely')
    local list=state.draft[state.side]
    if state.picker.replace then s.size=assert(selectedStack()).size; list[state.entry]=s
    else assert(#list<Model.MAX_ENTRIES,'Ingredient limit reached'); s.size=1; list[#list+1]=s; state.entry=#list end
    mode('edit'); quantity()
  end
  local function scale(factor)
    state.draft=Model.scale(state.draft,factor); status('Draft scaled '..(factor==2 and 'x2' or '/2'))
  end
  local function preview()
    Model.validate(state.original); Model.validate(state.draft)
    assert(Model.signature(state.original)~=Model.signature(state.draft),'No changes to preview')
    state.diff=Model.diff(state.original,state.draft); state.page=1; mode('preview')
  end
  local function apply()
    progress('Saving: moving, editing, verifying, returning pattern...')
    tx.apply(state.record,state.draft)
    -- Update cache from a fresh read; a later external edit is still checked before the next Apply.
    local raw=assert(api.read(state.record.endpoint),'Cannot read returned pattern')
    state.record.raw=C.copy(raw); state.record.pattern=Model.pattern(raw)
    filter(); catalog=nil; mode('main'); status('Saved and verified at original interface/slot')
  end
  local function resume(action)
    assert(tx,'Reconnect the original adapters before recovery')
    progress('Recovering interrupted transaction...')
    tx.resume(action); state.records={}; filter(); catalog=nil
    mode('main'); status('Recovery complete. Press Scan to refresh patterns.')
  end
  local function backEdit()
    if Model.signature(state.original)==Model.signature(state.draft) then mode('main'); return end
    state.confirm={text='Discard the unsaved draft?',yes=function() mode('main') end,no=function() mode('edit') end}
    mode('confirm')
  end
  local function listRows(items,index,y,bottom,label,onChoose)
    local first,last=ui.page(index,#items,y,bottom)
    for i=first,last do
      ui.row(1,y+i-first,ui.w,label(items[i],i),i==index,function() onChoose(i,i==index) end)
    end
    ui.text(1,bottom+1,#items==0 and 'No matches' or (first..'-'..last..' of '..#items),0x99aabb)
  end
  local help={
    'Search cached inputs/outputs by display label or registry ID.',
    'Click a result, then Open (or click the selected row again).',
    'Inputs/Outputs selects the ingredient list. Amount edits quantity.',
    'Add/Replace picks identities from stored items or scanned recipes.',
    'Remove deletes the selected ingredient from the draft.',
    'x2 and /2 scale every positive input/output; zero catalysts stay zero.',
    '/2 refuses fractional amounts. Quantities are limited to 2147483647.',
    'Preview shows changes; Apply moves, edits, verifies and returns.',
    'Stop affected crafting jobs before applying a recipe change.',
    'Do not put machines/storage requests on the editing interface.',
    'Tagged identities require OC allowItemStackNBTTags=true.',
    'Crafting-grid patterns are read-only; processing patterns can edit.',
    'Arrow keys/page keys and mouse wheel navigate lists.',
    'Click a field to type. Ctrl+A selects all. Tab changes fields.',
    'Backspace/Delete, Home/End and clipboard paste are supported.',
    'Esc leaves a field; Esc again goes back. Enter selects/saves.',
    'Scan is manual; no background AE polling. Keep chunks loaded.',
    'An interrupted save locks editing until Finish/Restore succeeds.'}
  draw=function()
    local suffix=options.demo and ' [DEMO - no real AE access]' or ''
    ui.frame('AE2 Pattern Editor '..M.VERSION..suffix,state.status)
    local w,h=ui.w,ui.h
    if state.mode=='main' then
      local x=ui.button(1,2,'Scan',scan,api~=nil)
      x=ui.button(x,2,'Setup',setup,not options.demo)
      x=ui.button(x,2,'Help',function() state.page=1; mode('help') end)
      ui.button(x,2,'Quit',function() running=false end)
      ui.text(1,3,'Search'); ui.field(8,3,w-7,state.search,function() filter() end)
      filter()
      ui.button(1,4,'Match: '..state.match,function()
        state.match=state.match=='both' and 'inputs' or state.match=='inputs' and 'outputs' or 'both'; filter()
      end)
      ui.text(1,5,'Output / pattern                         Interface')
      listRows(state.results,state.selected,6,h-4,function(r)
        local title=Model.title(r.pattern)..(r.pattern.crafting and ' [grid]' or '')
        local n=math.floor(w*0.55)
        return unicode.sub(title,1,n-1)..string.rep(' ',math.max(1,n-unicode.len(title)))..r.name
      end,function(i,again) state.selected=i; if again then open() end end)
      ui.button(1,h-1,'Open',open,#state.results>0)
      ui.text(10,h-1,'Scan: '..(state.scanned or 'not yet'),0x99aabb)
    elseif state.mode=='edit' then
      ui.text(1,2,Model.title(state.draft)..' @ '..state.record.name)
      local x=ui.button(1,3,'Inputs '..#state.draft.inputs,function() state.side='inputs'; state.entry=1 end)
      ui.button(x,3,'Outputs '..#state.draft.outputs,function() state.side='outputs'; state.entry=1 end)
      ui.text(1,4,state.side:upper()..'  Amount / label / registry ID')
      listRows(state.draft[state.side],state.entry,5,h-6,function(s)
        return s.size..(s.kind=='fluid' and 'mB ' or 'x ')..s.label..' | '..s.name
      end,function(i,again) state.entry=i; if again and editable() then quantity() end end)
      local yes=editable(); local selected=selectedStack()~=nil
      x=ui.button(1,h-4,'Add',function() pick(false) end,yes)
      x=ui.button(x,h-4,'Replace',function() pick(true) end,yes and selected)
      x=ui.button(x,h-4,'Amount',quantity,yes and selected)
      ui.button(x,h-4,'Remove',remove,yes and selected)
      x=ui.button(1,h-2,'/2',function() scale(0.5) end,yes)
      x=ui.button(x,h-2,'x2',function() scale(2) end,yes)
      x=ui.button(x,h-2,'Preview',preview,yes)
      ui.button(x,h-2,'Back',backEdit)
    elseif state.mode=='amount' then
      ui.text(1,3,'Amount for '..selectedStack().label)
      ui.text(1,5,state.side=='inputs' and 'Whole units/mB; 0 means a reusable catalyst' or 'Positive whole units/mB')
      ui.field(1,7,math.min(w,24),state.amount,saveQuantity)
      local x=ui.button(1,9,'Save draft',saveQuantity)
      ui.button(x,9,'Cancel',function() mode('edit') end)
    elseif state.mode=='picker' then
      ui.text(1,2,'Choose an exact item/fluid identity; amount is edited next')
      ui.field(1,3,w,state.picker.search)
      local list=pickerResults()
      listRows(list,state.picker.selected,5,h-4,function(s)
        return (s.kind=='fluid' and '[F] ' or '[I] ')..s.label..' | '..s.name..
          (s.hasTag and (' #NBT '..(s.tag and C.adler(s.tag) or 'hidden')) or '')
      end,function(i,again) state.picker.selected=i; if again then pickDone() end end)
      local x=ui.button(1,h-1,'Select',pickDone,#list>0)
      ui.button(x,h-1,'Back',function() mode('edit') end)
    elseif state.mode=='preview' then
      ui.text(1,2,'Review changes. Stop affected AE jobs before applying.')
      ui.lines(state.diff,state.page,4,h-7)
      local x=ui.button(1,h-2,'Apply',apply)
      ui.button(x,h-2,'Back',function() mode('edit') end)
    elseif state.mode=='choose' then
      local choice=state.choice
      ui.text(1,3,choice.title)
      listRows(choice.items,choice.selected,5,h-4,function(r) return r.label end,function(i,again)
        choice.selected=i; if again then choice.callback(choice.items[i]) end
      end)
      local x=ui.button(1,h-1,'Select',function() choice.callback(assert(choice.items[choice.selected],'No selection')) end,#choice.items>0)
      ui.button(x,h-1,'Back',choice.back)
    elseif state.mode=='confirm' then
      ui.text(1,4,state.confirm.text)
      local x=ui.button(1,7,'Confirm',function() state.confirm.yes() end)
      ui.button(x,7,'Cancel',function() state.confirm.no() end)
    elseif state.mode=='recovery' then
      ui.text(1,3,'An interrupted save needs attention. Other edits are locked.',0xffcc66)
      ui.text(1,5,'Finish applies the saved draft and returns the pattern.')
      ui.text(1,6,'Restore original reverses edits and returns the pattern.')
      ui.text(1,8,'Keep the original interfaces, adapters and chunks available.')
      local x=ui.button(1,11,'Finish',function() resume('finish') end,tx~=nil)
      x=ui.button(x,11,'Restore original',function() resume('restore') end,tx~=nil)
      ui.button(x,11,'Quit',function() running=false end)
    elseif state.mode=='help' then
      ui.lines(help,state.page,3,h-5)
      ui.button(1,h-1,'Back',function() mode('main') end)
    elseif state.mode=='error' then
      ui.text(1,3,'Operation stopped',0xff7777)
      local lines={}
      local step=math.max(1,w-1)
      for i=1,unicode.len(state.error),step do lines[#lines+1]=unicode.sub(state.error,i,i+step-1) end
      ui.lines(lines,1,5,h-8)
      ui.button(1,h-1,'Back',function()
        if recovery() then mode('recovery') else mode(state.returnMode or 'main') end
      end)
    end
  end
  local function navigation(code,delta)
    if state.mode=='main' then state.selected=math.max(1,math.min(#state.results,state.selected+delta))
    elseif state.mode=='edit' then state.entry=math.max(1,math.min(#state.draft[state.side],state.entry+delta))
    elseif state.mode=='picker' then state.picker.selected=math.max(1,math.min(#pickerResults(),state.picker.selected+delta))
    elseif state.mode=='choose' then state.choice.selected=math.max(1,math.min(#state.choice.items,state.choice.selected+delta))
    elseif state.mode=='preview' then state.page=math.max(1,math.min(#state.diff,state.page+delta))
    elseif state.mode=='help' then state.page=math.max(1,math.min(#help,state.page+delta)) end
  end
  local function key(e)
    if e[1]=='scroll' then navigation(nil,-e[5]); return end
    if e[1]~='key_down' then return end
    local code=e[4]
    if code==keys.up then navigation(code,-1)
    elseif code==keys.down then navigation(code,1)
    elseif code==keys.pageUp then navigation(code,-math.max(1,ui.h-10))
    elseif code==keys.pageDown then navigation(code,math.max(1,ui.h-10))
    elseif code==keys.enter then
      if state.mode=='main' and #state.results>0 then open()
      elseif state.mode=='edit' and editable() then quantity()
      elseif state.mode=='picker' then pickDone()
      elseif state.mode=='choose' then local c=state.choice; c.callback(assert(c.items[c.selected],'No selection')) end
    elseif code==keys.delete and state.mode=='edit' and editable() then remove()
    elseif code==keys.escape then
      if state.mode=='edit' then backEdit()
      elseif state.mode=='picker' or state.mode=='amount' or state.mode=='preview' then mode('edit')
      elseif state.mode=='help' then mode('main')
      elseif state.mode=='confirm' then state.confirm.no()
      elseif state.mode=='choose' then state.choice.back() end
    end
  end
  local ok,err=xpcall(function()
    if options.demo or config then
      local connected,message=pcall(connect)
      if not connected then status('Connection failed: '..tostring(message)..'. Use Setup.') end
    end
    if recovery() then mode('recovery') end
    while running do
      draw()
      if options.onDraw then options.onDraw(state,ui) end
      local e=ui.pull()
      local handled,message=pcall(function() if not ui.dispatch(e) then key(e) end end)
      if not handled then errorBox(message) end
    end
  end,debug.traceback)
  gpu.setResolution(oldW,oldH); gpu.setBackground(0); gpu.setForeground(0xffffff)
  gpu.fill(1,1,oldW,oldH,' ')
  if not ok then error(err,0) end
  return state
end
return M
