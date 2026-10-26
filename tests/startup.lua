-- Exercise the shipped entry point with the OpenOS APIs present in GTNH.
-- In particular, shell.getRunningProgram does not exist there.
package.loaded.shell=nil
package.preload.shell=function() error('Bundled app must not load shell') end
package.preload.filesystem=function()
  return {
    path=function() error('Bundled app must not inspect its source path') end,
    exists=function() return false end,
    makeDirectory=function() return true end,
  }
end

local draws=0
local gpu={}
function gpu.getResolution() return 80,25 end
function gpu.maxResolution() return 80,25 end
function gpu.setResolution() end
function gpu.setBackground() end
function gpu.setForeground() end
function gpu.set() end
function gpu.fill() draws=draws+1 end

package.preload.component=function() return {gpu=gpu} end
package.preload.event=function()
  return {pull=function() return 'touch','screen',24,2,0,'player' end}
end
package.preload.keyboard=function() return {keys={}} end
package.preload.unicode=function()
  return {
    len=string.len,
    wlen=string.len,
    sub=string.sub,
    wtrunc=function() error('OpenOS unicode.wtrunc must not be used for clipping') end,
  }
end

local help=assert(load(APP,'=pattern_editor')); help('--help')
local real=assert(load(APP,'=pattern_editor')); real()
local demo=assert(load(APP,'=pattern_editor')); demo('--demo')
assert(draws>=4,'Real and demo startup should each draw and exit normally')
print('PASS: installed entry point starts in real and demo modes without shell.getRunningProgram')
