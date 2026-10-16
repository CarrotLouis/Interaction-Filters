-- Synthetic current-build memory, fed to the unmodified shipped reader.
-- Engine query functions are doubles; no game process or native object calls.
local ROOT=assert(arg[1])
local ffi=require('ffi')
local Reader=dofile(ROOT..'/src/origin_reader.lua')
local Origins=dofile(ROOT..'/src/support_origins.lua')
local P=dofile(ROOT..'/src/profile.lua')
local function u32(n)
    local a={}
    for i=1,4 do a[i]=string.char(n%256);n=math.floor(n/256)end
    return table.concat(a)
end
local function u64(n)return u32(n%4294967296)..u32(math.floor(n/4294967296))end
local function unhex(h)return(h:gsub('..',function(v)return string.char(tonumber(v,16))end))end
local function mul32(a,b)
    local al,ah=a%65536,math.floor(a/65536)
    local bl,bh=b%65536,math.floor(b/65536)
    return (al*bl+((ah*bl+al*bh)%65536)*65536)%4294967296
end
local function put(s,o,v)return s:sub(1,o)..v..s:sub(o+#v+1)end
local GAME,MANAGER,DESC,ROWS,IHASH,ATTACH,AROWS,AHASH,ENTITIES,UHASH=
    0x10000000,0x52000000,0x51000000,0x53000000,0x57000000,
    0x54000000,0x55000000,0x56000000,0x70000000,0x73000000
local FIRST=0xffffff11
local function fixture(count)
    count=count or 4
    local f={segments={},calls={},present=true,supported=true,session='S1',world='W1',owned={[5001]=true},arena=64}
    local function add(a,s)f.segments[a]=s end
    function f.replace(a,s)assert(f.segments[a]);add(a,s)end
    local function hashmap(header,rows,entries,cap)
        local slots=string.rep(u32(4294967295)..u32(4294967295),cap)
        local used={};local mult=2654435761
        for _,v in ipairs(entries)do
            local slot=mul32(v[1],mult)%cap
            while used[slot]do slot=(slot+1)%cap end
            used[slot]=true;slots=put(slots,slot*8,u32(v[1])..u32(v[2]))
        end
        add(header,u64(rows)..u32(cap)..u32(4294967295)..u32(mult))
        add(rows,slots)
    end
    add(GAME+0x3326d68,u64(MANAGER));add(GAME+0x3326698,u64(ATTACH))
    add(GAME+0x346bf98,u64(ENTITIES))
    local pointers,records,descriptors,imap={},{},{},{}
    for i=0,count-1 do
        local entity=i==0 and FIRST or 77+i
        pointers[#pointers+1]=u64(DESC+i*24)
        descriptors[#descriptors+1]=string.rep('\x11',8)..u32(entity)..u32(1000+i)..u32(5000+i)..u32(1)
        local row=put(string.rep('\0',0x370),0x340,u32(1))
        row=put(row,0x44,u32(count==4 and i==3 and 1 or 3))
        records[#records+1]=row;imap[#imap+1]={entity,i}
    end
    add(DESC,table.concat(descriptors));add(ROWS,table.concat(records))
    add(MANAGER+0x14068,u64(0x58000000));add(0x58000000,table.concat(pointers))
    local head=string.rep('\0',80)
    head=put(head,8,u32(count));head=put(head,16,u32(count))
    head=put(head,56,u64(0x58000000));head=put(head,64,u64(ROWS))
    add(MANAGER+0x14030,head)
    local cap=8;while cap<count*2 do cap=cap*2 end
    hashmap(MANAGER+0x14050,IHASH,imap,cap)
    -- The hashmap overlaps the manager header; provide one consistent header.
    head=put(head,32,f.segments[MANAGER+0x14050])
    add(MANAGER+0x14030,head);f.segments[MANAGER+0x14050]=nil
    -- Entity owner map resolves parent UNIT ids to inline 24-byte descriptors.
    local avatar_unit,pod_unit=0xf0000311,0xf0000422
    hashmap(ENTITIES+0xf22ec8,UHASH,{{avatar_unit,0},{pod_unit,1}},8)
    add(ENTITIES+0xf32f18,unhex('97fa4d294d331c4d')..u32(900)..u32(avatar_unit)..u32(9000)..u32(1)..
        string.rep('\x22',8)..u32(901)..u32(pod_unit)..u32(9001)..u32(1))
    hashmap(ATTACH+0x18,AHASH,{{78,0},{79,1}},8)
    add(ATTACH+0x38,u64(AROWS))
    add(AROWS,u32(pod_unit)..string.rep('\0',0xac-4)..u32(avatar_unit)..string.rep('\0',0xac-4))
    local memory={}
    function memory.module(name)assert(name=='game.dll');return f.present and GAME or nil end
    function memory.verify_build(p)assert(p==P);return f.supported end
    function memory.address(p)return tonumber(ffi.cast('uintptr_t',p))end
    function memory.read(pointer,n)
        local address=memory.address(pointer)
        if f.on_read then f.on_read(address,n)end
        for base,s in pairs(f.segments)do
            if address>=base and address+n<=base+#s then return s:sub(address-base+1,address-base+n)end
        end
        return nil
    end
    local function call(name)f.calls[#f.calls+1]=name end
    local env={stingray={Script={
        temp_byte_count=function()call('temp_save');return f.arena end,
        set_temp_byte_count=function(saved)
            call('temp_restore')
            if f.restore_error then error('temporary arena refusal')end
            f.arena=saved
        end,
    },Application={main_world=function()call('world');f.arena=f.arena+128;return f.world end},Network={
        game_session=function()call('session');return f.session end,
        peer_id=function()call('peer');return 7 end,
    },GameSession={
        in_session=function(s)call('in_session');assert(s==f.session);return true end,
        objects_owned_by=function(s,p)
            call('owned');assert(s==f.session and p==7)
            f.arena=f.arena+256
            if f.ownership_error then error('transient ownership failure')end
            local list={};for id in pairs(f.owned)do list[#list+1]=id end;return list
        end,
    }}}
    f.scope={mission=true,epoch='mission-1',reason='Mission'}
    f.reader=Reader.new(memory,P,env,f.scope)
    f.env=env
    local snapshot=f.reader.snapshot
    function f.reader.snapshot(elapsed)return snapshot(elapsed==nil and 20 or elapsed)end
    return f
end
local f=fixture()
f.present=false;assert(f.reader.snapshot()==nil and #f.calls==0)
f.present=true;f.supported=false
assert(f.reader.snapshot()==nil and #f.calls==0 and f.reader.reason=='unsupported game build')
f.supported=true
assert(f.reader.snapshot(0)==nil and #f.calls==0,'startup made engine queries')
assert(f.reader.snapshot(19.9)==nil and #f.calls==0,'startup grace ended early')
f.world=nil
assert(f.reader.snapshot().active==false and f.arena==64,'missing world/arena restoration')
f.world='W1';f.calls={}
local s=f.reader.snapshot()
assert(s.active and #s.items==3 and s.items[1].entity==FIRST)
assert(s.items[1].free and s.items[2].podded and s.items[3].carried)
assert(s.items[2].record==ROWS+0x370 and s.owned[5001] and not s.owned[5002])
assert(table.concat(f.calls,',')=='temp_save,world,session,in_session,peer,owned,temp_restore' and f.arena==64)
local history=Origins.new()
history.observe(s,0)
local result=history.observe(f.reader.snapshot(),1.6)
local classes={};for _,v in ipairs(result)do classes[v.entity]=v.class end
assert(classes[FIRST]==Origins.FIELD and classes[78]==Origins.OWN and classes[79]==Origins.TEAM)
-- Ownership transfer and record-array relocation preserve the classified source.
f.owned={[5002]=true}
local head=f.segments[MANAGER+0x14030]
f.replace(MANAGER+0x14030,put(head,64,u64(ROWS+0x10000)))
f.segments[ROWS+0x10000]=f.segments[ROWS]
result=history.observe(f.reader.snapshot(),3)
assert(result[1].entity==78 and result[1].class==Origins.OWN and result[1].record==ROWS+0x10000+0x370)
-- A read fault invalidates the whole publication; no further engine calls.
local old=f.segments[DESC];f.segments[DESC]=nil
local before=#f.calls
assert(f.reader.snapshot()==nil and #f.calls==before and f.reader.reason=='source memory unavailable')
f.segments[DESC]=old
f.ownership_error=true;s=f.reader.snapshot()
assert(s.active and s.owned==nil and s.epoch==history.epoch and f.arena==64,'error path leaked temporary arena')
f.ownership_error=false;f.session='S2'
assert(f.reader.snapshot().epoch==history.epoch,'same-world session/host transfer erased origin')
result=history.observe(f.reader.snapshot(),5)
assert(result[2].entity==79 and result[2].class==Origins.TEAM,'host transfer reclassified teammate weapon')
-- An initially missing session becoming ready must not erase map history.
local delayed=fixture();delayed.session=nil
local early=delayed.reader.snapshot();delayed.session='ready'
assert(delayed.reader.snapshot().epoch==early.epoch)
local old_epoch=delayed.reader.snapshot().epoch
delayed.world='W2'
delayed.scope.epoch='mission-2'
assert(delayed.reader.snapshot().epoch~=old_epoch,'changed world reused old origins')
local no_arena=fixture();no_arena.env.stingray.Script=nil
assert(no_arena.reader.snapshot()==nil and #no_arena.calls==0,'queried without arena protection')
local broken_arena=fixture();broken_arena.restore_error=true
assert(broken_arena.reader.snapshot()==nil and broken_arena.reader.arena_failed)
local calls=#broken_arena.calls
assert(broken_arena.reader.snapshot()==nil and #broken_arena.calls==calls,'continued after arena restore failure')
local no_gear=fixture()
local block=no_gear.segments[ROWS]
for i=0,3 do block=put(block,i*0x370+0x44,u32(1))end
no_gear.replace(ROWS,block)
assert(#no_gear.reader.snapshot().items==0 and
    #no_gear.calls==0,'unneeded engine queries on empty support list')
-- A carried/podded backpack ends map-start loading without being a filter row.
local pack_only=fixture()
local pack_rows=pack_only.segments[ROWS]
for i=0,3 do pack_rows=put(pack_rows,i*0x370+0x44,u32(i==1 and 28 or 1))end
pack_only.replace(ROWS,pack_rows)
local pack_state=pack_only.reader.snapshot()
assert(#pack_state.items==0 and pack_state.carried_gear and
    #pack_only.calls==0,'pack boundary/source cache')
local ship=fixture();ship.scope.mission=false;ship.scope.reason='waiting for mission: Ship'
local ship_reads=0;ship.on_read=function()ship_reads=ship_reads+1 end
assert(ship.reader.snapshot().active==false and #ship.calls==0 and ship_reads==0,'ship touched source memory/engine APIs')
-- Malformed component bounds and zones refuse the snapshot before engine queries.
for _,change in ipairs({function(g)
    local h=g.segments[MANAGER+0x14030];g.replace(MANAGER+0x14030,put(h,16,u32(5)))
end,function(g)
    g.replace(ROWS,put(g.segments[ROWS],0x340,u32(9)))
end})do
    local g=fixture();change(g);assert(g.reader.snapshot()==nil and #g.calls==0)
end
local changed=fixture();local header_reads=0
changed.on_read=function(a)
    if a==MANAGER+0x14030 then
        header_reads=header_reads+1
        if header_reads==2 then changed.replace(a,put(changed.segments[a],16,u32(3)))end
    end
end
assert(changed.reader.snapshot()==nil and #changed.calls==0,'churning arrays published')
local large=fixture(1024)
local exhausted=large.reader.snapshot()
assert(exhausted==nil and large.reader.reason=='source read budget exceeded' and #large.calls==0,
    tostring(large.reader.reason)..' reads='..tostring(large.reader.reads)..' calls='..#large.calls)
assert(large.reader.reads==2049 and large.reader.bytes<=4194304)
print('PASS shipped source reader: component joins, ownership, startup, world/session, temporary arena, faults and budgets')
