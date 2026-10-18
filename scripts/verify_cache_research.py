"""Read-only evidence check for a possible data-only interaction backend.

The withdrawn wrapper treated a retained spatial record as a candidate payload.
This checker preserves that distinction and the native update order. It reads
only the small checked-in fixture, or explicitly supplied retained code sections.
It never opens a process, writes a file, or enables packaging.

Required: Python 3.10+ and capstone (requirements-dev.txt). Missing prerequisites
or mismatching evidence exit 2. --json gives a machine-readable result.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

FIXTURE = Path(__file__).resolve().parents[1] / 'tests/fixtures/cache_consumers.json'
BLOCKS = {'selected_payload': (0x9A49E0, 0x9A4AAC),
          'manual_interact': (0x9A4750, 0x9A49E0),
          'zone_available': (0x97B7F0, 0x97B8B3)}
CALLS = {'actor_update': (0x5731CA, 0x829E90),
         'actions': (0x82A4A0, 0xA3E620),
         'interact_action': (0xA3E985, 0xA61F80),
         'action_start': (0xA622E5, 0xA62310),
         'manual_start': (0xA624BF, 0x9A4750),
         'interactor_update': (0x573281, 0x9A3440),
         'collect': (0x9A35F6, 0x9A05B0),
         'manual_request': (0x9A4981, 0x979570)}
LUA_DLL_SHA256 = '2c8720c9f446c848436ad993b1a88099d76f0b0b09df53689719b797c3039ce7'
LUA_IMPORTS = [(0x13F7938, 'lua_settop'), (0x13F7A10, 'lua_gettop'),
               (0x13F7A28, 'lua_pushnumber'), (0x13F7A78, 'lua_pushstring'),
               (0x13F79F0, 'lua_rawget'), (0x13F7948, 'lua_insert'),
               (0x13F7998, 'lua_pcall')]


def load_fixture():
    return json.loads(FIXTURE.read_text(encoding='utf-8'))


def lua_exports(path):
    """Read the pinned DLL export directory; never load or execute the DLL."""
    import struct
    raw = Path(path).read_bytes()
    if hashlib.sha256(raw).hexdigest() != LUA_DLL_SHA256:
        raise ValueError('unsupported Lua DLL for import-name proof')
    pe = struct.unpack_from('<I', raw, 60)[0]
    count = struct.unpack_from('<H', raw, pe+6)[0]
    optional = struct.unpack_from('<H', raw, pe+20)[0]
    sections = [struct.unpack_from('<IIII', raw, pe+24+optional+i*40+8)
                for i in range(count)]
    def read(at, size):
        for _, start, length, offset in sections:
            if start <= at and at+size <= start+length:
                return raw[offset+at-start:offset+at-start+size]
        raise ValueError('Lua DLL export outside file sections')
    export = struct.unpack_from('<I', raw, pe+24+112)[0]
    _, names_count, functions, names, ordinals = struct.unpack_from('<IIIII', read(export, 40), 20)
    result = {}
    for index in range(names_count):
        name_at = struct.unpack('<I', read(names+index*4, 4))[0]
        name = read(name_at, 96).split(b'\0', 1)[0].decode('ascii')
        ordinal = struct.unpack('<H', read(ordinals+index*2, 2))[0]
        result[name] = struct.unpack('<I', read(functions+ordinal*4, 4))[0]
    return result


def verify(data, capture_dir=None, lua_dll=None):
    try:
        import capstone
    except ImportError as exc:
        raise ValueError('capstone is required; install requirements-dev.txt. '
                         'No live-game access is needed.') from exc
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
    md.detail = True
    if data['schema'] != 1 or data['steam_build'] != '25480438':
        raise ValueError('unsupported cache-research fixture')
    pins = {pin['name']: pin for pin in data['pins']}
    if len(pins) != len(data['pins']):
        raise ValueError('duplicate native pin')
    if set(data['blocks']) != set(BLOCKS):
        raise ValueError('unexpected native block catalog')
    chunks = []
    for name, (start, end) in BLOCKS.items():
        block = data['blocks'][name]
        raw = bytes.fromhex(block['hex'])
        if int(block['rva'], 16) != start or len(raw) != end - start:
            raise ValueError('native block bounds mismatch: ' + name)
        if hashlib.sha256(raw).hexdigest() != block['sha256']:
            raise ValueError('native block hash mismatch: ' + name)
        chunks.append(('game.dll', start, raw))
    for name, pin in pins.items():
        raw, at = bytes.fromhex(pin['hex']), int(pin['rva'], 16)
        instructions = list(md.disasm(raw, at))
        if len(instructions) != 1 or instructions[0].size != len(raw):
            raise ValueError('pin is not one complete instruction: ' + name)
        ins = instructions[0]
        if ins.mnemonic + ' ' + ins.op_str != pin['asm']:
            raise ValueError('native pin decode mismatch: ' + name)
        module = pin.get('module', 'game.dll')
        if module not in {'game.dll', 'helldivers2.exe'}:
            raise ValueError('unknown pin module: ' + name)
        for block_module, start, block in chunks:
            if module == block_module and start <= at < start + len(block):
                if block[at-start:at-start+len(raw)] != raw:
                    raise ValueError('pin/block disagreement: ' + name)
        chunks.append((module, at, raw))
    for name, (at, target) in CALLS.items():
        pin = pins[name]
        if pin.get('module', 'game.dll') != 'game.dll' or int(pin['rva'], 16) != at or pin['asm'] != 'call ' + hex(target):
            raise ValueError('native call chain mismatch: ' + name)
    if int(pins['actor_update']['rva'], 16) >= int(pins['interactor_update']['rva'], 16):
        raise ValueError('actor/collector native order changed')
    # These are separate loads: candidate payload != retained spatial record.
    facts = {'spatial_index': 'mov eax, dword ptr [rsi + 0x10]',
             'candidate_entity': 'mov eax, dword ptr [r11 + r12*4]',
             'candidate_append': 'mov qword ptr [r8 + rax*8 + 8], r12',
             'retained_source': 'mov r13, qword ptr [rsp + 0x78]',
             'retained_best': 'mov qword ptr [rbp - 0x48], r13',
             'retained_load': 'mov rdx, qword ptr [rbp - 0x48]',
             'retained_commit': 'mov qword ptr [r9], rdx',
             'consumer_index': 'mov eax, dword ptr [rcx + 0x10]',
             'consumer_payload': 'add rax, 0xe000'}
    for name, asm in facts.items():
        if pins[name]['asm'] != asm:
            raise ValueError('spatial/payload distinction lost: ' + name)
    order = {'script_update_call': ('helldivers2.exe', 0x689B98, 'call 0x1c6900'),
             'script_to_plugins': ('helldivers2.exe', 0x689BAF, 'jmp 0x60030'),
             'plugin_update_slot': ('helldivers2.exe', 0x60137, 'call qword ptr [rcx + 0x68]'),
             'game_plugin_world': ('game.dll', 0x4EE6E9, 'call 0xab5000'),
             'world_components': ('game.dll', 0xAB5EC9, 'call 0x571250'),
             'script_execute': ('helldivers2.exe', 0x1C6A9A, 'call 0x1c5700')}
    for name, expected in order.items():
        pin = pins[name]
        if (pin.get('module', 'game.dll'), int(pin['rva'], 16), pin['asm']) != expected:
            raise ValueError('normal-frame callback order changed: ' + name)
    rip_targets = {'game_update_address': 0x4EE6C0, 'game_update_register': 0x37CEB78,
                   'game_api_base': 0x37CEB10, 'script_update_name': 0x1678150,
                   'script_lookup': 0x13F79F0, 'script_pcall': 0x13F7998}
    for name, expected in rip_targets.items():
        pin = pins[name]
        ins = next(md.disasm(bytes.fromhex(pin['hex']), int(pin['rva'], 16)))
        targets = [ins.address+ins.size+op.mem.disp for op in ins.operands
                   if op.type == capstone.CS_OP_MEM and op.mem.base == capstone.x86.X86_REG_RIP]
        if targets != [expected]:
            raise ValueError('script/plugin binding changed: ' + name)
    if pins['script_global_index']['asm'] != 'mov edx, 0xffffd8ee':
        raise ValueError('script lookup no longer uses the Lua globals table')
    if [(int(item['iat_rva'], 16), item['name']) for item in data['lua_imports']] != LUA_IMPORTS:
        raise ValueError('unexpected Lua import catalog')
    if data['strings'] != [{'module': 'helldivers2.exe', 'rva': '0x1678150', 'hex': '75706461746500'}]:
        raise ValueError('unexpected script callback name')
    for string in data['strings']:
        chunks.append((string['module'], int(string['rva'], 16), bytes.fromhex(string['hex'])))
    capture = None
    import_proof = None
    if capture_dir is not None:
        sections = []
        for section in data['capture_sections']:
            path = Path(capture_dir) / section['name']
            raw = path.read_bytes()
            if len(raw) != section['bytes'] or hashlib.sha256(raw).hexdigest() != section['sha256']:
                raise ValueError('unsupported or incomplete retained section: ' + section['name'])
            sections.append((section['module'], int(section['rva'], 16), raw))
        def captured(module, at, size):
            for section_module, start, raw in sections:
                if module == section_module and start <= at and at+size <= start+len(raw):
                    return raw[at-start:at-start+size]
            raise ValueError('uncaptured evidence at ' + module + '+' + hex(at))
        for module, start, expected in chunks:
            if captured(module, start, len(expected)) != expected:
                raise ValueError('retained code disagrees at ' + hex(start))
        capture = {'verified_sections': len(sections), 'matched_ranges': len(chunks)}
        if lua_dll is not None:
            import struct
            exports = lua_exports(lua_dll)
            bases = set()
            for item in data['lua_imports']:
                slot = int(item['iat_rva'], 16)
                value = struct.unpack('<Q', captured('helldivers2.exe', slot, 8))[0]
                bases.add(value-exports[item['name']])
            if len(bases) != 1 or next(iter(bases)) <= 0 or next(iter(bases)) & 0xFFFF:
                raise ValueError('Lua imports do not resolve to one aligned module')
            import_proof = {'matched_imports': len(data['lua_imports']),
                            'lua_dll_sha256': LUA_DLL_SHA256}
    elif lua_dll is not None:
        raise ValueError('--lua-dll also requires --capture-dir')
    return {'ok': True, 'scope': 'offline research only', 'native_pins': len(pins),
            'native_blocks': len(BLOCKS), 'capture': capture,
            'lua_import_proof': import_proof,
            'candidate_and_retained_share_layout': False,
            'native_actor_precedes_collector': True,
            'normal_frame_lua_precedes_game_plugin': True,
            'all_native_update_paths_proven': False, 'lifetime_proven': False,
            'live_acceptance': False, 'packaging_allowed': False}


def self_test(data):
    cases = []
    changed = deepcopy(data)
    changed['blocks']['manual_interact']['hex'] = '90' + changed['blocks']['manual_interact']['hex'][2:]
    cases.append(changed)
    changed = deepcopy(data)
    changed['pins'][0]['asm'] = 'nop '
    cases.append(changed)
    changed = deepcopy(data)
    changed['steam_build'] = 'unknown'
    cases.append(changed)
    for changed in cases:
        try:
            verify(changed)
        except ValueError:
            continue
        raise ValueError('self-test accepted altered evidence')
    return len(cases)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture-dir', type=Path, help='explicit retained capture directory; read-only')
    parser.add_argument('--lua-dll', type=Path, help='optional pinned lua51.dll for import-name proof; only read, never loaded')
    parser.add_argument('--self-test', action='store_true', help='also reject three altered-evidence cases')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    try:
        data = load_fixture()
        result = verify(data, args.capture_dir, args.lua_dll)
        if args.self_test:
            result['negative_self_tests'] = self_test(data)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        if args.json:
            print(json.dumps({'ok': False, 'error': str(exc)}))
        print('FAIL cache research: ' + str(exc), file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"PASS {result['native_pins']} pins / {result['native_blocks']} blocks; offline research only.")
        print('Normal-frame order pinned; other update paths and lifetime remain unproven. Packaging stays forbidden.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
