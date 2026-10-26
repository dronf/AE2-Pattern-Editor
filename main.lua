local args={...}
-- Bundled releases register ape modules in package.preload. Source checkouts
-- need the module path relative to the script OpenOS actually launched.
if not package.preload['ape.app'] then
  local program=assert(os.getenv('_'),'OpenOS did not provide the script path')
  local root=require('filesystem').path(program)
  package.path=root..'src/?.lua;'..package.path
end
local options={}
for _,arg in ipairs(args) do
  if arg=='--demo' then options.demo=require('ape.demo').new(); options.dir='/home/.ae2-pattern-editor-demo'
  elseif arg=='--help' then
    print('AE2 Pattern Editor: pattern_editor [--demo]')
    print('Run Setup to select an Interface Terminal and an empty adapter-connected ME Interface.')
    return
  else error('Unknown option: '..tostring(arg)) end
end
require('ape.app').run(options)
