"""Inspect actual OC/AE2 JAR bytecode without starting Minecraft. JDK 17 required."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, zipfile
p=argparse.ArgumentParser()
p.add_argument('--mods',type=Path,required=True)
p.add_argument('--javap',default='javap')
p.add_argument('--output',type=Path)
a=p.parse_args()
oc=a.mods/'OpenComputers-1.12.64-GTNH.jar'
ae=a.mods/'appliedenergistics2-rv3-beta-1080-GTNH.jar'
required={
 'li.cil.oc.integration.appeng.DriverBlockInterface$Environment':[
 'getInterfacePattern','setInterfacePatternInput','setInterfacePatternOutput',
 'getItemsInNetwork','getFluidsInNetwork'],
 'li.cil.oc.integration.appeng.DriverPartInterfaceTerminal$Environment':[
 'getInterfaces','getInterfacesByLocation','send'],
 'li.cil.oc.integration.appeng.internal.PatternEnvironment$class':[
 'getPatternNBT','setPatternSlot'],
 'li.cil.oc.integration.appeng.ConverterPattern$':['convert'],
 'li.cil.oc.integration.vanilla.ConverterItemStack$':['convert','parse'],
}
records={}
for cls,methods in required.items():
    text=subprocess.check_output([a.javap,'-classpath',str(oc),'-c','-v','-p',cls],text=True)
    for method in methods:
        assert re.search(r'\b'+method+r'\(',text),f'Missing API {cls}.{method}'
    with zipfile.ZipFile(oc) as z:
        code=z.read(cls.replace('.','/')+'.class')
    records[cls]={'sha256':hashlib.sha256(code).hexdigest(),'methods':methods}
    if 'PatternEnvironment$class' in cls:
        assert 'sipush        511' in text or re.search(r'sipush\s+511',text)
        assert 'NBTTagList.func_74744_a' in text or 'removeTag' in text or 'func_74744_a' in text
    if 'ConverterPattern$' in cls:
        assert 'inputs' in text and 'outputs' in text and 'isCraftable' in text
for cls,kind in [('appeng.util.item.AEItemStackType','item'),('appeng.util.item.AEFluidStackType','fluid')]:
    text=subprocess.check_output([a.javap,'-classpath',str(ae),'-c','-p',cls],text=True)
    assert '// String '+kind in text
result={'oc':oc.name,'ae2':ae.name,'jarSha256':{x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in [oc,ae]},
        'inspectedClasses':records,'scope':'Static bytecode/API inspection; not an in-game execution test.'}
if a.output:
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('PASS: required callbacks, pattern conversion, entry limit and item/fluid type IDs in installed GTNH JARs')
