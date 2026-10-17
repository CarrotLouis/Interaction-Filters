"""Assemble the small native predicate; no DLL is installed or redistributed."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
argparse.ArgumentParser(description=__doc__).parse_args()
BUILD = ROOT/'build'
BUILD.mkdir(exist_ok=True)
TOOLCHAIN = os.environ.get('PPB_TOOLCHAIN')

def compiler_tool(name):
    if TOOLCHAIN:
        candidate = Path(TOOLCHAIN) / (name + ('.exe' if os.name == 'nt' else ''))
        if not candidate.is_file():
            raise RuntimeError(f'Missing {candidate}; set PPB_TOOLCHAIN to the x64 GNU bin folder')
        return str(candidate)
    found = shutil.which(name)
    if not found:
        raise RuntimeError(f'{name} is not on PATH; set PPB_TOOLCHAIN or see docs/DEVELOPMENT.md')
    return found
obj, binary = BUILD/'filter.o', BUILD/'filter.bin'
temp = BUILD/'compiler-temp'
temp.mkdir(exist_ok=True)
compiler_env = dict(os.environ, TMP=str(temp), TEMP=str(temp), TMPDIR=str(temp))
subprocess.run([compiler_tool('gcc'), '-c', '-o', str(obj), str(ROOT/'native/filter_v3.S')],
               check=True, env=compiler_env)
subprocess.run([compiler_tool('objcopy'), '-O', 'binary', '--only-section=.text', str(obj), str(binary)], check=True)
relocations = subprocess.run([compiler_tool('objdump'), '-r', str(obj)], check=True,
                             stdout=subprocess.PIPE, text=True).stdout
assert 'IMAGE_REL_AMD64_' not in relocations and 'R_X86_64_' not in relocations, 'native predicate has unresolved relocations'
code = binary.read_bytes()
offsets = {}
for name, marker in [('player',0x1111111111111111), ('control',0x2222222222222222),
                     ('collect',0x3333333333333333), ('interactables',0x4444444444444444)]:
    token = struct.pack('<Q',marker)
    assert code.count(token) == 1, name
    offsets[name] = code.index(token)
cas = bytes.fromhex('4c89c0f0480fb111c3')
assert code.count(cas) == 1
symbols=subprocess.check_output([compiler_tool('objdump'),'-t',str(obj)],text=True)
for name,label in [('entry','ppb_filter'),('body','ppb_body'),('epilogue','ppb_epilogue'),
                   ('wrapper_end','ppb_wrapper_end'),('cas','ppb_compare_exchange'),
                   ('unwind','ppb_unwind'),('function_table','ppb_function_table')]:
    row=next(line for line in symbols.splitlines()if line.split()and line.split()[-1]==label)
    offsets[name]=int(row.split()[-2],16)
assert offsets['cas']==code.index(cas)
assert len(code)<4096 and offsets['entry']==0xb0
assert code[offsets['entry']:offsets['body']]==bytes.fromhex('5356574883ec40')
assert struct.unpack_from('<III',code,offsets['function_table'])==(offsets['entry'],offsets['wrapper_end'],offsets['unwind'])
info = {'bytes':len(code), 'sha256':hashlib.sha256(code).hexdigest(), 'hex':code.hex(), 'offsets':offsets}
(BUILD/'filter.json').write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
offset_lua = ','.join(f'{name}={off}' for name,off in offsets.items())
(ROOT/'src/native_blob.lua').write_text(
    '-- Generated from native/filter_v3.S by scripts/build_native.py.\n'
    f"return {{sha256='{info['sha256']}',hex='{info['hex']}',offsets={{{offset_lua}}}}}\n",encoding='utf-8')
print(f'Native predicate assembled: {len(code)} bytes; CAS offset {offsets["cas"]}; {info["sha256"]}')
