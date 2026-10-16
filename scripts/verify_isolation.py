"""Hard gate on the exact composed Lua: diagnostic scope, no source observer.

This is a source/envelope check, not proof of game stability. It never deploys.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
FORBIDDEN=('objects_owned_by','GameSession','origin_reader','support_origins',
           'ownership_queries','Network.game_session','Application.main_world',
           'temp_byte_count')
def check(source):
    for token in FORBIDDEN:
        assert token not in source,'isolation violation: '+token
    assert re.search(r"local version='0\.2\.3'",source)
    assert "local BUILD_ID='0.2.3-primary-only.1'" in source
    assert "{key='primary'," in source
    for key in ('team_support','field_support','sample_bottle','sample','info'):
        assert "{key='"+key+"'," not in source,'optional filter registered: '+key
    assert 'source_observer=not_included' in source
    return True
def verify_isolation(source,report_path=None):
    check(source)
    # The gate must catch an observer reintroduced after source composition.
    for token in FORBIDDEN:
        try:check(source+'\n-- injected regression: '+token)
        except AssertionError:pass
        else:raise AssertionError('isolation gate accepted '+token)
    value={'runtime_profile':'primary_only_isolation','build_id':'0.2.3-primary-only.1',
           'source_sha256':hashlib.sha256(source.encode()).hexdigest(),
           'source_observer_present':False,'source_query_symbols_present':False,
           'optional_rows_registered':False,'forbidden_tokens_checked':list(FORBIDDEN),
           'negative_gate_cases_passed':len(FORBIDDEN),'in_game_tested':False}
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
        src=args.source.read_text(encoding='utf-8')
        value=verify_isolation(src,args.report)
    except (OSError,UnicodeError,AssertionError,ValueError)as exc:
        reason='FAIL isolation gate: '+str(exc)
        if args.json:print(json.dumps({'ok':False,'failed':1,'reason':str(exc)}))
        print(reason,file=sys.stderr);raise SystemExit(2 if isinstance(exc,OSError)else 1)
    if args.json:print(json.dumps({'ok':True,'failed':0,**value},indent=2))
    else:print('PASS primary-only isolation; bytes='+str(len(src.encode()))+' SHA256='+value['source_sha256'])
