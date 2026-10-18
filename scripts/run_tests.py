from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
import lupa.luajit21 as luajit

def run_tests():
    tests=['test_lifecycle.lua','test_near_allocator.lua','test_windows.lua','test_call_execution.lua','test_mission_guard.lua',
           'test_entry.lua','test_ship_entry.lua','test_mission_disabled_entry.lua',
           'test_mission_entry.lua','test_mom_api.lua']
    scratch=ROOT/'build/test-logs'
    scratch.mkdir(parents=True,exist_ok=True)
    outputs=[]
    mom=Path(os.environ.get('PPB_MOM_SOURCE',str(ROOT/'external/ModOptionsMenu'))).resolve()
    if not (mom/'src/mod_options_menu.lua').exists():
        raise RuntimeError('ModOptionsMenu source is needed for the author-API test; set PPB_MOM_SOURCE')
    for name in tests:
        rt=luajit.LuaRuntime(unpack_returned_tuples=True)
        rt.globals().arg=rt.table_from({1:ROOT.as_posix(),2:scratch.as_posix(),3:mom.as_posix()})
        rt.execute((ROOT/'tests'/name).read_text(encoding='utf-8'))
        outputs.append({'runtime':'lupa.luajit21','test':name,'passed':True})
    dll_value=os.environ.get('HD2_LUA51_DLL')
    if not dll_value:
        raise RuntimeError('Set HD2_LUA51_DLL to the installed game bin/lua51.dll; see docs/DEVELOPMENT.md')
    dll=Path(dll_value).resolve()
    if not dll.exists():
        raise RuntimeError('The installed game lua51.dll is required for the exact-VM gate; set HD2_LUA51_DLL')
    env=dict(os.environ,HD2_LUA51_DLL=str(dll))
    for name in tests:
        subprocess.run([sys.executable,str(ROOT/'scripts/game_lua.py'),str(ROOT/'tests'/name),
                        str(ROOT),str(scratch),str(mom)],env=env,check=True)
        outputs.append({'runtime':'game lua51.dll (no game process)','test':name,'passed':True})
    subprocess.run([sys.executable,str(ROOT/'tests/test_native.py')],check=True)
    outputs.append({'runtime':'Unicorn x64','test':'withdrawn inline-predicate history / original gate / CAS','passed':True})
    subprocess.run([sys.executable,str(ROOT/'tests/test_call_wrapper.py')],check=True)
    outputs.append({'runtime':'Unicorn x64','test':'withdrawn 0.2.4 CALL wrapper history / candidate list / Win64 ABI','passed':True})
    subprocess.run([sys.executable,str(ROOT/'tests/test_entry_probe.py')],check=True)
    outputs.append({'runtime':'Unicorn x64','test':'production entry-only probe / no engine data access / entered-returned instrumentation','passed':True})
    subprocess.run([sys.executable,str(ROOT/'tests/test_release_policy.py')],check=True)
    outputs.append({'test':'withdrawn build/package/source-export refusal and policy validation','passed':True})
    from audit_ffi import audit
    src=(ROOT/'build/addon.lua').read_text(encoding='utf-8')
    audit(src)
    from verify_isolation import verify_isolation
    verify_isolation(src,ROOT/'build/isolation-verification.json')
    outputs.append({'test':'source observer absent from exact assembled artifact','passed':True})
    # Probe the audit's refusal under direct, protected and named-constant declarations.
    for text in ['ffi.cdef [[int GetAsyncKeyState(int);]]',
                 'pcall(ffi.cdef, [[int mine(int) __asm__("GetAsyncKeyState");]])',
                 'local D=[[int GetCursorPos(void*);]] ffi.cdef D']:
        try: audit(text)
        except SystemExit: pass
        else: raise AssertionError('FFI gate accepted a forbidden declaration')
    outputs.append({'test':'private FFI aliases and negative declaration gates','passed':True})
    from release_policy import read_policy
    policy=read_policy()
    report={'release_policy':policy,'source_sha256':hashlib.sha256(src.encode()).hexdigest(),
            'native_sha256':json.loads((ROOT/'build/filter.json').read_text())['sha256'],
            'checks':outputs,'in_game_tested':False,'host_client_tested':False,
            'manager_import_tested':False,'game_or_manager_deployed':False}
    (ROOT/'build/tests-passed.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS offline gates only; release state='+policy['state']+'; user live status='+policy['user_live_status'])
    return report

if __name__=='__main__':run_tests()
