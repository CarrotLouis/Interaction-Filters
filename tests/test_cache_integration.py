"""Production Lua cache backend -> retained native getter/manual request boundary.

The heap and Windows write boundary are synthetic. Unlike a hand-edited pointer
test, the real production Lua decides the new selection, then the original x64
consumer runs on that exact result. Engine template/request calls remain mocked.
No game process, network, executable allocation, or game API call is made.
"""
from pathlib import Path
import struct
import sys
import unittest

import lupa.luajit21 as lua
from unicorn import UcError

ROOT=Path(__file__).resolve().parents[1]
import test_cache_consumers as native


def fixture(zone=0):
    rt=lua.LuaRuntime(encoding=None,unpack_returned_tuples=True)
    rt.globals()[b'root']=ROOT.as_posix().encode()
    rt.globals()[b'zone']=zone
    rt.execute(b"F=dofile(root..'/tests/cache_fixture.lua');f=F.new(root,zone);assert(f.backend.configure(1))")
    return rt,rt.globals()[b'f']


def machine(f):
    vm,_,_=native.machine()
    for region in f[b'regions'].values():
        at,raw=int(region[b'a']),region[b's']
        for page in range(at&~0xfff,(at+len(raw)+0xfff)&~0xfff,0x1000):
            try:vm.mem_read(page,1)
            except UcError:vm.mem_map(page,0x1000)
        vm.mem_write(at,raw)
    return vm


class CacheIntegration(unittest.TestCase):
    def test_production_lua_to_native_support_request(self):
        for zone in [0,1,7]:
            with self.subTest(zone=zone):
                rt,f=fixture(zone)
                before=machine(f)
                _,requests=native.invoke(before,'manual_interact',manager=int(f[b'manager']))
                self.assertEqual(requests,[(100,77,0)])
                rt.execute(b'f.backend.step()')
                self.assertEqual(len(f[b'writes']),1)
                self.assertEqual(f[b'writes'][1][b'address'],f[b'row'])
                self.assertEqual(len(f[b'writes'][1][b'after']),8)
                after=machine(f)
                result,_=native.invoke(after,'selected_payload',manager=int(f[b'manager']))
                self.assertEqual(result,int(f[b'support_payload']))
                _,requests=native.invoke(after,'manual_interact',manager=int(f[b'manager']))
                self.assertEqual(requests,[(101,77,zone)])
                for at,raw in native.CODE.values():
                    self.assertEqual(bytes(after.mem_read(at,len(raw))),raw)

    def test_primary_without_replacement_is_not_submitted(self):
        rt,f=fixture()
        rt.execute(b'f.put(f.row+0x808,F.u32(0));f.backend.step()')
        vm=machine(f)
        _,requests=native.invoke(vm,'manual_interact',manager=int(f[b'manager']))
        self.assertEqual(requests,[])

    def test_off_leaves_native_primary_request_intact(self):
        rt,f=fixture()
        rt.execute(b'f.backend.disable();f.backend.step()')
        self.assertEqual(len(f[b'writes']),0)
        vm=machine(f)
        _,requests=native.invoke(vm,'manual_interact',manager=int(f[b'manager']))
        self.assertEqual(requests,[(100,77,0)])

    def test_host_owned_other_actor_still_submits_primary(self):
        rt,f=fixture();rt.execute(b'f.backend.step()')
        vm=machine(f)
        _,requests=native.invoke(vm,'manual_interact',actor=75,manager=int(f[b'manager']))
        self.assertEqual(requests,[(100,75,0)])

    def test_high_entity_hash_products_match_native_32bit_multiply(self):
        rt,f=fixture(7)
        rt.execute(b'''
            local entity,mul=0xf1234567,0xfdb97531
            f.put(f.descriptor+8,F.u32(entity));f.put(f.manager+0x38,F.u32(mul))
            f.put(f.manager+0x1000,string.rep('\\0',64))
            local slot=(entity%8)*(mul%8)%8
            f.put(f.manager+0x1000+slot*8,F.u32(entity)..F.u32(2))
            f.backend.step()
        ''')
        self.assertEqual(len(f[b'writes']),1)
        vm=machine(f)
        _,requests=native.invoke(vm,'manual_interact',actor=0xf1234567,manager=int(f[b'manager']))
        self.assertEqual(requests,[(101,0xf1234567,7)])

    def test_layout_fixture_decodes_and_matches_production_pins(self):
        import hashlib,json
        from capstone import Cs,CS_ARCH_X86,CS_MODE_64
        rt,f=fixture()
        pins={int(p[b'rva']):p[b'hex'].decode()for p in f[b'P'][b'pins'].values()}
        data=json.loads((ROOT/'tests/fixtures/cache_layout.json').read_text(encoding='utf-8'))
        md=Cs(CS_ARCH_X86,CS_MODE_64)
        self.assertEqual(data['steam_build'],'25480438')
        self.assertEqual(len({p['rva']for p in data['pins']}),len(data['pins']))
        for p in data['pins']:
            at=int(p['rva'],16);raw=bytes.fromhex(p['hex'])
            ins=list(md.disasm(raw,at))
            self.assertEqual(len(ins),1)
            self.assertEqual(ins[0].size,len(raw))
            self.assertEqual(ins[0].mnemonic+' '+ins[0].op_str,p['asm'])
            self.assertEqual(pins[at],p['hex'])
        self.assertEqual(f[b'P'][b'cache'][b'slots'],2048)
        self.assertIn('0x880',pins and (ROOT/'src/cache_backend.lua').read_text())


if __name__=='__main__':unittest.main(verbosity=2)
