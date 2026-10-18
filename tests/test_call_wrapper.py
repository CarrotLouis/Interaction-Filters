"""Execute the exact Win64 CALL wrapper, including its original call and return.

Engine memory/collector boundaries are reconstructed; this is not game acceptance.
The original retained-target fixture aliases a candidate pair, unlike the actual
spatial-record layout. test_cache_consumers.py reproduces the resulting defect.
"""
from pathlib import Path
import hashlib
import json
import os
import struct
import unittest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
import unicorn.x86_const as x

ROOT=Path(__file__).resolve().parents[1]
INFO=json.loads((ROOT/'tests/fixtures/call_wrapper_0.2.4.json').read_text(encoding='utf-8'))
GAME,STUB,CONTROL=0x10000000,0x20000000,0x20001000
CALL=GAME+0x9a35f6;PATCH=GAME+0x9a35f8;RETURN=CALL+5;COLLECT=GAME+0x9a05b0
GLOBAL=GAME+0x3326468;INTERACT_GLOBAL=GAME+0x3326d68
MANAGER,DESC,PLAYER,RECORDS=0x30000000,0x30001000,0x30002000,0x30100000
IMANAGER,HASH,ROWS,PAIRS=0x31000000,0x31100000,0x31200000,0x31300000
STACK=0x50000000;RSP=STACK+0x2000
INDEX=2;RECORD=RECORDS+INDEX*0x880
ORIGINAL=bytes.fromhex('cfffff33c0894424')
NONVOL=[x.UC_X86_REG_RBX,x.UC_X86_REG_RBP,x.UC_X86_REG_RSI,x.UC_X86_REG_RDI,
        x.UC_X86_REG_R12,x.UC_X86_REG_R13,x.UC_X86_REG_R14,x.UC_X86_REG_R15]
def u32(n):return struct.pack('<I',n)
def u64(n):return struct.pack('<Q',n)

def machine(types,mask=1,actor=329,local=329,local_count=1,retained=None,
            selected_index=0,count=None,cap=512,zone=0,patched=True):
    uc=Uc(UC_ARCH_X86,UC_MODE_64)
    for base,size in [(GAME+0x9a3000,0x2000),(COLLECT&~0xfff,0x1000),
                      (GLOBAL&~0xfff,0x1000),(STUB,0x4000),(MANAGER,0x4000),
                      (RECORDS,0x4000),(IMANAGER,0x20000),(HASH,0x4000),
                      (ROWS,0x40000),(PAIRS,0x4000),(STACK,0x4000)]:uc.mem_map(base,size)
    blob=bytearray(bytes.fromhex(INFO['hex']))
    for name,value in [('player',GLOBAL),('control',CONTROL),('collect',COLLECT),('interactables',INTERACT_GLOBAL)]:
        struct.pack_into('<Q',blob,INFO['offsets'][name],value)
    uc.mem_write(STUB,bytes(blob));uc.mem_write(CONTROL,u32(mask))
    uc.mem_write(CALL,bytes.fromhex('e8b5cfffff'))
    uc.mem_write(PATCH,ORIGINAL)
    if patched:
        displacement=struct.pack('<i',STUB+INFO['offsets']['entry']-RETURN)
        assert displacement[0]==0xb5
        uc.mem_write(PATCH,displacement[1:]+ORIGINAL[3:])
    uc.mem_write(COLLECT,bytes.fromhex('b878563412c3'))
    uc.mem_write(MANAGER+0x48,u64(RECORDS))
    uc.mem_write(DESC,u64(0x4d1c334d294dfa97)+u32(77)+u32(4196913)+u32(actor)+u32(1))
    uc.mem_write(GLOBAL,u64(PLAYER));uc.mem_write(PLAYER+0x88,u32(local_count))
    uc.mem_write(PLAYER+0x3a8,u32(local))
    uc.mem_write(INTERACT_GLOBAL,u64(IMANAGER))
    uc.mem_write(IMANAGER+0x14040,u32(len(types)))
    uc.mem_write(IMANAGER+0x14050,u64(HASH))
    uc.mem_write(IMANAGER+0x14058,u32(cap))
    uc.mem_write(IMANAGER+0x14060,u32(2654435761))
    uc.mem_write(IMANAGER+0x14070,u64(ROWS))
    pointers=[]
    for i,kind in enumerate(types):
        entity=i+1;pair=PAIRS+i*8;pointers.append(pair)
        uc.mem_write(pair,u32(entity)+u32(zone))
        slot=(entity*2654435761)&511
        uc.mem_write(HASH+slot*8,u32(entity)+u32(i))
        uc.mem_write(ROWS+i*0x370+0x340,u32(1))
        uc.mem_write(ROWS+i*0x370+0x44,u32(kind))
    selected=(pointers[selected_index]if pointers else 0)if retained is None else retained
    calls=[]
    def original(vm,address,size,data):
        if address!=COLLECT:return
        args=[vm.reg_read(r)for r in [x.UC_X86_REG_RCX,x.UC_X86_REG_RDX,x.UC_X86_REG_R8]]
        assert args==[MANAGER,DESC,INDEX],args
        assert vm.reg_read(x.UC_X86_REG_RSP)%16==8,'collector called with wrong stack alignment'
        # A real callee owns all 32 bytes of shadow space.
        vm.mem_write(vm.reg_read(x.UC_X86_REG_RSP)+8,b'\xA5'*32)
        # Populate only when the original runs: filtering must occur AFTER it.
        vm.mem_write(RECORD,u64(selected))
        vm.mem_write(RECORD+0x808,u32(len(types)if count is None else count))
        for j,p in enumerate(pointers):vm.mem_write(RECORD+8+j*8,u64(p))
        calls.append(True)
        for r in (x.UC_X86_REG_RCX,x.UC_X86_REG_RDX,x.UC_X86_REG_R8,x.UC_X86_REG_R9,
                  x.UC_X86_REG_R10,x.UC_X86_REG_R11):vm.reg_write(r,0x77770000)
    uc.hook_add(UC_HOOK_CODE,original)
    for i,r in enumerate(NONVOL):uc.reg_write(r,0xABC000+i*0x100)
    for i in range(6,16):uc.reg_write(getattr(x,'UC_X86_REG_XMM'+str(i)),0xABC000+i)
    uc.reg_write(x.UC_X86_REG_RCX,MANAGER);uc.reg_write(x.UC_X86_REG_RDX,DESC)
    uc.reg_write(x.UC_X86_REG_R8,INDEX);uc.reg_write(x.UC_X86_REG_RSP,RSP)
    return uc,pointers,calls

