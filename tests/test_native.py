"""Execute the shipped x64 predicate and the retained original gate with Unicorn.

This proves machine control flow and actor/type isolation, not real engine gameplay.
"""
from pathlib import Path
import hashlib
import json
import os
import struct
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
import unicorn.x86_const as x

INFO=json.loads((ROOT/'tests/fixtures/predicate_0.2.3.json').read_text())
BLOB=bytes.fromhex(INFO['hex'])
GATE=json.loads((ROOT/'tests/fixtures/native_gate.json').read_text())
PREFIX=json.loads((ROOT/'tests/fixtures/native_candidate_prefix.json').read_text())
OLD=json.loads((ROOT/'tests/fixtures/predicate_0.2.2.json').read_text())
GAME,STUB,CONTROL=0x10000000,0x20000000,0x20001000
SITE=GAME+0x9a0dab
PATCH=GAME+0x9a0da8
RESUME=GAME+0x9a0db0
SKIP=GAME+0x9a0a9c
ALLOW=GAME+0x9a0de5
GLOBAL=GAME+0x3326468
STACK,DESC,RECORD,PLAYER,CANDIDATE=0x30000000,0x31000000,0x31001000,0x31002000,0x31003000
TARGET=0x31004000
REGS=[x.UC_X86_REG_RAX,x.UC_X86_REG_RBX,x.UC_X86_REG_RCX,x.UC_X86_REG_RDX,
      x.UC_X86_REG_RSI,x.UC_X86_REG_RDI,x.UC_X86_REG_RBP,x.UC_X86_REG_R8,x.UC_X86_REG_R9,
      x.UC_X86_REG_R10,x.UC_X86_REG_R11,x.UC_X86_REG_R12,x.UC_X86_REG_R13,
      x.UC_X86_REG_R14,x.UC_X86_REG_R15]

def u64(n):return struct.pack('<Q',n)
def u32(n):return struct.pack('<I',n)

def machine(kind=1,unit=101,owned=True,avatar=True,enabled=True,local_network_id=329,actor_network_id=None,
            whitelist=(),selected=None,player_present=True,local_count=1,mask=None,
            origins=(),sequence=0,cache_count=None,actor_present=True,blob_info=None):
    uc=Uc(UC_ARCH_X86,UC_MODE_64)
    for address,size in [(GAME+0x9a0000,0x1000),(GLOBAL&~0xfff,0x1000),
                         (STUB,0x4000),(STACK,0x4000),(DESC,0x5000)]:
        uc.mem_map(address,size)
    uc.mem_write(SITE,bytes.fromhex(GATE['gate_hex']))
    uc.mem_write(PATCH,bytes.fromhex(GATE['original8']))
    metadata=blob_info or INFO
    blob=bytearray(bytes.fromhex(metadata['hex']))
    for key,value in [('player',GLOBAL),('control',CONTROL),('resume',RESUME),('skip',SKIP)]:
        struct.pack_into('<Q',blob,metadata['offsets'][key],value)
    uc.mem_write(STUB,bytes(blob))
    uc.mem_write(CONTROL,u32((1 if enabled else 0) if mask is None else mask)+u32(sequence))
    uc.mem_write(CONTROL+32,u32(len(origins) if cache_count is None else cache_count))
    for i,(entity,source,row) in enumerate(origins):
        uc.mem_write(CONTROL+64+i*16,u32(entity)+u32(source)+u64(row))
    uc.mem_write(GLOBAL,u64(PLAYER if player_present else 0))
    typ=0x4d1c334d294dfa97 if avatar else 0x0123456789abcdef
    if actor_network_id is None:actor_network_id=329 if unit==101 else 330
    uc.mem_write(DESC,u64(typ)+u32(77)+u32(unit)+u32(actor_network_id)+u32(1 if owned else 0))
    uc.mem_write(PLAYER+0x3a8,u32(local_network_id))
    uc.mem_write(PLAYER+0x88,u32(local_count))
    uc.mem_write(RECORD,u64(CANDIDATE if selected is None else selected))
    uc.mem_write(RECORD+0x878,u32(len(whitelist)))
    for i,value in enumerate(whitelist):uc.mem_write(RECORD+0x838+i*4,u32(value))
    rsp=STACK+0x2000
    uc.mem_write(rsp+0x40,u64(RECORD))
    uc.mem_write(rsp+0x28,u64(DESC if actor_present else 0))
    uc.mem_write(rsp+0x20,u32(7))
    for i,reg in enumerate(REGS):uc.reg_write(reg,0x12345000+i*0x100)
    uc.reg_write(x.UC_X86_REG_R12,CANDIDATE)
    uc.reg_write(x.UC_X86_REG_R13,TARGET)
    uc.mem_write(CANDIDATE,u32(77)+u32(0))
    uc.reg_write(x.UC_X86_REG_R15,kind)
    uc.reg_write(x.UC_X86_REG_RSP,rsp)
    uc.reg_write(x.UC_X86_REG_RFLAGS,0xad7) # exercise preservation of all arithmetic flags
    uc.reg_write(x.UC_X86_REG_XMM0,0x123456789abc)
    return uc

