-- Whole entry through mission/ship/settings with source APIs that throw.
-- Only external memory and native-hook boundaries are substituted.
local ROOT,DIR=assert(arg[1]),assert(arg[2])
local ffi=require('ffi')
local P=dofile(ROOT..'/src/profile.lua')
local H=dofile(ROOT..'/src/hook.lua')
local function u32(n)
    local b={};for i=1,4 do b[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(b)
end
local function u64(n)return u32(n%4294967296)..u32(math.floor(n/4294967296))end
local function put(s,o,b)return s:sub(1,o)..b..s:sub(o+#b+1)end
local GAME,OBJECT,MODE,DESC=0x10000000,0x50000000,0x60000000,0x70000000
local data={[GAME+P.mission_scope.game_global]=u64(OBJECT),[GAME+P.mission_scope.mode_global]=u64(MODE),
    [DESC]=string.rep('\0',8)..u32(77)..u32(101)}
for _,pin in ipairs(P.mission_scope.pins)do data[GAME+pin.rva]=H.bytes(pin.hex)end
local header=put(string.rep('\0',0x44),8,u32(1));header=put(header,0x38,u64(DESC))
data[MODE]=put(header,0x40,u32(1))
local function scene(n)data[OBJECT+P.mission_scope.state_offset]=u32(n)end
TEST_MEMORY={}
function TEST_MEMORY.module(name)assert(name=='game.dll');return GAME end
function TEST_MEMORY.address(p)return tonumber(ffi.cast('uintptr_t',p))end
function TEST_MEMORY.verify_build(p)return p.game_sha256==P.game_sha256 end
function TEST_MEMORY.read(p,n)
    local s=data[TEST_MEMORY.address(p)]
    assert(s and #s>=n,'composed entry touched equipment/source memory')
    return s:sub(1,n)
end
TEST_NATIVE={active=false,installed=false,blocked=0,enables=0,disables=0}
function TEST_NATIVE.configure(mask)
    assert(mask==1,'optional filter activated in primary-only package')
    TEST_NATIVE.enables=TEST_NATIVE.enables+1;TEST_NATIVE.active=true;TEST_NATIVE.installed=true
    return true
end
function TEST_NATIVE.disable()
    TEST_NATIVE.disables=TEST_NATIVE.disables+1;TEST_NATIVE.active=false;TEST_NATIVE.installed=false;return true
end
function TEST_NATIVE.audit()return true end
local source_calls=0
local function forbidden()source_calls=source_calls+1;error('source engine query executed in isolation')end
stingray={Script={temp_byte_count=forbidden,set_temp_byte_count=forbidden},
    Application={main_world=forbidden},Network={game_session=forbidden,peer_id=forbidden},
    GameSession={in_session=forbidden,objects_owned_by=forbidden}}
CowboyBingusModLoader={log_directory=DIR}
BingusTranslations={version=1,serial=0,packs={},game_language='en',steam_language=false}
local ID='primary_pickup_tools.primary_pickup_blocker.enabled_v2'
local other='primary_pickup_tools.primary_pickup_blocker.team_support'
local values,callbacks,registered={[other]=true},{},0
ModOptionsMenu={api=1,version=3}
function ModOptionsMenu.register_option(id,spec)
    assert(id==ID);registered=registered+1;values[id]=spec.default;return true
end
function ModOptionsMenu.get(id)assert(id==ID,'unregistered old option queried');return values[id]end
function ModOptionsMenu.on_change(id,fn)callbacks[id]=fn end
local forwarded=0
update=function()forwarded=forwarded+1;return 'previous',nil end
local file=assert(io.open(ROOT..'/build/addon.lua','r'));local src=file:read('*a');file:close()
local function replace_once(text,from,to)
    local a,b=assert(text:find(from,1,true))
    assert(not text:find(from,b+1,true));return text:sub(1,a-1)..to..text:sub(b+1)
end
src=replace_once(src,'local memory=bingus_memory.new(bingus_runtime)','local memory=TEST_MEMORY')
src=replace_once(src,'local native=hook_factory.new(windows_factory.new(memory,near_allocator,note),profile,native_blob)',
    'local native=TEST_NATIVE')
scene(4)
local c=assert(loadstring(src,'mission-isolation-entry'))()
for i=1,20000 do local a,b=update(0.016);assert(a=='previous'and b==nil)end
assert(c.active and c.in_mission and c.mask==1 and registered==1 and source_calls==0)
assert(forwarded==20000 and TEST_NATIVE.enables==1)
assert(not c.set_option('team_support',true) and values[other]==true,'optional saved value changed')
values[ID]=false;callbacks[ID](false);update(0.016);assert(not c.active)
values[ID]=true;callbacks[ID](true);update(0.016);assert(c.active)
scene(3);update(0.016);assert(not c.active and source_calls==0)
scene(4);update(0.016);assert(c.active and source_calls==0)
shutdown()
local status=assert(io.open(DIR..'/PrimaryPickupBlocker-STATUS.txt','r'))
local text=status:read('*a');status:close()
assert(text:find('source_observer=not_included\n',1,true)and text:find('source_engine_calls=0\n',1,true))
print('PASS composed mission entry: 20000 frames, primary-only mask, source APIs/source reads absent, existing optional value untouched')
