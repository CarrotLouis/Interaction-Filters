from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
RESOURCE='mods/primary_pickup_tools/primary_pickup_blocker'
SHARED=['bingus_runtime','bingus_memory','bingus_text']

def assemble():
    vendor=ROOT/'vendor/shared'
    hashes=json.loads((vendor/'SHA256.json').read_text(encoding='utf-8'))
    source=f'-- HD2-Addon: {RESOURCE}\nif rawget(_G,"PrimaryPickupBlocker") then return rawget(_G,"PrimaryPickupBlocker") end\n'
    for name in SHARED:
        data=(vendor/(name+'.lua')).read_bytes()
        assert hashlib.sha256(data).hexdigest()==hashes[name], 'shared runtime copy modified: '+name
        source+=f'local {name}=(function()\n'+data.decode('utf-8')+'\nend)()\n'
    for name,file in [('profile','profile'),('native_blob','native_blob'),('locales','locales'),
                      ('near_allocator','near_allocator'),
                      ('mission_factory','mission_guard'),
                      ('origins_factory','support_origins'),('origin_reader_factory','origin_reader'),
                      ('windows_factory','windows'),('hook_factory','hook'),('controller_factory','controller')]:
        source+=f'local {name}=(function()\n'+(ROOT/'src'/f'{file}.lua').read_text(encoding='utf-8')+'\nend)()\n'
    source+=(ROOT/'src/entry.lua').read_text(encoding='utf-8')
    build=ROOT/'build'
    build.mkdir(exist_ok=True)
    (build/'addon.lua').write_text(source,encoding='utf-8',newline='\n')
    return source

if __name__=='__main__':
    data=assemble().encode('utf-8')
    print(f'Assembled {len(data)} bytes; SHA-256 {hashlib.sha256(data).hexdigest()}')
