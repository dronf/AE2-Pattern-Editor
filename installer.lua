-- Generated pinned installer for AE2 Pattern Editor 1.0.5.
local internet=require('internet')
local filesystem=require('filesystem')
local shell=require('shell')
local target=filesystem.concat(shell.getWorkingDirectory(),'pattern_editor.lua')
local temp=target..'.download'
local url='https://github.com/dronf/AE2-Pattern-Editor/releases/download/v1.0.5/pattern_editor.lua'
local function adler(s)
  local a,b=1,0
  for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
  return string.format('%08x',b*65536+a)
end
local function close(f)
  local result,err=f:close()
  assert(result~=false and not (result==nil and err~=nil),err or 'Close failed')
end
print('Downloading AE2 Pattern Editor 1.0.5...')
local ok,err=pcall(function()
  local chunks,size={},0
  for chunk in internet.request(url) do
    size=size+#chunk; assert(size<=54326,'Unexpected download size')
    chunks[#chunks+1]=chunk
  end
  local body=table.concat(chunks)
  assert(#body==54326 and adler(body)=='a2d3bc5a','Download verification failed; old installation retained')
  assert(load(body,'=pattern_editor','t',{}),'Downloaded Lua did not compile')
  local f=assert(io.open(temp,'wb'))
  local wrote,reason=pcall(function() assert(f:write(body)); assert(f:flush()) end)
  close(f); assert(wrote,reason)
  if filesystem.exists(target..'.previous') then assert(filesystem.remove(target..'.previous')) end
  if filesystem.exists(target) then assert(filesystem.rename(target,target..'.previous')) end
  local moved,why=filesystem.rename(temp,target)
  if not moved then
    if filesystem.exists(target..'.previous') and not filesystem.exists(target) then filesystem.rename(target..'.previous',target) end
    error(why or 'Could not install downloaded file')
  end
end)
if not ok then error('Install stopped: '..tostring(err),0) end
print('Installed pattern_editor.lua 1.0.5. Settings/journal were preserved.')
print('Run: pattern_editor --demo   (simulation), or: pattern_editor   (real setup)')
