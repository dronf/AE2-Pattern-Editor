"""Build a self-contained OpenOS Lua application and a pinned installer."""
from pathlib import Path
import hashlib, json, re, zipfile, zlib

root=Path(__file__).resolve().parents[1]
version=re.search(r"VERSION='([^']+)'",(root/'src/ape/app.lua').read_text()).group(1)
tag='v'+version
out=root/'dist'
out.mkdir(exist_ok=True)
parts=['-- AE2 Pattern Editor '+version+' | MIT | https://github.com/dronf/AE2-Pattern-Editor\n']
for path in sorted((root/'src').rglob('*.lua')):
    module=path.relative_to(root/'src').with_suffix('').as_posix().replace('/','.')
    parts.append('package.loaded['+json.dumps(module)+'] = nil\npackage.preload['+json.dumps(module)+'] = function(...)\n'+path.read_text(encoding='utf-8')+'\nend\n')
parts.append((root/'main.lua').read_text(encoding='utf-8'))
bundle='\n'.join(parts).encode('utf-8')
(out/'pattern_editor.lua').write_bytes(bundle)
adler=f'{zlib.adler32(bundle)&0xffffffff:08x}'
installer=(root/'tools/installer.lua.in').read_text(encoding='utf-8').replace('@VERSION@',version).replace('@ADLER@',adler).replace('@SIZE@',str(len(bundle)))
(root/'installer.lua').write_text(installer,encoding='utf-8',newline='\n')
(out/'installer.lua').write_text(installer,encoding='utf-8',newline='\n')
for kind,paths in [('oc',['pattern_editor.lua','installer.lua']),('source',[])]:
    target=out/f'ae2-pattern-editor-{version}-{kind}.zip'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        if kind=='oc':
            for name in paths: z.write(out/name,name)
            for name in ['README.md','LICENSE','docs/INSTALLATION.md','docs/USAGE.md','docs/RECOVERY.md','docs/VERIFICATION.md']:
                z.write(root/name,name)
        else:
            for path in sorted(root.rglob('*')):
                rel=path.relative_to(root)
                if not path.is_file() or any(p in ['.git','dist','__pycache__','tmp'] for p in rel.parts): continue
                if path.suffix=='.pyc' or (rel.parent.as_posix()=='tests' and path.name.startswith('screen-')): continue
                z.write(path,'AE2-Pattern-Editor-'+version+'/'+rel.as_posix())
assets=[out/'pattern_editor.lua',out/'installer.lua',*sorted(out.glob(f'ae2-pattern-editor-{version}-*.zip'))]
checksums=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in assets)
(out/'SHA256SUMS.txt').write_text(checksums,encoding='ascii')
print(f'Built {version}: {len(bundle):,} byte single-file application; Adler-32 {adler}')
print(checksums)
