"""Gate the exact data-cache artifact and reviewed backend source hashes.

Reads only by default. A JSON report can be written explicitly under build/.
Independent native-consumer execution is an offline check, not live acceptance.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
BUILD_ID='0.3.0-cache-primary.1'
FORBIDDEN=('objects_owned_by','GameSession','origin_reader','support_origins',
           'ownership_queries','Network.game_session','Application.main_world','temp_byte_count',
           'VirtualAlloc','VirtualProtect','FlushInstructionCache','RtlAddFunctionTable',
           'RtlDeleteFunctionTable','near_allocator','native_blob','hook_factory','OpenProcess')
REVIEWED_FILES={'src/cache_backend.lua','src/data_writer.lua','src/controller.lua',
    'src/profile.lua','src/mission_guard.lua','src/entry.lua','scripts/assemble.py',
    'tests/fixtures/cache_layout.json','tests/fixtures/cache_consumers.json'}
def verify_review():
    review=json.loads((ROOT/'backend-review.json').read_text(encoding='utf-8'))
    if review.get('schema')!=1 or review.get('build_id')!=BUILD_ID:
        raise ValueError('backend review does not match this candidate')
    files=review.get('files',{})
    if set(files)!=REVIEWED_FILES:raise ValueError('backend review file set mismatch')
    for name,expected in files.items():
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=expected:
            raise ValueError('backend changed since review: '+name)
    if review.get('method')!='source audit plus independent native-consumer execution':
        raise ValueError('backend review method missing')
    return review

def check(source):
    for token in FORBIDDEN:
        assert token not in source,'isolation violation: '+token
    assert re.search(r"local version='0\.3\.0'",source)
    assert "local BUILD_ID='"+BUILD_ID+"'" in source
    assert "{key='primary'," in source
    for key in ('team_support','field_support','sample_bottle','sample','info'):
        assert "{key='"+key+"'," not in source,'optional filter registered: '+key
    assert 'source_observer=not_included' in source
    assert 'filtering_available=primary_manual' in source
    assert "controller.runtime_profile='local_retained_cache'" in source
    assert 'after=after' in source and 'scope();controller.filter_frame()' in source
    assert source.count('ifc3_WriteProcessMemory(')==2,'unexpected writer count'
    assert source.count('writer.replace(c.row,expected,desired,validate)')==1
    for cast in re.findall(r'\bffi\.cast\(\s*[\'"]([^\'"]+)',source):
        assert '(' not in cast,'native function pointer cast: '+cast
    assert "memory.writable_data(address,8)" in source
    return True

def verify_isolation(source,report_path=None):
    check(source)
    review=verify_review()
    for token in FORBIDDEN:
        try:check(source+'\n-- injected regression: '+token)
        except AssertionError:pass
        else:raise AssertionError('isolation gate accepted '+token)
    value={'runtime_profile':'local_retained_cache','build_id':BUILD_ID,
           'source_sha256':hashlib.sha256(source.encode()).hexdigest(),
           'source_observer_present':False,'game_code_writer_present':False,
           'active_native_bytes':0,'filtering_available':'primary_manual',
           'optional_rows_registered':False,'forbidden_tokens_checked':list(FORBIDDEN),
           'negative_gate_cases_passed':len(FORBIDDEN),'backend_review':review,
           'in_game_tested':False,'all_native_update_paths_proven':False}
    if report_path is not None:
        path=Path(report_path).resolve()
        if not path.is_relative_to((ROOT/'build').resolve())or path.suffix!='.json':
            raise ValueError('verification report must be a JSON file under this project build directory')
        path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
    return value

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT/'build/addon.lua')
    parser.add_argument('--report',type=Path,help='explicitly write JSON under build/; default reads only')
    parser.add_argument('--json',action='store_true')
    args=parser.parse_args()
    try:
        value=verify_isolation(args.source.read_text(encoding='utf-8'),args.report)
    except (OSError,UnicodeError,AssertionError,ValueError)as exc:
        if args.json:print(json.dumps({'ok':False,'failed':1,'reason':str(exc)}))
        print('FAIL isolation gate: '+str(exc),file=sys.stderr);raise SystemExit(2)
    if args.json:print(json.dumps({'ok':True,'failed':0,**value},indent=2))
    else:print('PASS reviewed primary cache isolation; SHA256='+value['source_sha256'])
