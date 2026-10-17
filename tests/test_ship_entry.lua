-- Execute the composed entry with ONE replaced memory boundary, never engine state.
-- Ship runs for 12000 frames; prohibited source engine functions raise immediately.
local ROOT=assert(arg[1])
local ffi=require('ffi')
local P=dofile(ROOT..'/src/profile.lua')
local Hook=dofile(ROOT..'/src/hook.lua')
ffi.cdef [[void *ppb_ship_GetCurrentProcess(void) __asm__("GetCurrentProcess");]]
local kernel=ffi.load('kernel32')
local GAME,OBJECT=0x10000000,0x50000000
local function u32(n)
    local s={};for i=1,4 do s[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(s)
end
local function u64(n)return u32(n%4294967296)..u32(math.floor(n/4294967296))end
local data={}
data[GAME+P.mission_scope.game_global]=u64(OBJECT)
data[OBJECT+P.mission_scope.state_offset]=u32(3)
for _,pin in ipairs(P.mission_scope.pins)do data[GAME+pin.rva]=Hook.bytes(pin.hex)end
local reads,engine=0,0
TEST_MEMORY={windows={kernel32={GetCurrentProcess=function()return kernel.ppb_ship_GetCurrentProcess()end}}}
function TEST_MEMORY.module(name)assert(name=='game.dll');return GAME end
function TEST_MEMORY.address(p)return tonumber(ffi.cast('uintptr_t',p))end
function TEST_MEMORY.verify_build(profile)assert(profile.game_sha256==P.game_sha256);return true end
function TEST_MEMORY.read(p,n)
    reads=reads+1
    local bytes=data[TEST_MEMORY.address(p)]
    assert(bytes and #bytes>=n,'ship touched source data or native hook site')
    return bytes:sub(1,n)
end
local function forbidden()engine=engine+1;error('ship invoked source engine API')end
stingray={Script={temp_byte_count=forbidden,set_temp_byte_count=forbidden},
    Application={main_world=forbidden},Network={game_session=forbidden,peer_id=forbidden},
    GameSession={in_session=forbidden,objects_owned_by=forbidden}}
BingusTranslations={version=1,serial=0,packs={},game_language='en',steam_language=false}
local values,callbacks,registered={},{},0
ModOptionsMenu={api=1,version=3}
function ModOptionsMenu.register_option(id,spec)values[id]=spec.default;registered=registered+1;return true end
function ModOptionsMenu.get(id)return values[id]end
function ModOptionsMenu.on_change(id,fn)callbacks[id]=fn end
local original=0
update=function()original=original+1;return 'forwarded',nil end
local f=assert(io.open(ROOT..'/build/addon.lua','r'));local source=f:read('*a');f:close()
local from='local memory=bingus_memory.new(bingus_runtime)'
local start=assert(source:find(from,1,true))
assert(not source:find(from,start+1,true),'multiple memory boundaries')
local injected=source:sub(1,start-1)..'local memory=TEST_MEMORY'..source:sub(start+#from)
local c=assert(loadstring(injected,'ship-composed-entry'))()
for i=1,12000 do
    local a,b=update(0.016)
    assert(a=='forwarded' and b==nil)
end
assert(registered==1 and original==12000,'registered='..registered..' original='..original..' reason='..tostring(c.reason)..' guard='..c.guard.status.state)
assert(c.enabled and c.filters.primary and c.game_state=='Ship' and not c.active and not c.in_mission)
assert(c.runtime_profile=='primary_call_wrapper' and engine==0)
local id='primary_pickup_tools.primary_pickup_blocker.enabled_v2'
values[id]=true;callbacks[id](true)
update(0.016)
assert(c.filters.primary and not c.active and engine==0,'ship APPLY entered engine/native work')
shutdown()
print('PASS composed ship entry: 12000 frames, one primary setting, forwarding, zero source engine calls/source reads/hook-site access')
