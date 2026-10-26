local C=require('ape.codec')
local M={}
function M.run(check,fails,memoryStore)
  local function chars(s)
    local out={}
    for c in s:gmatch('[%z\1-\127\194-\244][\128-\191]*') do out[#out+1]=c end
    return out
  end
  local unicode={}
  function unicode.len(s) return #chars(s) end
  function unicode.sub(s,a,b)
    local t=chars(s); local n=#t
    a=a or 1; b=b or n
    if a<0 then a=n+a+1 end; if b<0 then b=n+b+1 end
    local out={}; for i=math.max(1,a),math.min(n,b) do out[#out+1]=t[i] end
    return table.concat(out)
  end
  unicode.wlen=unicode.len
  function unicode.wtrunc() error('OpenOS unicode.wtrunc must not be used for clipping') end
  function unicode.char(n)
    if n<128 then return string.char(n) end
    return string.char(192+math.floor(n/64),128+n%64)
  end
  local keys={a=30,c=46,d=32,q=16,enter=28,numpadenter=156,escape=1,tab=15,home=199,['end']=207,
    left=203,right=205,back=14,delete=211,up=200,down=208,pageUp=201,pageDown=209}
  local ctrl=false
  local keyboard={keys=keys,isControlDown=function() return ctrl end}
  local function screen(w,h)
    local gpu={w=w,h=h,buffer={},fg=0xffffff,bg=0}
    function gpu.getResolution() return gpu.w,gpu.h end
    function gpu.maxResolution() return w,h end
    function gpu.setResolution(a,b) gpu.w=a; gpu.h=b; gpu.buffer={} end
    function gpu.setForeground(v) gpu.fg=v end
    function gpu.setBackground(v) gpu.bg=v end
    function gpu.set(x,y,s)
      check(x>=1 and y>=1 and y<=gpu.h and x+unicode.len(s)-1<=gpu.w,'Draw outside screen')
      gpu.buffer[y]=gpu.buffer[y] or {}
      for i,c in ipairs(chars(s)) do gpu.buffer[y][x+i-1]=c end
    end
    function gpu.fill(x,y,a,b,c)
      check(x>=1 and y>=1 and x+a-1<=gpu.w and y+b-1<=gpu.h,'Fill outside screen')
      for row=y,y+b-1 do for col=x,x+a-1 do
        gpu.buffer[row]=gpu.buffer[row] or {}; gpu.buffer[row][col]=c
      end end
    end
    function gpu.dump()
      local lines={}
      for y=1,gpu.h do local row={}; for x=1,gpu.w do row[x]=(gpu.buffer[y] or {})[x] or ' ' end; lines[y]=table.concat(row) end
      return table.concat(lines,'\n')
    end
    return gpu
  end
  local gpu=screen(50,16)
  local ui=require('ape.ui').new(gpu,{},keyboard,unicode)
  ui.frame('AE2 Pattern Editor '..require('ape.app').VERSION..' [DEMO - no real AE access]')
  check(unicode.len(gpu.dump():match('^[^\n]+'))==50,'Long title must fit a 50-column screen')
  local field={text='1234'}
  ui.frame('Input regression')
  ui.field(1,4,20,field)
  ui.focus(field,true)
  local function key(ch,code) ui.dispatch({'key_down','keyboard',ch,code or 2}) end
  key(53,6); key(54,7)
  check(field.text=='56','Top-row number keys must type once')
  key(0,keys.back); check(field.text=='5')
  key(55,71); check(field.text=='57','Numpad input must type once')
  key(0,keys.home); key(0,keys.delete); check(field.text=='7')
  key(0,keys['end']); key(56,9); check(field.text=='78')
  ctrl=true; key(1,keys.a); ctrl=false
  ui.dispatch({'clipboard','keyboard','2048'})
  check(field.text=='2048')
  key(0,keys.left); key(0,keys.back); check(field.text=='208')
  ctrl=true; key(1,keys.a); ctrl=false; key(0,keys.delete)
  check(field.text=='')
  ui.dispatch({'key_down','keyboard',233,18}); check(field.text=='\195\169')
  -- Buttons can be selected and activated without a touchscreen. Tab cycles
  -- the enabled buttons and then returns to the first text field.
  local activated={}
  ui.frame('Keyboard controls')
  ui.button(1,2,'First',function() activated[#activated+1]='first' end)
  ui.button(10,2,'Disabled',function() activated[#activated+1]='disabled' end,false)
  ui.button(22,2,'Second',function() activated[#activated+1]='second' end)
  local textField={text=''}
  ui.field(1,4,20,textField)
  ui.blur()
  key(0,keys.tab); key(0,keys.tab); key(0,keys.enter)
  check(#activated==1 and activated[1]=='second','Tab/Enter activates the selected enabled button')
  key(0,keys.tab); key(0,keys.tab); key(0,keys.tab)
  key(65,30)
  check(textField.text=='A','Tab reaches the text field after the buttons')
  -- Actual app: scan, find pattern, edit quantity, remove an ingredient, add via picker,
  -- multiply/divide, preview, apply, and verify physical return. Run at all OC screen tiers.
  for _,size in ipairs({{50,16},{80,25},{160,50}}) do
    gpu=screen(size[1],size[2]); local h=size[2]
    local d=require('ape.demo').new()
    local phase=0; local nextEvent; local seen={}
    local function touch(x,y) return {'touch','screen',x,y,0,'player'} end
    local function kd(code,ch) return {'key_down','keyboard',ch or 0,code} end
    local actions={
      {'main',function() return touch(2,2) end},
      {'main',function(s)
        local index
        for i,r in ipairs(s.results) do if r.name=='Assembly Line' and r.endpoint.slot==0 then index=i end end
        check(index~=nil); return touch(2,6+index-1)
      end},
      {'main',function() return kd(keys.enter) end},
      {'edit',function() return touch(18,h-4) end},
      {'amount',function() return kd(2,49) end},
      {'amount',function() return kd(7,54) end},
      {'amount',function(s) check(s.amount.text=='16'); return kd(keys.enter) end},
      {'edit',function(s) check(s.draft.inputs[1].size==16); return kd(keys.down) end},
      {'edit',function(s) check(s.entry==2); return kd(keys.delete) end},
      {'confirm',function() return touch(2,7) end},
      {'edit',function(s) check(#s.draft.inputs==1); return touch(2,h-4) end},
      {'picker',function() return {'clipboard','keyboard','Iron Ingot'} end},
      {'picker',function() return kd(keys.enter) end},
      {'picker',function() return kd(keys.enter) end},
      {'amount',function() return kd(5,52) end},
      {'amount',function() return kd(keys.enter) end},
      {'edit',function(s) check(s.draft.inputs[2].size==4); return touch(7,h-2) end},
      {'edit',function(s) check(s.draft.outputs[1].size==4); return touch(2,h-2) end},
      {'edit',function(s) check(s.draft.outputs[1].size==2); return touch(12,h-2) end},
      {'preview',function(s) check(#s.diff>=3); return touch(2,h-2) end},
      {'main',function(s)
        local p=d.inventories[2].patterns[0]
        check(p.inputs[1].size==16 and p.inputs[2].name=='minecraft:iron_ingot' and p.inputs[2].size==4)
        check(d.inventories[1].patterns[0]==nil,'Physical staging slot must be empty after Apply')
        return touch(24,2)
      end}}
    local event={pull=function() local e=nextEvent; nextEvent=nil; assert(e,'No scripted event'); return table.unpack(e) end}
    require('ape.app').run({gpu=gpu,event=event,keyboard=keyboard,unicode=unicode,
      component={},store=memoryStore(),demo=d,onDraw=function(s)
        phase=phase+1
        local action=assert(actions[phase],'App journey did not quit')
        check(s.mode==action[1],'At phase '..phase..' expected '..action[1]..', got '..s.mode..': '..tostring(s.error))
        seen[s.mode]=true
        if size[1]==80 and (s.mode=='main' or s.mode=='edit' or s.mode=='preview') then
          local file=io.open('tests/screen-'..s.mode..'.txt','w')
          if file then file:write(gpu.dump()); file:close() end
        end
        nextEvent=action[2](s)
      end})
    check(phase==#actions and seen.picker and seen.preview and seen.confirm)
  end
  -- Main-screen keyboard operation and OpenOS interruption must exit cleanly.
  local function kd(code,ch) return {'key_down','keyboard',ch or 0,code} end
  local cases={
    {name='Tab Scan and Q',events={kd(keys.tab),kd(keys.enter),kd(keys.q,113)},scanned=true},
    {name='Tab to Quit',events={kd(keys.tab),kd(keys.tab),kd(keys.tab),kd(keys.enter)}},
    {name='Escape',events={kd(keys.escape)}},
    {name='Ctrl+C',events={kd(keys.c,3)},focused=true},
    {name='Ctrl+D',events={kd(keys.d,4)},focused=true},
    {name='Ctrl+C key state',events={kd(keys.c)},focused=true,control=true},
    {name='Ctrl+D key state',events={kd(keys.d)},focused=true,control=true},
    {name='OpenOS interrupted',events={{'interrupted',0}},focused=true},
  }
  for _,case in ipairs(cases) do
    local nextEvent,phase=nil,0
    local event={pull=function() local e=assert(nextEvent,'Missing '..case.name..' event'); nextEvent=nil; return table.unpack(e) end}
    local state=require('ape.app').run({gpu=screen(50,16),event=event,keyboard=keyboard,
      unicode=unicode,component={},store=memoryStore(),demo=require('ape.demo').new(),
      onDraw=function(s,appUi)
        phase=phase+1
        check(s.mode=='main' and s.error==nil,case.name..' should stay on the main screen')
        if case.scanned and phase==#case.events then check(#s.results>0,'Enter on Scan must load demo patterns') end
        if case.focused then appUi.focus(s.search) end
        ctrl=case.control or false
        nextEvent=assert(case.events[phase],'Extra draw in '..case.name)
      end})
    ctrl=false
    check(phase==#case.events and state.mode=='main',case.name..' must exit cleanly')
  end
  -- Public helpers for other regression suites.
  M.screen=screen; M.unicode=unicode; M.keyboard=keyboard
end
return M
