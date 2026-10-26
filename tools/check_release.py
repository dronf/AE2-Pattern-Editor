"""Validate the built deliverables, run the bundle, and exercise the generated installer."""
from pathlib import Path
import argparse, hashlib, json, os, re, sys, zipfile
p=argparse.ArgumentParser()
p.add_argument('--deps',type=Path)
a=p.parse_args()
if a.deps: sys.path.insert(0,str(a.deps.resolve()))
root=Path(__file__).resolve().parents[1]
os.chdir(root)
bundle=(root/'dist/pattern_editor.lua').read_text(encoding='utf-8')
for line in (root/'dist/SHA256SUMS.txt').read_text().splitlines():
    sha,name=line.split('  ')
    assert hashlib.sha256((root/'dist'/name).read_bytes()).hexdigest()==sha,name
for path in (root/'dist').glob('*.zip'):
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        assert all(not n.startswith('/') and '..' not in Path(n).parts for n in z.namelist())
        if path.name.endswith('-oc.zip'):
            assert z.read('pattern_editor.lua')==(root/'dist/pattern_editor.lua').read_bytes()
links=0
for path in [root/'README.md',root/'CHANGELOG.md',*root.glob('docs/*.md')]:
    text=path.read_text(encoding='utf-8')
    for bad in ['\ufffd','\u00c2','\u00c3']:
        assert bad not in text,('Encoding',path)
    for target in re.findall(r'\]\(([^)]+)\)',text):
        if '://' not in target:
            assert (path.parent/target.split('#')[0]).exists(),(path,target)
            links+=1
json.loads((root/'docs/api-verification.json').read_text())
for version in ['lua52','lua53']:
    module=__import__('lupa.'+version,fromlist=['LuaRuntime'])
    lua=module.LuaRuntime()
    lua.execute("package.preload.shell=function() return {getRunningProgram=function() return '/home/pattern_editor.lua' end} end; package.preload.filesystem=function() return {path=function() return '/home/' end} end")
    lua.execute(bundle,'--help')
    # These require() calls resolve bundled package.preload modules, not source files.
    print('Testing built bundle under',version,flush=True)
    lua.execute((root/'tests/run.lua').read_text(encoding='utf-8'))
lua.globals().APP=bundle
lua.execute((root/'tests/installer.lua').read_text(encoding='utf-8'))
print(f'PASS: release SHA-256/ZIP contents, {links} documentation links, encoding, built bundle and installer')
