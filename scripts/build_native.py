"""Assemble the small native predicate; no DLL is installed or redistributed."""
from pathlib import Path
import hashlib
import json
import os
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT/'build'
BUILD.mkdir(exist_ok=True)
TOOLCHAIN = Path(os.environ.get('PPB_TOOLCHAIN', r'C:\Enviroments\mingw64\bin'))
obj, binary = BUILD/'filter.o', BUILD/'filter.bin'
temp = BUILD/'compiler-temp'
temp.mkdir(exist_ok=True)
compiler_env = dict(os.environ, TMP=str(temp), TEMP=str(temp), TMPDIR=str(temp))
subprocess.run([str(TOOLCHAIN/'gcc.exe'), '-c', '-o', str(obj), str(ROOT/'native/filter_v2.S')],
               check=True, env=compiler_env)
subprocess.run([str(TOOLCHAIN/'objcopy.exe'), '-O', 'binary', '--only-section=.text', str(obj), str(binary)], check=True)
relocations = subprocess.run([str(TOOLCHAIN/'objdump.exe'), '-r', str(obj)], check=True,
                             stdout=subprocess.PIPE, text=True).stdout
assert 'IMAGE_REL_AMD64_' not in relocations, 'native predicate has unresolved relocations'
code = binary.read_bytes()
offsets = {}
for name, marker in [('player',0x1111111111111111), ('control',0x2222222222222222),
                     ('skip',0x3333333333333333), ('resume',0x4444444444444444)]:
    token = struct.pack('<Q',marker)
    assert code.count(token) == 1, name
    offsets[name] = code.index(token)
cas = bytes.fromhex('4c89c0f0480fb111c3')
assert code.count(cas) == 1
offsets['cas'] = code.index(cas)
assert len(code) < 4096 and code[:5] == bytes.fromhex('4c8b442440')
info = {'bytes':len(code), 'sha256':hashlib.sha256(code).hexdigest(), 'hex':code.hex(), 'offsets':offsets}
(BUILD/'filter.json').write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
offset_lua = ','.join(f'{name}={off}' for name,off in offsets.items())
(ROOT/'src/native_blob.lua').write_text(
    '-- Generated from native/filter_v2.S by scripts/build_native.py.\n'
    f"return {{sha256='{info['sha256']}',hex='{info['hex']}',offsets={{{offset_lua}}}}}\n",encoding='utf-8')
print(f'Native predicate assembled: {len(code)} bytes; CAS offset {offsets["cas"]}; {info["sha256"]}')
