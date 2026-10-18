"""Preserve the WITHDRAWN 0.2.5 diagnostic's offline scope; never a new candidate.

The 0.2.4 run exited after 22 seconds with zero primary blocks. This probe keeps
the CALL/frame, but must touch no actor/candidate memory. Engine data is UNMAPPED
here. Historical filtering tests are deliberately separate from this artifact.
"""
from pathlib import Path
import hashlib
import json
import struct
import unittest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
import unicorn.x86_const as x

ROOT=Path(__file__).resolve().parents[1]
INFO=json.loads((ROOT/'tests/fixtures/entry_probe_0.2.5.json').read_text(encoding='utf-8'))
CALL=0x109a35f6
RETURN=CALL+5
COLLECT=0x109a05b0
STUB=0x20000000
CONTROL=STUB+4096
STACK=0x50000000
RSP=STACK+0x2000
ORIGINAL=bytes.fromhex('cfffff33c0894424')
NONVOL=[x.UC_X86_REG_RBX,x.UC_X86_REG_RBP,x.UC_X86_REG_RSI,x.UC_X86_REG_RDI,
        x.UC_X86_REG_R12,x.UC_X86_REG_R13,x.UC_X86_REG_R14,x.UC_X86_REG_R15]
ARGS=[x.UC_X86_REG_RCX,x.UC_X86_REG_RDX,x.UC_X86_REG_R8,x.UC_X86_REG_R9]

def word(vm,address):return struct.unpack('<I',vm.mem_read(address,4))[0]

def execute(args=(1,2,0xffffffff,4),mask=1,stop_at_collector=False):
    vm=Uc(UC_ARCH_X86,UC_MODE_64)
    for base,size in [(CALL&~0xfff,0x1000),(COLLECT&~0xfff,0x1000),
                      (STUB,0x4000),(STACK,0x4000)]:vm.mem_map(base,size)
    code=bytearray.fromhex(INFO['hex'])
    for name,value in [('control',CONTROL),('collect',COLLECT)]:
        struct.pack_into('<Q',code,INFO['offsets'][name],value)
    vm.mem_write(STUB,bytes(code))
    vm.mem_write(CONTROL,struct.pack('<I',mask))
    displacement=struct.pack('<i',STUB+INFO['offsets']['entry']-RETURN)
    assert displacement[0]==0xb5
    vm.mem_write(CALL,b'\xe8\xb5'+ORIGINAL)
    vm.mem_write(CALL+2,displacement[1:]+ORIGINAL[3:])
    vm.mem_write(COLLECT,bytes.fromhex('b878563412c3'))
    for i,reg in enumerate(NONVOL):vm.reg_write(reg,0xabc000+i*0x100)
    for i in range(6,16):vm.reg_write(getattr(x,'UC_X86_REG_XMM'+str(i)),0xabc000+i)
    for reg,value in zip(ARGS,args):vm.reg_write(reg,value)
    vm.reg_write(x.UC_X86_REG_RSP,RSP)
    calls=[];ended=[];accesses=[]
    def boundary(uc,at,size,data):
        if at==COLLECT:
            assert [uc.reg_read(reg)for reg in ARGS]==list(args)
            assert uc.reg_read(x.UC_X86_REG_RSP)%16==8
            assert word(uc,CONTROL+0x2244)==1 and word(uc,CONTROL+0x2248)==0
            calls.append(at)
            if stop_at_collector:uc.emu_stop();return
            uc.mem_write(uc.reg_read(x.UC_X86_REG_RSP)+8,b'\xa5'*32)
            for reg in ARGS+[x.UC_X86_REG_R10,x.UC_X86_REG_R11]:uc.reg_write(reg,0x77770000)
        if at==RETURN:ended.append(at);uc.emu_stop()
    def memory(uc,access,at,size,value,data):
        # Instruction fetches are distinct; all data access must be private.
        assert (STUB<=at and at+size<=STUB+0x4000)or(STACK<=at and at+size<=STACK+0x4000),hex(at)
        if CONTROL<=at<CONTROL+0x3000:
            assert at in {CONTROL+0x2100,CONTROL+0x2244,CONTROL+0x2248},hex(at)
        accesses.append((access,at,size))
    vm.hook_add(UC_HOOK_CODE,boundary)
    vm.hook_add(UC_HOOK_MEM_READ|UC_HOOK_MEM_WRITE,memory)
    vm.emu_start(CALL,0,count=10000)
    return vm,calls,ended,accesses

class EntryProbe(unittest.TestCase):
    def test_historical_identity_unwind_and_current_absence(self):
        code=bytes.fromhex(INFO['hex']);offset=INFO['offsets']
        self.assertEqual(hashlib.sha256(code).hexdigest(),INFO['sha256'])
        self.assertNotIn('player',offset);self.assertNotIn('interactables',offset)
        self.assertEqual(offset['entry'],0xb0)
        self.assertEqual(code[offset['entry']:offset['body']],bytes.fromhex('5356574883ec40'))
        self.assertEqual(code[offset['unwind']:offset['unwind']+12],bytes.fromhex('010704000772037002600130'))
        self.assertTrue(INFO['hex']in(ROOT/'src/native_blob.lua').read_text(encoding='utf-8'))
        self.assertTrue(INFO['hex']not in(ROOT/'build/addon.lua').read_text(encoding='utf-8'),
                        'withdrawn entry bytes were reintroduced into the current artifact')

    def test_unmapped_engine_arguments_all_masks(self):
        for mask in (0,1,63):
            for args in [(0,0,0,0),(1,2,0xffffffff,4),(0xdead0000,0xbeef0000,99,0xfedcba98)]:
                vm,calls,ended,accesses=execute(args,mask)
                self.assertEqual((calls,ended),([COLLECT],[RETURN]));self.assertTrue(accesses)
                self.assertEqual(word(vm,CONTROL+0x2244),1)
                self.assertEqual(word(vm,CONTROL+0x2248),1)
                self.assertEqual(word(vm,CONTROL+0x2100),1)
                self.assertEqual(bytes(vm.mem_read(CONTROL+8,24)),b'\0'*24)
                self.assertEqual(word(vm,CONTROL+0x2104),0)
                self.assertEqual(word(vm,CONTROL+0x2118),0)

    def test_original_return_and_abi(self):
        vm,_,_,_=execute()
        self.assertEqual(vm.reg_read(x.UC_X86_REG_RAX),0x12345678)
        self.assertEqual(vm.reg_read(x.UC_X86_REG_RSP),RSP)
        self.assertEqual([vm.reg_read(reg)for reg in NONVOL],[0xabc000+i*0x100 for i in range(8)])
        for i in range(6,16):self.assertEqual(vm.reg_read(getattr(x,'UC_X86_REG_XMM'+str(i))),0xabc000+i)

    def test_instrument_distinguishes_entered_from_returned(self):
        vm,calls,ended,_=execute(stop_at_collector=True)
        self.assertEqual(calls,[COLLECT]);self.assertEqual(ended,[])
        self.assertEqual(word(vm,CONTROL+0x2244),1)
        self.assertEqual(word(vm,CONTROL+0x2248),0)
        self.assertEqual(word(vm,CONTROL+0x2100),0)

    def test_call_prefix_and_adjacent_instructions(self):
        vm,_,_,_=execute()
        self.assertEqual(bytes(vm.mem_read(CALL,2)),bytes.fromhex('e8b5'))
        self.assertEqual(bytes(vm.mem_read(RETURN,5)),ORIGINAL[3:])

if __name__=='__main__':unittest.main(verbosity=2)
