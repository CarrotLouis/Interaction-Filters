-- Feed the shipped decoder and controller real-shaped synthetic GameState data.
-- System adapter counts allocations/code writes; engine tables throw on ship calls.
local ROOT=assert(arg[1])
local ffi=require('ffi')
local Guard=dofile(ROOT..'/src/mission_guard.lua')
local Controller=dofile(ROOT..'/src/controller.lua')
local Hook=dofile(ROOT..'/src/hook.lua')
local P=dofile(ROOT..'/src/profile.lua')
local B=dofile(ROOT..'/src/native_blob.lua')
local function u32(n)
    local s={};for i=1,4 do s[i]=string.char(n%256);n=math.floor(n/256)end
    return table.concat(s)
end
local function u64(n)return u32(n%4294967296)..u32(math.floor(n/4294967296))end
local function put(s,o,v)return s:sub(1,o)..v..s:sub(o+#v+1)end
local GAME,OBJECT,MODE,DESC=0x10000000,0x50000000,0x60000000,0x70000000
local memory={present=true,supported=true,reads=0,data={}}
memory.data[GAME+P.mission_scope.game_global]=u64(OBJECT)
memory.data[GAME+P.mission_scope.mode_global]=u64(MODE)
for _,pin in ipairs(P.mission_scope.pins)do memory.data[GAME+pin.rva]=Hook.bytes(pin.hex)end
memory.data[DESC]=string.rep('\0',8)..u32(77)..u32(101)
function memory.module(name)assert(name=='game.dll');return memory.present and GAME or nil end
function memory.address(p)return tonumber(ffi.cast('uintptr_t',p))end
function memory.verify_build(profile)assert(profile==P);return memory.supported end
function memory.read(p,n)
    memory.reads=memory.reads+1;local s=memory.data[memory.address(p)]
    return s and s:sub(1,n)or nil
end
local function scene(state,count,kind,entity)
    memory.data[OBJECT+P.mission_scope.state_offset]=u32(state)
    local head=put(string.rep('\0',0x44),8,u32(count or 1))
    head=put(head,0x38,u64(DESC));head=put(head,0x40,u32(kind or 1))
    memory.data[MODE]=head
    memory.data[DESC]=string.rep('\0',8)..u32(entity or 77)..u32(101)
end
local gate=Guard.new(memory,P)
memory.present=false;assert(not gate.poll() and gate.reason:find('not ready',1,true))
memory.present=true;memory.supported=false;assert(not gate.poll() and gate.reason=='unsupported game build')
memory.supported=true
for _,state in ipairs({0,1,2,3,5,6,7,8,99})do
    scene(state);assert(not gate.poll() and not gate.mission and gate.epoch==nil)
end
for _,count in ipairs({0,2,4294967295})do scene(4,count);assert(not gate.poll())end
for _,kind in ipairs({0,8,99})do scene(4,1,kind);assert(not gate.poll())end
scene(4);assert(gate.poll() and gate.mission and gate.state=='Mission')
local old_epoch=gate.epoch;scene(4,1,1,88);assert(gate.poll() and gate.epoch~=old_epoch)
memory.data[DESC]=nil;assert(not gate.poll() and gate.reason=='mission identity unavailable')
scene(3)
local adapter={allocations=0,writes=0,control=0}
local data={}
for _,pin in ipairs(P.pins)do data[GAME+pin.rva]=Hook.bytes(pin.hex)end
local site=GAME+P.patch_rva;data[site]=Hook.bytes(P.original)
function adapter.verify_build()return GAME end
function adapter.read(a,n)return data[a]end
function adapter.prepare()adapter.allocations=adapter.allocations+1;return {},0x20000000 end
function adapter.set_control(_,v)adapter.control=v end
function adapter.compare_exchange(a,before,after)
    assert(data[a]==before);data[a]=after;adapter.writes=adapter.writes+1;return true
end
function adapter.counter()return 0 end
local hook=Hook.new(adapter,P,B)
local values,callbacks={},{ }
local menu={api=1,version=3}
function menu.register_option(id,spec)values[id]=spec.default;return true end
function menu.get(id)return values[id]end
function menu.on_change(id,fn)callbacks[id]=fn end
local c=Controller.new({ModOptionsMenu=menu},hook,function(k)return k end,function()end,function()end)
c.set_scope(false,'not checked','Unknown')
local function step()
    gate.poll();c.set_scope(gate.mission,gate.reason,gate.state);c.step()
end
for i=1,5000 do step()end
assert(c.enabled and c.filters.primary and not c.active and not hook.installed)
assert(adapter.allocations==0 and adapter.writes==0,'ship allocated/modified native code')
callbacks[Controller.OPTION](true)
assert(adapter.allocations==0 and adapter.writes==0,'ship APPLY installed native hook')
scene(4);step()
assert(c.active and hook.installed and adapter.allocations==1 and adapter.writes==1)
local patch=data[site]
scene(6);step()
assert(not c.active and not hook.installed and data[site]==Hook.bytes(P.original) and adapter.control==false)
scene(4);step()
assert(c.active and adapter.allocations==1 and data[site]==patch,'mission resume lost settings/reallocated')
scene(3);step()
assert(not c.active and c.enabled and data[site]==Hook.bytes(P.original))
c.stop('test end')
local bad=Guard.new(memory,P)
memory.data[GAME+P.mission_scope.pins[1].rva]='broken'
assert(not bad.poll() and bad.reason=='mission-state native consumer changed')
print('PASS mission guard: ship/menu/load/unknown no native allocation or code write; mission auto-enable and restore; empty/fault/identity/pins')
