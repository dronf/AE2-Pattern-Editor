"""Run the real Lua modules under Lua 5.2 and 5.3 (pip install lupa)."""
from pathlib import Path
import argparse, os, sys
parser=argparse.ArgumentParser()
parser.add_argument('--deps',type=Path,help='Optional directory containing lupa')
args=parser.parse_args()
if args.deps:
    sys.path.insert(0,str(args.deps.resolve()))
os.chdir(Path(__file__).resolve().parents[1])
for version in ['lua52','lua53']:
    module=__import__('lupa.'+version,fromlist=['LuaRuntime'])
    lua=module.LuaRuntime()
    for path in sorted(Path('src').rglob('*.lua')):
        lua.execute('assert(load(...))',path.read_text(encoding='utf-8'))
    print('Testing',version,flush=True)
    lua.execute(Path('tests/run.lua').read_text(encoding='utf-8'))
