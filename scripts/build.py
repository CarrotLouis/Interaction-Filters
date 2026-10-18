"""Required gates -> manager envelope -> byte-for-byte inspection. Never deploys."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import shutil
import struct
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from assemble import assemble,RESOURCE
from release_policy import read_policy,require_packaging

def run():
    p=argparse.ArgumentParser()
    p.add_argument('--output-dir',type=Path,default=ROOT/'outputs')
    p.add_argument('--verify-only',action='store_true',help='run offline gates without creating a distributable; withdrawn builds stay withdrawn')
    args=p.parse_args()
    try:
        policy=read_policy()
        if not args.verify_only:require_packaging()
    except (OSError,ValueError)as exc:p.error(str(exc))
    output=args.output_dir.resolve()
    source=assemble().encode('utf-8')
    subprocess.run([sys.executable,str(ROOT/'scripts/build_mod.py'),'--validate-only'],check=True)
    from run_tests import run_tests
    tests=run_tests()
    assert tests['source_sha256']==hashlib.sha256(source).hexdigest()
    if args.verify_only:
        print(json.dumps({'ok':True,'offline_gates_passed':True,'release_policy':policy,
                          'packaged':False,'game_or_manager_deployed':False},indent=2))
        return None
    output.mkdir(parents=True,exist_ok=True)
    version=re.search(rb"local version='([0-9.]+)'",source)[1].decode()
    staging=ROOT/'build/package';staging.mkdir(exist_ok=True)
    subprocess.run([sys.executable,str(ROOT/'scripts/build_mod.py'),'--output-dir',str(staging)],check=True)
    raw=staging/f'Interaction-Filters-{version}.zip'
    candidate=staging/f'Interaction-Filters-{version}-cache-primary-test.zip'
    with zipfile.ZipFile(raw)as z:
        files={name:z.read(name) for name in z.namelist()}
    manifest=json.loads(files['manifest.json'])
    manifest['Name']=f'Interaction Filters {version} - PRIMARY FILTER TEST'
    description=('Requires Bingus Shared Loader v18+ and Mod Options Menu v1.1+. '
                 'PRIMARY-ONLY DATA-CACHE TEST. Local manual primary pickup filtering; default ON, saved OFF honored. Five optional filters remain unavailable. Steam build 25480438 only. '
                 'Offline-verified test candidate; in-game acceptance pending.')
    manifest['Description']=description
    manifest['Options'][0]['Name']='Interaction Filters'
    manifest['Options'][0]['Description']=description
    files['manifest.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    files['LICENSE.txt']=(ROOT/'LICENSE').read_bytes()
    files['THIRD_PARTY_NOTICES.txt']=(ROOT/'THIRD_PARTY_NOTICES.md').read_bytes()
    files['VALIDATION.txt']=(ROOT/'docs/VALIDATION.md').read_bytes()
    forbidden=('.bat','.cmd','.ps1','.vbs','.js','.exe','.dll')
    assert not any(name.lower().endswith(forbidden) for name in files)
    with zipfile.ZipFile(candidate,'w',zipfile.ZIP_DEFLATED)as z:
        for name,body in sorted(files.items()):
            info=zipfile.ZipInfo(name,date_time=(1980,1,1,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16
            z.writestr(info,body)
    # The separate official tool is a build input, not redistributed in the source.
    import os
    tools_path=Path(os.environ.get('PPB_BINGUS_TOOLS',str(ROOT/'external/BingusSharedLoader/scripts')))
    sys.path.insert(0,str(tools_path))
    from archive import read_resource,resource_hash,ARCHIVE
    with zipfile.ZipFile(candidate)as z:
        assert z.testzip()is None
        for name,body in files.items():assert z.read(name)==body
        payload=read_resource(z.read('Addon/'+ARCHIVE),resource_hash(RESOURCE))
        size,kind=struct.unpack_from('<II',payload)
        assert kind==2 and size==len(source) and payload[8:]==source
        assert z.read('Addon/'+ARCHIVE+'.stream')==b''
        assert z.read('Addon/'+ARCHIVE+'.gpu_resources')==b''
    inspection=subprocess.check_output([sys.executable,str(ROOT/'scripts/inspect_package.py'),str(candidate),
        '--resource',RESOURCE,'--source',str(ROOT/'build/addon.lua'),'--json'],text=True,encoding='utf-8')
    (ROOT/'build/package-inspection.json').write_text(inspection,encoding='utf-8')
    final=output/candidate.name
    if final.exists()and final.read_bytes()!=candidate.read_bytes():
        raise RuntimeError('preserve an existing deliverable; use a new output directory/version')
    shutil.copyfile(candidate,final)
    report={'version':version,'build_id':policy['build_id'],'runtime_profile':'local_retained_cache','resource':RESOURCE,
        'guid':manifest['Guid'],'candidate_file':final.name,'bytes':final.stat().st_size,
        'sha256':hashlib.sha256(final.read_bytes()).hexdigest(),
        'source_sha256':tests['source_sha256'],'native_sha256':None,'active_native_bytes':0,
        'package_inspected':True,'exact_source_equality':True,
        'in_game_tested':False,'manager_import_tested':False,'host_client_tested':False,
        'game_or_manager_deployed':False}
    (ROOT/'build/package-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))
    return final

if __name__=='__main__':run()
