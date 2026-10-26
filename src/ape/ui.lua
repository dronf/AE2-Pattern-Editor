local M={}
function M.new(gpu,event,keyboard,unicode)
  local ui={gpu=gpu,hits={},fields={},buttons={}}
  local keys=keyboard.keys
  local focus
  local buttonIndex=0
  local function len(s) return unicode.len(s) end
  local function sub(s,a,b)
    local count=len(s)
    if a>count or (b and b<a) then return '' end
    return unicode.sub(s,a,b and math.min(b,count) or nil)
  end
  local function width(s) return unicode.wlen and unicode.wlen(s) or len(s) end
  local function clip(s,n)
    s=tostring(s):gsub('[\r\n\t]',' ')
    if n<=0 then return '' end
    if width(s)<=n then return s end
    -- OpenOS unicode.wtrunc can index one past the string at the screen edge.
    -- Find the longest prefix that fits without asking unicode.sub past len(s).
    local low,high=0,len(s)
    while low<high do
      local middle=math.floor((low+high+1)/2)
      if width(sub(s,1,middle))<=n then low=middle else high=middle-1 end
    end
    return sub(s,1,low)
  end
  function ui.text(x,y,s,color,bg,n)
    if y<1 or y>ui.h or x>ui.w then return end
    assert(x>=1, 'Invalid drawing position')
    gpu.setForeground(color or 0xeeeeee); gpu.setBackground(bg or 0x10151c)
    gpu.set(x,y,clip(s,math.min(n or ui.w,ui.w-x+1)))
  end
  function ui.frame(title,status)
    ui.w,ui.h=gpu.getResolution()
    ui.hits={}; ui.fields={}; ui.buttons={}
    gpu.setBackground(0x10151c); gpu.setForeground(0xeeeeee)
    gpu.fill(1,1,ui.w,ui.h,' ')
    ui.text(1,1,title,0x66ddff)
    ui.text(1,ui.h,status or '',0xffd166)
  end
  function ui.button(x,y,label,fn,enabled)
    local text='['..label..']'; local w=math.min(width(text),ui.w-x+1)
    if w<=0 or y<1 or y>ui.h then return x end
    local selected=enabled~=false and buttonIndex==#ui.buttons+1
    ui.text(x,y,text,enabled==false and 0x666666 or selected and 0xffd166 or 0xffffff,
      enabled==false and 0x20252a or selected and 0x365f80 or 0x30455c,w)
    if enabled~=false then
      ui.buttons[#ui.buttons+1]=fn
      ui.hits[#ui.hits+1]={x=x,y=y,w=w,fn=fn}
    end
    return x+w+1
  end
  function ui.field(x,y,w,state,onSubmit)
    state.text=state.text or ''; state.pos=math.min(state.pos or len(state.text),len(state.text))
    w=math.min(w,ui.w-x+1)
    local item={x=x,y=y,w=w,state=state,submit=onSubmit}
    ui.fields[#ui.fields+1]=item
    local start=math.max(1,state.pos-w+3)
    state.start=start
    ui.text(x,y,string.rep(' ',w),nil,0x24313e,w)
    ui.text(x,y,sub(state.text,start),focus==state and 0xffffff or 0xbbcccc,0x24313e,w)
    if focus==state then
      local cx=x+width(sub(state.text,start,state.pos))
      if cx<x+w then
        local ch=sub(state.text,state.pos+1,state.pos+1)
        ui.text(cx,y,ch~='' and ch or '_',0x10151c,state.all and 0xffd166 or 0x66ddff,1)
      end
    end
    ui.hits[#ui.hits+1]={x=x,y=y,w=w,field=item,fn=function() focus=state end}
  end
  function ui.focus(state,all) focus=state; buttonIndex=0; if state then state.all=all or false end end
  function ui.blur() focus=nil; buttonIndex=0 end
  function ui.row(x,y,w,text,selected,fn)
    ui.text(x,y,string.rep(' ',w),nil,selected and 0x254c66 or 0x10151c,w)
    ui.text(x,y,text,selected and 0x66eeff or 0xeeeeee,selected and 0x254c66 or 0x10151c,w)
    ui.hits[#ui.hits+1]={x=x,y=y,w=w,fn=fn}
  end
  function ui.lines(lines,start,y,count)
    for i=start,math.min(#lines,start+count-1) do ui.text(1,y+i-start,lines[i]) end
  end
  local function insert(s)
    if focus.all then focus.text=''; focus.pos=0; focus.all=false end
    s=s:gsub('[\r\n\t]',' ')
    if len(focus.text)+len(s)>(focus.limit or 256) then return end
    focus.text=sub(focus.text,1,focus.pos)..s..sub(focus.text,focus.pos+1)
    focus.pos=focus.pos+len(s)
  end
  function ui.dispatch(e)
    local name=e[1]
    if name=='touch' then
      local x,y=e[3],e[4]
      buttonIndex=0
      for i=#ui.hits,1,-1 do
        local hit=ui.hits[i]
        if y==hit.y and x>=hit.x and x<hit.x+hit.w then
          if hit.field then
            local s=hit.field.state
            focus=s; s.all=false
            local wanted=x-hit.x
            local p=s.start-1
            while p<len(s.text) and width(sub(s.text,s.start,p+1))<=wanted do p=p+1 end
            s.pos=p
          else focus=nil; hit.fn() end
          return true
        end
      end
      focus=nil; return true
    end
    if name=='clipboard' and focus then insert(e[3] or ''); return true end
    if name=='key_down' and e[4]==keys.tab then
      if focus then
        local index=0
        for i,f in ipairs(ui.fields) do if f.state==focus then index=i end end
        if index<#ui.fields then focus=ui.fields[index+1].state; focus.all=true
        else focus=nil; buttonIndex=#ui.buttons>0 and 1 or 0 end
      elseif buttonIndex<#ui.buttons then buttonIndex=buttonIndex+1
      else
        buttonIndex=0
        if #ui.fields>0 then focus=ui.fields[1].state; focus.all=true end
      end
      return true
    end
    if name=='key_down' and not focus then
      local code=e[4]
      if (code==keys.enter or code==keys.numpadenter) and ui.buttons[buttonIndex] then
        local fn=ui.buttons[buttonIndex]; buttonIndex=0; fn(); return true
      end
      if code==keys.up or code==keys.down or code==keys.pageUp or code==keys.pageDown then
        buttonIndex=0
      end
    end
    if name=='key_down' and focus then
      local ch,code=e[3],e[4]
      local ctrl=keyboard.isControlDown and keyboard.isControlDown()
      if ctrl and (ch==1 or ch==97 or code==keys.a) then focus.all=true; return true end
      if code==keys.enter or code==keys.numpadenter then
        local old=focus; focus=nil
        for _,f in ipairs(ui.fields) do if f.state==old and f.submit then f.submit() end end
      elseif code==keys.escape then focus=nil
      elseif code==keys.home then focus.pos=0; focus.all=false
      elseif code==keys['end'] then focus.pos=len(focus.text); focus.all=false
      elseif code==keys.left then focus.pos=math.max(0,focus.pos-1); focus.all=false
      elseif code==keys.right then focus.pos=math.min(len(focus.text),focus.pos+1); focus.all=false
      elseif code==keys.back or code==keys.delete then
        if focus.all then focus.text=''; focus.pos=0; focus.all=false
        elseif code==keys.back and focus.pos>0 then
          focus.text=sub(focus.text,1,focus.pos-1)..sub(focus.text,focus.pos+1); focus.pos=focus.pos-1
        elseif code==keys.delete then focus.text=sub(focus.text,1,focus.pos)..sub(focus.text,focus.pos+2) end
      elseif not ctrl and ch and ch>=32 then insert(unicode.char(ch)) end
      return true
    end
    return false
  end
  function ui.pull() return {event.pull()} end
  function ui.page(index,count,y,bottom)
    local rows=math.max(1,bottom-y+1)
    local start=math.floor((math.max(1,index)-1)/rows)*rows+1
    return start,math.min(count,start+rows-1),rows
  end
  return ui
end
return M
