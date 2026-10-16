local ROOT=assert(arg[1])
local TEST_DIR=assert(arg[2])
-- Exact entry. Default ON waits safely when the game module is absent.
CowboyBingusModLoader={log_directory=TEST_DIR}
BingusTranslations={version=1,serial=0,packs={},game_language='zh-Hans',steam_language=false}
local specs,callbacks,applied={},{},{}
local ID='primary_pickup_tools.primary_pickup_blocker.enabled_v2'
local registrations=0
ModOptionsMenu={api=1,version=3,
    register_option=function(id,value)
        specs[id]=value
        registrations=registrations+1;applied[id]=value.default;return true
    end,
    on_change=function(id,fn)callbacks[id]=fn end,
    get=function(id)return applied[id]end}
local previous_calls=0
update=function(...)
    previous_calls=previous_calls+1
    return 4,nil,'original',nil
end
local c=assert(loadfile(ROOT..'/build/addon.lua'))()
assert(c.version=='0.2.2')
local a,b,d,e=update(0.016,'extra argument')
assert(a==4 and b==nil and d=='original' and e==nil and previous_calls==1,'update return forwarding')
assert(registrations==6 and c.registered and c.enabled and not c.active)
local spec=specs[ID]
assert(spec.default==true and spec.type=='toggle')
assert(spec.label()=='禁止捡起地面主武器' and spec.mod()=='交互过滤','Chinese locale')
assert(c.mask==1 and c.filters.team_support==false and c.filters.info==false,'new defaults')
local again=assert(loadfile(ROOT..'/build/addon.lua'))()
assert(again==c and registrations==6,'reload duplicated entry')
assert(rawget(_G,'ModBindingsMenu')==nil,'unexpected hotkey dependency')
BingusTranslations.game_language='en';BingusTranslations.serial=1
assert(spec.label()=='Block ground primary pickups','English locale')
applied[ID]=true;callbacks[ID](true)
-- This process does not host game.dll: no native installation can occur.
assert(c.enabled and not c.active and c.reason:find('not ready',1,true),'missing modules incorrectly active')
applied[ID]=false;callbacks[ID](false)
assert(not c.enabled and not c.active)
for i=1,100 do update(0.25)end
assert(c.in_mission==false and c.origin_published==0 and c.origin_reads==0,'unknown state executed source reader')
local status=assert(io.open(TEST_DIR..'/PrimaryPickupBlocker-STATUS.txt','r'))
local content=status:read('*a');status:close()
assert(content:find('filter.primary=false\n',1,true) and content:find('filter.team_support=false\n',1,true) and
    content:find('filter.info=false\n',1,true),'six applied values missing in status')
shutdown()
print('PASS exact entry, six rows, Chinese/English, primary ON/others OFF, reload, forwarding, missing game modules')