def run(uc,patched=True,stop_at_gate=False,start=SITE):
    if patched:
        uc.mem_write(PATCH,bytes.fromhex(GATE['original8'])[:3]+b'\xe9'+struct.pack('<i',STUB-(SITE+5)))
    stop_points={SKIP,RESUME} if stop_at_gate else {SKIP,ALLOW}
    result=[]
    def stop(vm,address,size,data):
        if address in stop_points:
            result.append(address);vm.emu_stop()
    hook=uc.hook_add(UC_HOOK_CODE,stop)
    uc.emu_start(start,0,count=6000)
    uc.hook_del(hook)
    assert len(result)==1, 'predicate did not reach an original continuation'
    return result[0]

class Native(unittest.TestCase):
    def test_network_id_namespace_and_reinforcement(self):
        # Distinct realistic unit/network IDs, including the live STATUS unit.
        # Actor network IDs here are reconstructed test data, not a live capture.
        for unit,goid,local_goid,blocked in [
                (4196913,329,329,True),(4196913,330,329,False),
                (329,330,329,False),(4196913,329,0x7fff,False),
                (8389421,411,411,True),(4196913,329,411,False),
                (4196913,411,411,True)]:
            uc=machine(unit=unit,actor_network_id=goid,local_network_id=local_goid)
            self.assertEqual(run(uc),SKIP if blocked else ALLOW)
            d=struct.unpack('<16I',uc.mem_read(CONTROL+0x2100,64))
            self.assertEqual(d[9],unit,'unit diagnostic conflated with network ID')
            self.assertEqual(d[10],local_goid)
            self.assertEqual(struct.unpack('<I',uc.mem_read(CONTROL+0x2240,4))[0],goid)
        wrong=machine(unit=4196913,actor_network_id=329,local_network_id=329,blob_info=OLD)
        decoy=machine(unit=329,actor_network_id=330,local_network_id=329,blob_info=OLD)
        self.assertEqual(run(wrong),ALLOW,'old shipped namespace bug was not reproduced')
        self.assertEqual(run(decoy),SKIP,'old accidental numeric collision was not reproduced')
    def test_blob_identity(self):
        self.assertEqual(hashlib.sha256(BLOB).hexdigest(),INFO['sha256'])
        self.assertEqual(BLOB[:5],bytes.fromhex('4c8b442440'))
        self.assertLess(len(BLOB),4096)
    def test_only_primary_for_current_local_unit(self):
        cases=0
        for kind in list(range(52))+[99,0xffffffff]:
            for unit,owned,avatar in [(101,True,True),(202,False,True),
                                      (202,True,True),(101,False,True),(101,True,False),
                                      (101,False,False)]:
                with self.subTest(kind=kind,unit=unit,owned=owned,avatar=avatar):
                    uc=machine(kind,unit,owned,avatar)
                    self.assertEqual(run(uc),SKIP if kind==1 and unit==101 else ALLOW)
                    self.assertEqual(struct.unpack('<I',uc.mem_read(CONTROL+8,4))[0],
                                     int(kind==1 and unit==101))
                    cases+=1
        self.assertEqual(cases,324)
    def test_off_is_differentially_identical_to_original_gate(self):
        for enabled in [False,True]:
            for kind in list(range(52))+[99]:
                for whitelist in [(),(3,),(1,3),(27,28,43)]:
                    if enabled and kind==1:continue # the one intentional behavior change
                    before=machine(kind,enabled=enabled,whitelist=whitelist)
                    after=machine(kind,enabled=enabled,whitelist=whitelist)
                    self.assertEqual(run(before,False),run(after,True))
                    for reg in REGS+[x.UC_X86_REG_RSP,x.UC_X86_REG_RFLAGS,x.UC_X86_REG_XMM0]:
                        self.assertEqual(before.reg_read(reg),after.reg_read(reg),(kind,reg))
                    self.assertEqual(before.mem_read(RECORD,0x880),after.mem_read(RECORD,0x880))
    def test_native_continuations_preserve_state_and_stack(self):
        for kind in [1,2,3,28,99]:
            uc=machine(kind)
            initial={r:uc.reg_read(r) for r in REGS+[x.UC_X86_REG_RSP,x.UC_X86_REG_RFLAGS,x.UC_X86_REG_XMM0]}
            result=run(uc,True,True)
            self.assertEqual(result,SKIP if kind==1 else RESUME)
            for reg,value in initial.items():
                self.assertEqual(uc.reg_read(reg),RECORD if reg==x.UC_X86_REG_R8 else value)
    def test_synthetic_pair_alias_retained_identity_check(self):
        # Historical pointer-equality behavior only. The real retained pointer
        # names a spatial record; see test_cache_consumers.py for the defect.
        uc=machine();run(uc)
        self.assertEqual(uc.mem_read(RECORD,8),bytes(8))
        support=CANDIDATE+0x100
        uc=machine(selected=support);run(uc)
        self.assertEqual(uc.mem_read(RECORD,8),u64(support))
    def test_no_avatar_and_not_ready_go_through(self):
        for values in [dict(unit=4196913,actor_network_id=0x7fff,local_network_id=0x7fff),dict(player_present=False),
                       dict(local_count=0),dict(local_count=2),dict(actor_present=False)]:
            uc=machine(**values);self.assertEqual(run(uc),ALLOW)
    def test_every_mask_is_independent_and_local_only(self):
        cases=[(1,0,0),(3,1,None),(3,2,1),(3,3,2),
               (11,0,3),(10,0,4),(48,0,5),(2,0,None),(29,0,None),(37,0,None)]
        for mask in range(64):
            for kind,source,bit in cases:
                for unit,owned,avatar in [(101,True,True),(202,True,True),
                                          (101,False,True),(101,True,False)]:
                    with self.subTest(mask=mask,kind=kind,source=source,unit=unit,owned=owned,avatar=avatar):
                        blocked=bit is not None and bool(mask&(1<<bit)) and unit==101
                        uc=machine(kind,unit,owned,avatar,mask=mask,origins=[(77,source,TARGET)])
                        self.assertEqual(run(uc),SKIP if blocked else ALLOW)
                        counters=struct.unpack('<6I',uc.mem_read(CONTROL+8,24))
                        self.assertEqual(counters,tuple(int(blocked and i==bit) for i in range(6)))
                        self.assertEqual(uc.mem_read(RECORD,8),bytes(8) if blocked else u64(CANDIDATE))
    def test_previous_predicate_counterexamples_and_new_diagnostics(self):
        # These are required local-isolation cases, not claimed live captures.
        for values in [dict(owned=False),dict(avatar=False),dict(owned=False,avatar=False)]:
            before=machine(**values,blob_info=OLD)
            after=machine(**values)
            self.assertEqual(run(before),ALLOW,'old assumptions no longer reproduced')
            self.assertEqual(run(after),SKIP)
            d=struct.unpack('<15I',after.mem_read(CONTROL+0x2100,60))
            self.assertEqual(d[:8],(1,1,1,0,0,0,1,1))
            self.assertEqual(d[8:11],(1,101,329))
            self.assertEqual(d[14],1)
        for values,index in [(dict(actor_present=False),3),(dict(local_count=0),4),
                             (dict(player_present=False),4),(dict(unit=202),5)]:
            uc=machine(**values);self.assertEqual(run(uc),ALLOW)
            d=struct.unpack('<15I',uc.mem_read(CONTROL+0x2100,60))
            self.assertEqual(d[index],1)
            self.assertEqual(d[6:8],(0,0))
        for kind in [0,1,3,10,11,48,63,64,0xffffffff,0x100000001]:
            uc=machine(kind,mask=0);run(uc)
            self.assertEqual(struct.unpack('<I',uc.mem_read(CONTROL+0x2100,4))[0],1)
            hist=struct.unpack('<64I',uc.mem_read(CONTROL+0x2140,256))
            self.assertEqual(hist,tuple(int(i==(kind&0xffffffff)) for i in range(64)))
    def test_type_loaded_by_retained_original_candidate_instructions(self):
        prefix=bytes.fromhex(PREFIX['hex']);start=GAME+int(PREFIX['rva'],16)
        self.assertEqual(start+len(prefix),SITE)
        self.assertEqual(hashlib.sha256(prefix).hexdigest(),PREFIX['sha256'])
        for zone in [0,1,7]:
            for kind,source,bit in [(1,0,0),(3,2,1),(3,3,2),(11,0,3),
                                    (10,0,4),(48,0,5),(2,0,None),(29,0,None)]:
                for unit in [101,202]:
                    for mask in [0,1,63]:
                        uc=machine(kind=99,unit=unit,owned=False,avatar=False,mask=mask,
                                   origins=[(77,source,TARGET)])
                        uc.mem_write(start,prefix)
                        uc.mem_write(CANDIDATE+4,u32(zone))
                        # The real prefix calculates zone*0x68 + row, then loads +0x44.
                        record=TARGET+zone*0x68
                        uc.mem_write(record+0x20,struct.pack('<f',1000))
                        uc.mem_write(record+0x38,u32(0xffffffff)) # no engine call needed
                        uc.mem_write(record+0x44,u32(kind))
                        uc.reg_write(x.UC_X86_REG_RSI,DESC+0x100)
                        uc.reg_write(x.UC_X86_REG_RBP,STACK+0x1000)
                        wanted=bit is not None and bool(mask&(1<<bit)) and unit==101
                        self.assertEqual(run(uc,start=start),SKIP if wanted else ALLOW,
                                         (zone,kind,unit,mask))
    def test_unknown_stale_and_unpublished_support_pass_through(self):
        uc=machine(28,mask=63,origins=[(77,2,TARGET)])
        self.assertEqual(run(uc),ALLOW,'pack source monitoring blocked backpack pickups')
        for options in [dict(origins=[]),dict(origins=[(77,0,TARGET)]),
                        dict(origins=[(77,1,TARGET)]),dict(origins=[(77,9,TARGET)]),
                        dict(origins=[(78,2,TARGET)]),dict(origins=[(77,2,TARGET+16)]),
                        dict(origins=[(77,2,TARGET)],sequence=1),
                        dict(origins=[(77,2,TARGET)],cache_count=513)]:
            uc=machine(3,mask=63,**options)
            self.assertEqual(run(uc),ALLOW)
            self.assertEqual(uc.mem_read(CONTROL+8,24),bytes(24))
        uc=machine(3,mask=2,origins=[(77,2,TARGET)])
        check=BLOB.index(bytes.fromhex('443b5004')) # reread sequence after loading source
        def change_sequence(vm,address,size,data):
            if address==STUB+check:vm.mem_write(CONTROL+4,u32(2))
        h=uc.hook_add(UC_HOOK_CODE,change_sequence)
        self.assertEqual(run(uc),ALLOW,'concurrent publication was accepted')
        uc.hook_del(h)
    def test_support_cache_last_row_and_all_six_state_preservation(self):
        rows=[(1000+i,1,TARGET+i*16) for i in range(511)]+[(77,2,TARGET)]
        uc=machine(3,mask=2,origins=rows)
        self.assertEqual(run(uc),SKIP,'last of 512 sources was not read')
        for kind,source,bit in [(1,0,0),(3,2,1),(3,3,2),(11,0,3),(10,0,4),(48,0,5)]:
            uc=machine(kind,mask=1<<bit,origins=[(77,source,TARGET)])
            initial={r:uc.reg_read(r) for r in REGS+[x.UC_X86_REG_RSP,x.UC_X86_REG_RFLAGS,x.UC_X86_REG_XMM0]}
            self.assertEqual(run(uc,True,True),SKIP)
            for reg,value in initial.items():
                self.assertEqual(uc.reg_read(reg),RECORD if reg==x.UC_X86_REG_R8 else value)
    def test_atomic_exchange_exactly_one_owned_aligned_word(self):
        uc=machine()
        expected=int.from_bytes(bytes.fromhex(GATE['original8']),'little')
        desired=int.from_bytes(bytes.fromhex(GATE['original8'])[:3]+b'\xe9'+struct.pack('<i',STUB-(SITE+5)),'little')
        for expect,replace in [(expected,desired),(desired,expected),(desired,0x5555555555555555)]:
            before=int.from_bytes(uc.mem_read(PATCH,8),'little')
            uc.reg_write(x.UC_X86_REG_RCX,PATCH)
            uc.reg_write(x.UC_X86_REG_RDX,replace)
            uc.reg_write(x.UC_X86_REG_R8,expect)
            rsp=STACK+0x2000
            uc.reg_write(x.UC_X86_REG_RSP,rsp)
            uc.mem_write(rsp,u64(ALLOW))
            uc.emu_start(STUB+INFO['offsets']['cas'],ALLOW,count=5)
            self.assertEqual(uc.reg_read(x.UC_X86_REG_RAX),before)
            self.assertEqual(int.from_bytes(uc.mem_read(PATCH,8),'little'),replace if before==expect else before)

if __name__=='__main__':unittest.main(verbosity=2)
