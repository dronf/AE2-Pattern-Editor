-- Run by check_release.py with the real generated application as APP.
local original={open=io.open,internet=package.loaded.internet,
  filesystem=package.loaded.filesystem,shell=package.loaded.shell}
local function test(body,failRename,expectSuccess)
  local files={['/home/pattern_editor.lua']='old application',
    ['/home/.ae2-pattern-editor/settings']='keep settings',
    ['/home/.ae2-pattern-editor/transaction']='keep recovery'}
  local fs={concat=function(a,b) return a..'/'..b end}
  function fs.exists(p) return files[p]~=nil end
  function fs.remove(p) files[p]=nil; return true end
  function fs.rename(a,b)
    if failRename and a:find('.download',1,true) then return nil,'Injected install failure' end
    if not files[a] or files[b] then return nil,'Bad rename' end
    files[b]=files[a]; files[a]=nil; return true
  end
  package.loaded.filesystem=fs
  package.loaded.shell={getWorkingDirectory=function() return '/home' end}
  package.loaded.internet={request=function()
    local pos=1
    return function()
      if pos>#body then return nil end
      local s=body:sub(pos,pos+1023); pos=pos+#s; return s
    end
  end}
  io.open=function(path)
    local data=''
    return {write=function(_,s) data=data..s; return true end,
      flush=function() files[path]=data; return true end,
      close=function() return nil end}
  end
  local ok=pcall(assert(loadfile('installer.lua')))
  assert(ok==expectSuccess,'Unexpected installer result')
  assert(files['/home/pattern_editor.lua']==(expectSuccess and APP or 'old application'))
  assert(files['/home/.ae2-pattern-editor/settings']=='keep settings')
  assert(files['/home/.ae2-pattern-editor/transaction']=='keep recovery')
  if expectSuccess then assert(files['/home/pattern_editor.lua.previous']=='old application') end
end
local ok,err=pcall(function()
  test(APP,false,true)
  test(APP..'truncated?',false,false)
  test(APP:sub(1,-2),false,false)
  test('x'..APP:sub(2),false,false)
  test(APP,true,false)
end)
io.open=original.open
for _,k in ipairs({'internet','filesystem','shell'}) do package.loaded[k]=original[k] end
assert(ok,err)
print('PASS: pinned installer, chunked download, checksum/size rejection, nil close, rollback and user-data preservation')
