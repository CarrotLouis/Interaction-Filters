-- Regression for the 2026-10-17 control test: loaded addon, saved primary OFF.
-- Keep the production entry/controller/hook; substitute reads and trap writes.
local ROOT,DIR=assert(arg[1]),assert(arg[2])
local ffi=require('ffi')
local P=dofile(ROOT..'/src/profile.lua')
local Hook=dofile(ROOT..'/src/hook.lua')
ffi.cdef [[void *ppb_disabled_GetCurrentProcess(void) __asm__("GetCurrentProcess");]]
local kernel=ffi.load('kernel32')
local GAME,OBJECT,MODE,DESC=0x10000000,0x50000000,0x60000000,0x70000000
local function u32(n)
    local b={};for i=1,4 do b[i]=string.char(n%256);n=math.floor(n/256)end
    return table.concat(b)
end
local function u64(n)return u32(n%4294967296)..u32(math.floor(n/4294967296))end
local function put(s,o,b)return s:sub(1,o)..b..s:sub(o+#b+1)end
local data={[GAME+P.mission_scope.game_global]=u64(OBJECT),
    [GAME+P.mission_scope.mode_global]=u64(MODE),
    [DESC]=string.rep('\0',8)..u32(77)..u32(101)}
for _,pin in ipairs(P.mission_scope.pins)do data[GAME+pin.rva]=Hook.bytes(pin.hex)end
data[MODE]=put(put(put(string.rep('\0',0x44),8,u32(1)),0x38,u64(DESC)),0x40,u32(1))
local function scene(n)data[OBJECT+P.mission_scope.state_offset]=u32(n)end
local reads,source_calls,write_calls=0,0,0
TEST_MEMORY={windows={kernel32={GetCurrentProcess=function()
    return kernel.ppb_disabled_GetCurrentProcess()
end}}}
function TEST_MEMORY.module(name)assert(name=='game.dll');return GAME end
function TEST_MEMORY.address(p)return tonumber(ffi.cast('uintptr_t',p))end
function TEST_MEMORY.verify_build(p)assert(p==P or p.game_sha256==P.game_sha256);return true end
function TEST_MEMORY.read(p,n)
    reads=reads+1
    local value=data[TEST_MEMORY.address(p)]
    assert(value and #value>=n,'disabled entry accessed source data or native hook code')
    return value:sub(1,n)
end
function TEST_FORBIDDEN_WRITE()
    write_calls=write_calls+1;error('disabled entry attempted native preparation or code mutation')
end
local function forbidden_source()
    source_calls=source_calls+1;error('disabled entry invoked a source engine API')
end
stingray={Script={temp_byte_count=forbidden_source,set_temp_byte_count=forbidden_source},
    Application={main_world=forbidden_source},Network={game_session=forbidden_source,peer_id=forbidden_source},
    GameSession={in_session=forbidden_source,objects_owned_by=forbidden_source}}
CowboyBingusModLoader={log_directory=DIR}
BingusTranslations={version=1,serial=0,packs={},game_language='en',steam_language=false}
local ID='primary_pickup_tools.primary_pickup_blocker.enabled_v2'
local values,callbacks,registered={[ID]=false},{},0
ModOptionsMenu={api=1,version=3}
function ModOptionsMenu.register_option(id,spec)
    assert(id==ID and spec.default==true);registered=registered+1
    if values[id]==nil then values[id]=spec.default end
    return true
end
function ModOptionsMenu.get(id)assert(id==ID);return values[id]end
function ModOptionsMenu.on_change(id,fn)callbacks[id]=fn end
local forwarded=0
update=function()forwarded=forwarded+1;return 'previous',nil,'tail' end
local f=assert(io.open(ROOT..'/build/addon.lua','r'));local source=f:read('*a');f:close()
local function replace_once(from,to)
    local a,b=assert(source:find(from,1,true));assert(not source:find(from,b+1,true))
    source=source:sub(1,a-1)..to..source:sub(b+1)
end
replace_once('local memory=bingus_memory.new(bingus_runtime)','local memory=TEST_MEMORY')
local creation='local native=hook_factory.new(windows_factory.new(memory,near_allocator,note),profile,native_blob)'
replace_once(creation,[[local adapter=windows_factory.new(memory,near_allocator,note)
adapter.verify_build=TEST_FORBIDDEN_WRITE
adapter.prepare=TEST_FORBIDDEN_WRITE
adapter.compare_exchange=TEST_FORBIDDEN_WRITE
local native=hook_factory.new(adapter,profile,native_blob)]])
scene(3)
local c=assert(loadstring(source,'disabled-composed-entry'))()
for i=1,12000 do local a,b,z=update(0.016);assert(a=='previous'and b==nil and z=='tail')end
scene(4)
for i=1,20000 do update(0.016)end
assert(c.in_mission and c.game_state=='Mission' and not c.enabled and not c.active and c.mask==0)
assert(c.guard.status.errors==0 and c.guard.running() and registered==1)
assert(write_calls==0 and source_calls==0 and reads>0)
callbacks[ID](false);update(0.016)
scene(3);update(0.016);scene(4);update(0.016)
assert(not c.enabled and not c.active and write_calls==0 and source_calls==0)
shutdown()
assert(write_calls==0 and forwarded==32003)
print('PASS saved-OFF composed entry: 12000 ship + 20000 mission frames, production hook, zero native prepare/install/restore and zero source queries')
