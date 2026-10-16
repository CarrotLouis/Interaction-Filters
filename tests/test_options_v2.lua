local ROOT=assert(arg[1])
local C=dofile(ROOT..'/src/controller.lua')
local env={};local calls=0
local h={active=false,installed=false,blocked=0}
function h.configure(mask)h.mask=mask;h.active=mask~=0;h.installed=h.active;calls=calls+1;return true end
function h.disable()h.active=false;h.installed=false;return true end
function h.audit()return true end
local values,callbacks,specs={},{},{}
values['primary_pickup_tools.primary_pickup_blocker.enabled']=false
local registrations=0
env.ModOptionsMenu={api=1,version=3,
    register_option=function(id,spec)registrations=registrations+1;specs[id]=spec;if values[id]==nil then values[id]=spec.default end;return true end,
    get=function(id)return values[id]end,on_change=function(id,cb)callbacks[id]=cb end}
local c=C.new(env,h,function(k)return k end,function()end,function()end)
c.step()
assert(registrations==6 and c.mask==1 and c.active,'primary ON / legacy migration')
for i=2,6 do assert(specs[C.DEFS[i].id].default==false)end
for i=2,6 do
    local d=C.DEFS[i];values[d.id]=true;callbacks[d.id](true)
    assert(c.filters[d.key] and c.mask==2^i-1,'wrong closure/mask')
end
assert(c.mask==63)
values[C.OPTION]=false;callbacks[C.OPTION](false)
assert(c.mask==62 and c.active,'primary OFF disabled another option')
for i=2,6 do local d=C.DEFS[i];values[d.id]=false;callbacks[d.id](false)end
assert(c.mask==0 and not c.active and not h.installed)
local again=C.new(env,h,function(k)return k end,function()end,function()end)
again.step();assert(again.mask==0 and not again.active,'manual OFF not saved')
assert(not again.set_option('unknown',true) and not again.set_option('info','true'))
values[C.DEFS[6].id]=true;again.step();assert(again.mask==32 and again.active)
again.pause('test');assert(not again.active and not h.installed)
again.step();assert(again.mask==32 and again.active)
again.stop('shutdown');assert(not again.active and not h.installed)
print('PASS six independent switches, closure capture, defaults, migration, saved OFF, pause and shutdown')
