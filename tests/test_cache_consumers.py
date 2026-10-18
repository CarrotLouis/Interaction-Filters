"""Retained native consumers on synthetic data, never a live game process.

Unlike the historical wrapper's pair-alias fixture, retained points to a 20-byte
spatial record (floats + payload index). Candidate entries point to 12-byte
entity/zone/score payloads. These tests reproduce the historical defect, then
check only the consumer-side possibility of a data-only replacement.

The manual request boundary, template resolver and special-interaction preamble
are mocked. Network pickup, Lua/native scheduling, lifetime and host/client
acceptance are NOT established here.
"""
from copy import deepcopy
import json
from pathlib import Path
import struct
import subprocess
import sys
import unittest
import uuid

from unicorn import UC_HOOK_CODE, UcError
import unicorn.x86_const as x

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from verify_cache_research import load_fixture, self_test, verify
import test_call_wrapper as old

DATA = load_fixture()
SPATIAL = old.PAIRS + 0x2000
OTHER_SPATIAL = SPATIAL + 0x20
ACTOR_HASH = old.MANAGER + 0x3000
DESCRIPTORS = old.MANAGER + 0x3100
TARGET_DESCRIPTORS = 0x31400000
TEMPLATE = 0x32000000
ACTOR = 77
CODE = {name: (old.GAME + int(block['rva'], 16), bytes.fromhex(block['hex']))
        for name, block in DATA['blocks'].items()}


def word(vm, at):
    return struct.unpack('<I', vm.mem_read(at, 4))[0]


def pointer(vm, at):
    return struct.unpack('<Q', vm.mem_read(at, 8))[0]


def machine(selected=0, support_zone=0):
    vm, pairs, calls = old.machine([1, 3], retained=SPATIAL + selected * 0x20)
    vm.mem_map(TARGET_DESCRIPTORS, 0x2000)
    vm.mem_map(TEMPLATE, 0x1000)
    vm.mem_map(old.GAME + 0x3483000, 0x1000)  # reconstructed invalid/empty IDs = 0
    for name, (at, raw) in CODE.items():
        if name == 'zone_available':
            vm.mem_map(at & ~0xFFF, 0x1000)
        vm.mem_write(at, raw)
    # The main actor lookup. Descriptor +0x10 network ID differs from +0x0C unit.
    vm.mem_write(old.GAME + 0x33269A0, old.u64(old.MANAGER))
    vm.mem_write(old.MANAGER + 0x28, old.u64(ACTOR_HASH))
    vm.mem_write(old.MANAGER + 0x30, struct.pack('<III', 8, 0, 1))
    vm.mem_write(ACTOR_HASH + (ACTOR & 7) * 8, struct.pack('<II', ACTOR, old.INDEX))
    vm.mem_write(old.MANAGER + 0x40, old.u64(DESCRIPTORS))
    vm.mem_write(DESCRIPTORS + old.INDEX * 8, old.u64(old.DESC))
    # A second actor exercises separate rows, even with identical nearby items.
    vm.mem_write(ACTOR_HASH + ((ACTOR+1) & 7) * 8, struct.pack('<II', ACTOR+1, 0))
    vm.mem_write(old.RECORDS, old.u64(OTHER_SPATIAL))
    vm.mem_write(old.IMANAGER + 0x14068, old.u64(TARGET_DESCRIPTORS))
    for index, zone in [(0, 0), (1, support_zone)]:
        spatial = SPATIAL + index * 0x20
        spatial_index = 5 + index
        # The historical collector closure shares this list. Rebuild its entries
        # at the native embedded-payload addresses, rather than the old aliases.
        pairs[index] = old.IMANAGER + 0xE000 + spatial_index * 12
        # X/Y float bits are deliberately not plausible entity/zone values.
        vm.mem_write(spatial, struct.pack('<4fI', 1.0+index, 2.0, 3.0, 0.5, spatial_index))
        vm.mem_write(pairs[index], struct.pack('<IIf', index+1, zone, 10.0-index))
        row = old.ROWS + index * 0x370
        vm.mem_write(row + 0x340, old.u32(zone+1))
        vm.mem_write(row + zone * 0x68 + 0x44, old.u32(1 if index == 0 else 3))
        vm.mem_write(row + zone * 0x68 + 0x60, b'\x01')
        descriptor = TARGET_DESCRIPTORS + 0x1000 + index * 0x100
        vm.mem_write(TARGET_DESCRIPTORS + index * 8, old.u64(descriptor))
        vm.mem_write(descriptor, struct.pack('<QIIII', 123+index, index+1, 10+index, 20+index, 1))
    vm.mem_write(old.RECORD, old.u64(SPATIAL + selected * 0x20))
    vm.mem_write(old.RECORD + 0x808, old.u32(2))
    for index, pair in enumerate(pairs):
        vm.mem_write(old.RECORD + 8 + index * 8, old.u64(pair))
    return vm, pairs, calls


