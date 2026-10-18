local ROOT=assert(arg[1])
local F=dofile(ROOT..'/tests/cache_fixture.lua')
local Guard=dofile(ROOT..'/src/mission_guard.lua')
local function make()local f=F.new(ROOT);return f,Guard.new(f.memory,f.P)end
local checks=0
for _,state in ipairs({0,1,2,3,5,6,7,8,99})do
    local f,g=make();f.scene(state);assert(not g.poll()and not g.mission and not g.epoch);checks=checks+1
end
for _,count in ipairs({0,2,0xffffffff})do
    local f,g=make();f.put(f.mode+8,F.u32(count));assert(not g.poll());checks=checks+1
end
for _,kind in ipairs({0,8,99})do
    local f,g=make();f.put(f.mode+0x40,F.u32(kind));assert(not g.poll());checks=checks+1
end
local f,g=make();assert(g.poll()and g.mission);local epoch=g.epoch
f.put(f.mode_descriptor+8,F.u32(88));assert(g.poll()and g.epoch~=epoch)
f,g=make();f.present=false;assert(not g.poll())
f,g=make();f.supported=false;assert(not g.poll())
f,g=make();f.put(f.game+f.P.mission_scope.pins[1].rva,'\0');assert(not g.poll())
print('PASS '..(checks+5)..' mission scope checks: unknown/ship/load/mode/count/build/epoch/native evidence')
