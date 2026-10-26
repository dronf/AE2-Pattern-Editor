local C=require('ape.codec')
local M={}
function M.run(check,fails)
  local oldOpen=io.open
  local files={}; local failure
  local fs={makeDirectory=function() return true end}
  function fs.exists(path) return files[path]~=nil end
  function fs.remove(path) files[path]=nil; return true end
  function fs.rename(a,b)
    if failure=='rename' and a:find('.tmp',1,true) then return nil,'Injected rename failure' end
    if not files[a] or files[b] then return nil,'Invalid rename' end
    files[b]=files[a]; files[a]=nil; return true
  end
  io.open=function(path,mode)
    if mode=='rb' then
      if not files[path] then return nil,'Not found' end
      return {read=function() return files[path] end,close=function() return nil end}
    end
    local data=''
    return {
      write=function(_,s) if failure=='write' then return nil,'Disk full' end; data=data..s; return true end,
      flush=function() if failure=='flush' then return nil,'Disk full' end; files[path]=data; return true end,
      close=function() return nil end}
  end
  local ok,err=pcall(function()
    local store=require('ape.store').new('/data',fs)
    local v={state='prepared',binary='\0\255\n',draft={inputs={{name='x',size=1}}}}
    store.save('transaction',v)
    check(C.equal(store.pending(),v),'Nil/no-error OpenOS close is valid')
    local v2=C.copy(v); v2.state='staged'; store.save('transaction',v2)
    check(C.equal(store.pending(),v2))
    check(C.equal(store.load('transaction.bak'),v))
    failure='rename'
    fails(function() store.save('transaction',{state='editing'}) end,'Injected rename')
    check(files['/data/transaction']==nil and files['/data/transaction.bak']~=nil)
    check(C.equal(store.pending(),v2),'Recover backup after interrupted atomic replacement')
    failure=nil
    store.save('transaction',v2)
    files['/data/transaction']=files['/data/transaction']..'corrupt'
    fails(function() store.pending() end,'Corrupt transaction')
    files['/data/transaction']=nil
    store.save('transaction',v)
    failure='write'; fails(function() store.save('transaction',v2) end,'Disk full')
    check(C.equal(store.pending(),v),'Failed write retains primary')
    failure='flush'; fails(function() store.save('transaction',v2) end,'Disk full')
    check(C.equal(store.pending(),v),'Failed flush retains primary')
  end)
  io.open=oldOpen
  assert(ok,err)
end
return M
