-- Synthetic engine heap; no game memory or engine functions.
local ffi=require('ffi')
local M={}
function M.u32(n)
    local s={};for i=1,4 do s[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(s)
end
function M.u64(n)return M.u32(n%4294967296)..M.u32(math.floor(n/4294967296))end
function M.f32(n)local f=ffi.new('float[1]',n);return ffi.string(f,4)end
function M.bytes(h)return(h:gsub('..',function(x)return string.char(tonumber(x,16))end))end
function M.new(root,zone)
    zone=zone or 0
    local P=dofile(root..'/src/profile.lua')
    local f={P=P,regions={},writes={},reads=0,supported=true,present=true,
        game=0x10000000,player=0x20000000,manager=0x21000000,rows=0x22000000,
        targets=0x23000000,target_rows=0x24000000,target_descriptors=0x25000000,
        state=0x26000000,mode=0x27000000,mode_descriptor=0x28000000}
    f.row=f.rows+2*0x880;f.descriptor=f.manager+0x3200
    function f.map(a,n,initial)
        f.regions[#f.regions+1]={a=a,s=initial or string.rep('\0',n)}
    end
    function f.get(a,n)
        for _,r in ipairs(f.regions)do
            if a>=r.a and a+n<=r.a+#r.s then return r.s:sub(a-r.a+1,a-r.a+n)end
        end
    end
    function f.put(a,s)
        for _,r in ipairs(f.regions)do
            if a>=r.a and a+#s<=r.a+#r.s then
                local o=a-r.a;r.s=r.s:sub(1,o)..s..r.s:sub(o+#s+1);return
            end
        end
        error(string.format('unmapped fixture write %X (%d)',a,#s))
    end
    local function global(a,value)f.map(f.game+a,8,M.u64(value))end
    global(P.player_global,f.player);global(P.cache.interactor_global,f.manager)
    global(P.interactable_global,f.targets);global(P.mission_scope.game_global,f.state)
    global(P.mission_scope.mode_global,f.mode)
    f.map(f.game+P.cache.invalid_request_target,4,M.u32(0))
    for _,list in ipairs({P.pins,P.mission_scope.pins})do
        for _,pin in ipairs(list)do f.map(f.game+pin.rva,#pin.hex/2,M.bytes(pin.hex))end
    end
    for _,v in ipairs({{f.player,0x400},{f.manager,0x4000},{f.rows,4*0x880},
        {f.targets,0x14080},{f.target_rows,8*0x370},{f.target_descriptors,0x1000},
        {f.mode,0x50},{f.mode_descriptor,24}})do f.map(v[1],v[2])end
    f.map(f.state+P.mission_scope.state_offset,4,M.u32(4))
    f.put(f.mode+8,M.u32(1));f.put(f.mode+0x38,M.u64(f.mode_descriptor));f.put(f.mode+0x40,M.u32(1))
    f.put(f.mode_descriptor+8,M.u32(99)..M.u32(101))
    f.put(f.player+0x88,M.u32(1));f.put(f.player+0x3a8,M.u32(329))
    f.put(f.manager+0x1c,M.u32(3));f.put(f.manager+0x28,M.u64(f.manager+0x1000))
    f.put(f.manager+0x30,M.u32(8)..M.u32(0)..M.u32(1))
    f.put(f.manager+0x40,M.u64(f.manager+0x2000));f.put(f.manager+0x48,M.u64(f.rows))
    for i=0,2 do
        local entity=75+i;local desc=f.manager+0x3000+i*0x100
        f.put(f.manager+0x2000+i*8,M.u64(desc))
        f.put(desc,M.u64(123)..M.u32(entity)..M.u32(4196913+i)..M.u32(i==2 and 329 or 330+i)..M.u32(1))
        f.put(f.manager+0x1000+(entity%8)*8,M.u32(entity)..M.u32(i))
        f.put(f.rows+i*0x880+0x834,'\1')
    end
    f.put(f.targets,string.rep('\255',0x4000))
    f.put(f.targets+0x14000,M.u64(f.targets)..M.u32(2048)..M.u32(0xffffffff)..M.u32(2))
    f.put(f.targets+0x14018,M.u64(f.targets+0x4000))
    f.put(f.targets+0x14040,M.u32(2))
    f.put(f.targets+0x14050,M.u64(f.targets+0x11000))
    f.put(f.targets+0x14058,M.u32(8)..M.u32(0)..M.u32(1))
    f.put(f.targets+0x14068,M.u64(f.target_descriptors));f.put(f.targets+0x14070,M.u64(f.target_rows))
    function f.target(i,kind,z,score)
        z=z or 0;score=score or 10-i
        local entity,slot=100+i,5+i
        local spatial=f.targets+0x4000+slot*20
        local payload=f.targets+0xe000+slot*12
        local row=f.target_rows+i*0x370;local desc=f.target_descriptors+0x100+i*0x40
        f.put(f.targets+0x11000+(entity%8)*8,M.u32(entity)..M.u32(i))
        f.put(f.target_descriptors+i*8,M.u64(desc))
        f.put(desc,M.u64(777+i)..M.u32(entity)..M.u32(55+i)..M.u32(200+i)..M.u32(1))
        f.put(row+0x340,M.u32(z+1));f.put(row+0x364,M.u32(1))
        f.put(row+z*0x68+0x40,M.u32(slot)..M.u32(kind))
        f.put(row+z*0x68+0x60,'\1');f.put(row+z*0x68+0x66,'\0')
        f.put(payload,M.u32(entity)..M.u32(z)..M.f32(score))
        f.put(spatial,M.f32(1+i)..M.f32(2)..M.f32(3)..M.u32(slot)..M.u32(slot))
        f.put(f.targets+(slot*2)*8,M.u32(slot)..M.u32(slot))
        return spatial,payload,row
    end
    f.primary,f.primary_payload,f.primary_row=f.target(0,1)
    f.support,f.support_payload,f.support_row=f.target(1,3,zone)
    f.put(f.row,M.u64(f.primary));f.put(f.row+8,M.u64(f.primary_payload)..M.u64(f.support_payload))
    f.put(f.row+0x808,M.u32(2))
    -- Two other locally owned actors are deliberately near the same objects.
    f.put(f.rows,M.u64(f.primary));f.put(f.rows+0x880,M.u64(f.primary))
    f.memory={windows={kernel32={GetCurrentProcess=function()return ffi.cast('void *',-1)end}}}
    function f.memory.module(name)assert(name=='game.dll');return f.present and ffi.cast('uint8_t *',f.game)or nil end
    function f.memory.address(p)return tonumber(ffi.cast('uintptr_t',p))end
    function f.memory.verify_build(profile)
        assert(profile.exe_sha256==P.exe_sha256 and profile.game_sha256==P.game_sha256)
        return f.supported,'unsupported game build'
    end
    function f.memory.read(p,n)
        assert(type(p)=='cdata','untyped pointer at read boundary')
        f.reads=f.reads+1
        if f.on_read then f.on_read(f.memory.address(p),n)end
        return f.get(f.memory.address(p),n)
    end
    function f.memory.writable_data(a,n)return a==f.row and n==8 and not f.readonly end
    f.writer={}
    function f.writer.replace(a,before,after,validate)
        if f.on_validate then f.on_validate()end
        if not f.memory.writable_data(a,8)then return false,'target is not private RW data' end
        if not validate()then return false,'snapshot changed' end
        if f.get(a,8)~=before then return false,'selection changed' end
        assert(a==f.row and #after==8,'write outside the one local retained pointer')
        f.writes[#f.writes+1]={address=a,before=before,after=after};f.put(a,after)
        return true
    end
    function f.scene(n)f.put(f.state+P.mission_scope.state_offset,M.u32(n))end
    function f.collect()f.put(f.row,M.u64(f.primary))end
    f.backend=dofile(root..'/src/cache_backend.lua').new(f.memory,f.writer,P)
    return f
end
return M