def run(uc):
    ended=[]
    def stop(vm,address,size,data):
        if address==RETURN:ended.append(address);vm.emu_stop()
    h=uc.hook_add(UC_HOOK_CODE,stop)
    uc.emu_start(CALL,0,count=300000)
    uc.hook_del(h);assert ended==[RETURN],'wrapper failed to return to the original caller'
    n=struct.unpack('<I',uc.mem_read(RECORD+0x808,4))[0]
    out=[struct.unpack('<Q',uc.mem_read(RECORD+8+i*8,8))[0]for i in range(min(n,256))]
    return n,out

class CallWrapper(unittest.TestCase):
    def test_layout_and_unwind_metadata(self):
        code=bytes.fromhex(INFO['hex']);o=INFO['offsets']
        self.assertEqual(hashlib.sha256(code).hexdigest(),INFO['sha256'])
        self.assertEqual(o['entry'],0xb0)
        self.assertEqual(code[o['entry']:o['body']],bytes.fromhex('5356574883ec40'))
        self.assertEqual(code[o['unwind']:o['unwind']+12],bytes.fromhex('010704000772037002600130'))
        self.assertEqual(struct.unpack_from('<III',code,o['function_table']),
                         (o['entry'],o['wrapper_end'],o['unwind']))
    def test_only_primary_removed_and_order_preserved(self):
        for types in [[],[1],[3],[1,3,1,10,48,1],[3,1,19,2,44,41],list(range(52))]:
            uc,ps,calls=machine(types)
            n,out=run(uc)
            self.assertEqual(out,[p for p,t in zip(ps,types)if t!=1])
            self.assertEqual(n,sum(t!=1 for t in types));self.assertEqual(len(calls),1)
    def test_off_and_remote_are_identical_to_original(self):
        for args in [dict(mask=0),dict(actor=330),dict(local=0x7fff),dict(local_count=0),dict(local_count=2)]:
            uc,ps,calls=machine([1,3,1,48],**args);n,out=run(uc)
            self.assertEqual((n,out),(4,ps));self.assertEqual(len(calls),1)
            self.assertEqual(struct.unpack('<Q',uc.mem_read(RECORD,8))[0],ps[0])
    def test_synthetic_pair_alias_retained_target(self):
        for selected in range(4):
            uc,ps,_=machine([1,3,48,1],selected_index=selected);run(uc)
            self.assertEqual(struct.unpack('<Q',uc.mem_read(RECORD,8))[0],0 if selected in (0,3)else ps[selected])
    def test_maximum_capacity_and_unknown_fail_open(self):
        types=[1 if i%3==0 else 3 for i in range(256)]
        uc,ps,_=machine(types);n,out=run(uc)
        self.assertEqual(out,[p for p,t in zip(ps,types)if t!=1])
        for args in [dict(cap=0),dict(cap=3),dict(cap=131072),dict(zone=8)]:
            uc,ps,_=machine([1,3],**args);self.assertEqual(run(uc),(2,ps))
        uc,_,_=machine([1,3],count=300);n,_=run(uc);self.assertEqual(n,300)
    def test_win64_nonvolatile_state_and_return_value(self):
        for args in [dict(),dict(mask=0),dict(actor=330)]:
            uc,_,_=machine([1,3,1],**args)
            saved=[uc.reg_read(r)for r in NONVOL]
            run(uc)
            self.assertEqual([uc.reg_read(r)for r in NONVOL],saved)
            self.assertEqual(uc.reg_read(x.UC_X86_REG_RSP),RSP)
            self.assertEqual(uc.reg_read(x.UC_X86_REG_RAX),0x12345678)
            for i in range(6,16):self.assertEqual(uc.reg_read(getattr(x,'UC_X86_REG_XMM'+str(i))),0xABC000+i)
    def test_patch_preserves_call_opcode_low_byte_and_next_instructions(self):
        uc,_,_=machine([1]);run(uc)
        self.assertEqual(bytes(uc.mem_read(CALL,2)),bytes.fromhex('e8b5'))
        self.assertEqual(bytes(uc.mem_read(RETURN,5)),ORIGINAL[3:])

if __name__=='__main__':unittest.main(verbosity=2)