def invoke(vm, name, actor=ACTOR, manager=old.MANAGER):
    requests = []
    stubs = {'template': old.GAME + 0x50ACB0,
             'preamble': old.GAME + 0x9A2C20,
             'request': old.GAME + 0x979570,
             'special': old.GAME + 0x9793B0}
    if name == 'manual_interact':
        # Only the external boundaries are mocked; the selected-payload getter,
        # manual consumer and runtime-zone availability lookup use retained bytes.
        pages = {at & ~0xFFF for at in stubs.values()}
        for page in pages:
            try:
                vm.mem_read(page, 1)
            except UcError:
                vm.mem_map(page, 0x1000)
        for at in stubs.values():
            vm.mem_write(at, b'\xC3')
    ended = []
    def boundary(uc, at, size, context):
        if at == old.RETURN:
            ended.append(True)
            uc.emu_stop()
        elif at == stubs['template']:
            uc.reg_write(x.UC_X86_REG_RAX, TEMPLATE)
        elif at == stubs['request']:
            stack = uc.reg_read(x.UC_X86_REG_RSP)
            requests.append((uc.reg_read(x.UC_X86_REG_R8),
                             uc.reg_read(x.UC_X86_REG_R9), word(uc, stack+0x28)))
            result = uc.reg_read(x.UC_X86_REG_RDX)
            uc.mem_write(result, bytes(24))
            uc.reg_write(x.UC_X86_REG_RAX, result)
    hook = vm.hook_add(UC_HOOK_CODE, boundary)
    vm.reg_write(x.UC_X86_REG_RSP, old.RSP+8)
    vm.mem_write(old.RSP+8, old.u64(old.RETURN))
    vm.reg_write(x.UC_X86_REG_RCX, manager)
    vm.reg_write(x.UC_X86_REG_RDX, actor)
    vm.emu_start(CODE[name][0], 0, count=20000)
    vm.hook_del(hook)
    if ended != [True]:
        raise AssertionError('native consumer did not return')
    return vm.reg_read(x.UC_X86_REG_RAX), requests


class CacheConsumers(unittest.TestCase):
    def test_evidence_and_altered_evidence_refusal(self):
        result = verify(DATA)
        self.assertTrue(result['normal_frame_lua_precedes_game_plugin'])
        self.assertFalse(result['all_native_update_paths_proven'])
        self.assertFalse(result['lifetime_proven'])
        self.assertEqual(self_test(DATA), 3)
        changed = deepcopy(DATA)
        changed['pins'].append(changed['pins'][0])
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            verify(changed)

    def test_getter_resolves_spatial_record_to_payload(self):
        for selected in [0, 1]:
            vm, _, _ = machine(selected=selected)
            result, _ = invoke(vm, 'selected_payload')
            expected = old.IMANAGER + 0xE000 + (5+selected) * 12
            self.assertEqual(result, expected)
            self.assertEqual(word(vm, result), selected+1)
            self.assertNotEqual(pointer(vm, old.RECORD), result)

    def test_historical_wrapper_leaves_real_retained_primary(self):
        vm, pairs, calls = machine()
        self.assertEqual(old.run(vm), (1, [pairs[1]]))
        self.assertEqual(len(calls), 1)
        self.assertEqual(pointer(vm, old.RECORD), SPATIAL)
        # Despite removal from the candidate list, the real manual consumer
        # still reaches the primary request. This is a reproduced old DEFECT.
        _, requests = invoke(vm, 'manual_interact')
        self.assertEqual(requests, [(1, ACTOR, 0)])

    def test_zero_candidate_count_does_not_cancel_retained_request(self):
        vm, _, _ = machine()
        vm.mem_write(old.RECORD + 0x808, old.u32(0))
        _, requests = invoke(vm, 'manual_interact')
        self.assertEqual(requests, [(1, ACTOR, 0)])

    def test_clearing_retained_prevents_this_manual_request(self):
        vm, _, _ = machine()
        vm.mem_write(old.RECORD, bytes(8))
        _, requests = invoke(vm, 'manual_interact')
        self.assertEqual(requests, [])

    def test_data_only_replacement_selects_support_and_its_zone(self):
        for zone in [0, 1, 7]:
            vm, _, _ = machine(support_zone=zone)
            before = bytes(vm.mem_read(old.RECORDS, 0x4000))
            vm.mem_write(old.RECORD, old.u64(OTHER_SPATIAL))
            after = bytes(vm.mem_read(old.RECORDS, 0x4000))
            offset = old.INDEX * 0x880
            self.assertEqual(before[:offset], after[:offset])
            self.assertEqual(before[offset+8:], after[offset+8:])
            self.assertEqual(pointer(vm, old.RECORDS), OTHER_SPATIAL)
            _, requests = invoke(vm, 'manual_interact')
            self.assertEqual(requests, [(2, ACTOR, zone)])
            for at, raw in CODE.values():
                self.assertEqual(bytes(vm.mem_read(at, len(raw))), raw)

    def test_unowned_actor_is_not_submitted(self):
        vm, _, _ = machine()
        vm.mem_write(old.DESC + 0x14, old.u32(0))
        _, requests = invoke(vm, 'manual_interact')
        self.assertEqual(requests, [])

    def test_read_only_cli_errors_have_json_and_exit_two(self):
        target = ROOT / 'build' / ('absent-capture-' + uuid.uuid4().hex)
        self.assertFalse(target.exists())
        command = [sys.executable, '-B', str(ROOT/'scripts/verify_cache_research.py'),
                   '--capture-dir', str(target), '--json']
        result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8')
        self.assertEqual(result.returncode, 2)
        self.assertFalse(json.loads(result.stdout)['ok'])
        self.assertIn('FAIL cache research:', result.stderr)
        self.assertFalse(target.exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
