-- Composed production source; replace only the OS memory and write boundary.
-- The actual mission decoder, controller, backend, translations and guard run.
local ROOT,DIR=assert(arg[1]),assert(arg[2])
local F=dofile(ROOT..'/tests/cache_fixture.lua')
local f=F.new(ROOT)
TEST_MEMORY=f.memory;TEST_WRITER=f.writer
CowboyBingusModLoader={log_directory=DIR}
BingusTranslations={version=1,serial=0,packs={},game_language='zh-Hans',steam_language=false}
local ID='primary_pickup_tools.primary_pickup_blocker.enabled_v2'
local other='primary_pickup_tools.primary_pickup_blocker.team_support'
local values,callbacks,specs={[other]=true},{},{}
local registrations,forwarded,source_calls=0,0,0
ModOptionsMenu={api=1,version=3}
function ModOptionsMenu.register_option(id,spec)
    assert(id==ID);registrations=registrations+1;specs[id]=spec
    if values[id]==nil then values[id]=spec.default end
    return true
end
function ModOptionsMenu.get(id)assert(id==ID);return values[id]end
function ModOptionsMenu.on_change(id,fn)callbacks[id]=fn end
local function forbidden()source_calls=source_calls+1;error('engine API must not be called')end
stingray={Application={main_world=forbidden},Network={game_session=forbidden},
    Script={temp_byte_count=forbidden},GameSession={objects_owned_by=forbidden}}
update=function(dt,extra)
    forwarded=forwarded+1;assert(extra=='forward')
    f.collect() -- An earlier Lua mod changes the cache: our AFTER must see it.
    return 4,nil,'previous',nil
end
local function replaced(text,from,to)
    local a,b=assert(text:find(from,1,true));assert(not text:find(from,b+1,true))
    return text:sub(1,a-1)..to..text:sub(b+1)
end
local file=assert(io.open(ROOT..'/build/addon.lua','r'));local src=file:read('*a');file:close()
src=replaced(src,'local memory=bingus_memory.new(bingus_runtime)','local memory=TEST_MEMORY')
src=replaced(src,'writer_factory.new(memory)','TEST_WRITER')
local c=assert(loadstring(src,'composed-cache-entry'))()
for i=1,20000 do
    local a,b,d,e=update(0.016,'forward')
    assert(a==4 and b==nil and d=='previous'and e==nil)
    assert(f.get(f.row,8)==F.u64(f.support),'after callback lost to lower Lua update')
end
assert(c.active and c.in_mission and c.mask==1 and registrations==1 and forwarded==20000 and source_calls==0)
assert(specs[ID].default==true and specs[ID].label()=='禁止捡起地面主要武器')
assert(not c.set_option('team_support',true)and values[other]==true,'optional saved value changed')
values[ID]=false;callbacks[ID](false)
local writes=#f.writes
for i=1,1000 do update(0.016,'forward')end
assert(#f.writes==writes and f.get(f.row,8)==F.u64(f.primary),'OFF wrote old pointers')
values[ID]=true;callbacks[ID](true);f.scene(3)
for i=1,12000 do update(0.016,'forward')end
assert(not c.active and #f.writes==writes,'ship performed filter writes')
f.scene(4);update(0.016,'forward');assert(c.active and #f.writes==writes+1)
f.put(f.player+0x3a8,F.u32(0x7fff));update(0.016,'forward')
assert(#f.writes==writes+1,'dead avatar wrote cached address')
f.put(f.player+0x3a8,F.u32(400));f.put(f.descriptor+0x10,F.u32(400))
update(0.016,'forward');assert(#f.writes==writes+2,'reinforcement did not resume')
shutdown();local final=#f.writes
update(0.016,'forward');assert(#f.writes==final and not c.active,'shutdown resumed writes')
local status=assert(io.open(DIR..'/PrimaryPickupBlocker-STATUS.txt','r'));local text=status:read('*a');status:close()
assert(text:find('build_id=0.3.0-cache-primary.1\n',1,true))
assert(text:find('backend.replaced=20002\n',1,true),'final filtering count not serialized')
assert(text:find('runtime_profile=local_retained_cache\n',1,true))
print('PASS composed cache entry: 20000 filtered frames, 12000 ship frames, OFF, after ordering, settings, death/reinforcement, final status and shutdown')
