local C=require('ape.codec')
local M={}
function M.new(dir, fs)
  fs=fs or require('filesystem')
  if not fs.exists(dir) then assert(fs.makeDirectory(dir), 'Cannot create data directory') end
  local obj={dir=dir}
  function obj.load(name)
    local path=dir..'/'..name
    if not fs.exists(path) then
      if fs.exists(path..'.bak') then path=path..'.bak' else return nil end
    end
    local f=assert(io.open(path,'rb')); local body=f:read('*a'); f:close()
    local header,payload=body:match('^APE1 ([0-9a-f]+)\n(.*)$')
    assert(header and C.adler(payload)==header, 'Corrupt '..name..'; preserve it and inspect the .bak file')
    return C.decode(payload)
  end
  function obj.save(name,v)
    local path=dir..'/'..name
    local payload=C.encode(v)
    local f=assert(io.open(path..'.tmp','wb'))
    local ok,err=pcall(function()
      assert(f:write('APE1 '..C.adler(payload)..'\n'..payload))
      assert(f:flush())
    end)
    -- OpenOS filesystem streams may return nil with NO error on a successful close.
    local closed,reason=f:close()
    assert(ok,err)
    assert(closed~=false and not (closed==nil and reason~=nil),reason or 'Close failed')
    if fs.exists(path..'.bak') then assert(fs.remove(path..'.bak')) end
    if fs.exists(path) then assert(fs.rename(path,path..'.bak')) end
    assert(fs.rename(path..'.tmp',path))
  end
  function obj.pending()
    -- A missing primary with a backup is an interrupted replacement, not an empty journal.
    if not fs.exists(dir..'/transaction') and fs.exists(dir..'/transaction.bak') then
      return obj.load('transaction.bak')
    end
    return obj.load('transaction')
  end
  function obj.finish(j)
    j.state='done'; obj.save('transaction',j)
  end
  return obj
end
return M
