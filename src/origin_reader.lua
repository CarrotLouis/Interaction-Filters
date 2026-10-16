-- Bounded, read-only current-build component enumeration. No World/Unit calls.
-- Engine signatures come from the reference's Application/Network/GameSession
-- calls. Save/restore the script temporary arena around every query batch.
local M={}
local ffi=require('ffi')
local AVATAR='4d1c334d294dfa97'
local function u32(s,o)
    local a,b,c,d=s:byte(o+1,o+4);return a+b*256+c*65536+d*16777216
end
local function ptr(s,o)
    local lo,hi=u32(s,o),u32(s,o+4)
    local n=lo+hi*4294967296
    return n>=65536 and n<140737488355328 and n or nil
end
local function type_hash(s)
    return string.format('%08x%08x',u32(s,4),u32(s,0))
end
local function mul32(a,b)
    local al,ah=a%65536,math.floor(a/65536)
    local bl,bh=b%65536,math.floor(b/65536)
    return (al*bl+((ah*bl+al*bh)%65536)*65536)%4294967296
end
local function pow2(n)
    if n<1 or n>1048576 then return false end
    while n>1 do if n%2~=0 then return false end;n=n/2 end
    return true
end
function M.new(memory,profile,env,scope)
    assert(scope and type(scope.mission)=='boolean','mission scope required')
    local reader={reason='waiting for supported game',generation=0}
    local game
    local reads,bytes,fault=0,0,nil
    local function read(a,n)
        if fault then return nil end
        if not a or a<65536 or a+n>=140737488355328 or n<1 or n>262144 then
            fault='source address or read bounds changed';return nil
        end
        reads,bytes=reads+1,bytes+n
        reader.reads,reader.bytes=reads,bytes
        if reads>2048 or bytes>4194304 then fault='source read budget exceeded';return nil end
        local b=memory.read(ffi.cast('uint8_t *',a),n)
        if not b or #b~=n then fault='source memory unavailable';return nil end
        return b
    end
    local function pointer_at(a)local s=read(a,8);return s and ptr(s,0)end
    local function lookup(address,key)
        local h=read(address,20);if not h then return nil,'unreadable'end
        local rows,cap,empty,mult=ptr(h,0),u32(h,8),u32(h,12),u32(h,16)
        if cap==0 then return nil,'absent'end
        if not rows or not pow2(cap)then return nil,'unreadable'end
        local start=mul32(key,mult)
        for j=0,math.min(cap,512)-1 do
            local row=read(rows+((start+j)%cap)*8,8)
            if not row then return nil,'unreadable'end
            local found,value=u32(row,0),u32(row,4)
            if found==key then return value~=4294967295 and value or nil,'found'end
            if found==empty then return nil,'absent'end
        end
        return nil,'unreadable'
    end
    local function attachment(entity,attach,entities)
        if not attach or not entities then return nil end
        local index,why=lookup(attach+0x18,entity)
        if not index then return why=='absent' and 'free' or nil end
        if index>=32768 then return nil end
        local rows=pointer_at(attach+0x38)
        local raw=rows and read(rows+index*0xac,12)
        if not raw then return nil end
        local unit=u32(raw,0)
        if unit==0 or unit==4294967295 then return 'free'end
        local owner=lookup(entities+0xf22ec8,unit)
        if not owner or owner>=262144 then return nil end
        local desc=read(entities+0xf32f18+owner*24,24)
        if not desc or u32(desc,12)~=unit then return nil end
        return type_hash(desc)==AVATAR and 'carried' or 'pod'
    end
    local function ownership_queries(wanted)
        local sr=rawget(env,'stingray')
        local net=sr and sr.Network;local gs=sr and sr.GameSession;local app=sr and sr.Application
        if not net or not gs or not app or type(app.main_world)~='function' or
           type(net.game_session)~='function' or type(net.peer_id)~='function' or
           type(gs.in_session)~='function' or type(gs.objects_owned_by)~='function' then return nil,nil,nil end
        local world_ok,world=pcall(app.main_world)
        if not world_ok then return nil,nil,nil end
        if world==nil then return nil,nil,false end
        if not wanted then return nil,nil,tostring(world)end
        local ok,session=pcall(net.game_session)
        if not ok or session==nil then return nil,nil,tostring(world) end
        local inside,present=pcall(gs.in_session,session)
        if not inside or present~=true then return nil,nil,tostring(world) end
        local peer_ok,peer=pcall(net.peer_id)
        if not peer_ok or peer==nil then return nil,tostring(session),tostring(world)end
        local owned_ok,list=pcall(gs.objects_owned_by,session,peer)
        if not owned_ok or type(list)~='table' then return nil,tostring(session),tostring(world)end
        local owned={}
        for _,id in pairs(list)do if type(id)=='number' and id>0 and id<4294967295 then owned[id]=true end end
        return owned,tostring(session),tostring(world)
    end
    local function ownership(wanted)
        local sr=rawget(env,'stingray');local script=sr and sr.Script
        if not script or type(script.temp_byte_count)~='function' or type(script.set_temp_byte_count)~='function' then
            return nil,nil,nil,'script temporary arena API unavailable'
        end
        local saved_ok,saved=pcall(script.temp_byte_count)
        if not saved_ok or type(saved)~='number' or saved<0 then
            return nil,nil,nil,'script temporary arena could not be saved'
        end
        local ok,owned,session,world=pcall(ownership_queries,wanted)
        local restored=pcall(script.set_temp_byte_count,saved)
        if not restored then
            reader.arena_failed=true
            return nil,nil,nil,'source monitor disabled: script temporary arena could not be restored'
        end
        if not ok then return nil,nil,nil,'ownership query failed'end
        return owned,session,world
    end
    function reader.snapshot(elapsed)
        reads,bytes,fault=0,0,nil
        reader.reads,reader.bytes=0,0
        if not scope.mission then reader.reason=scope.reason or 'waiting for mission';return {active=false}end
        if reader.arena_failed then return nil end
        if not game then
            local base=memory.module('game.dll')
            if not base then return nil end
            local ok=memory.verify_build(profile)
            if not ok then reader.reason='unsupported game build';return nil end
            game=memory.address(base)
        end
        if type(elapsed)~='number' or elapsed<20 then
            reader.reason='source monitor warming up (20 seconds)';return nil
        end
        local manager=pointer_at(game+0x3326d68)
        local head=manager and read(manager+0x14030,80)
        if not head then reader.reason=fault or 'interactable header unavailable';return nil end
        local cap,count=u32(head,8),u32(head,16)
        local descriptors,records=ptr(head,56),ptr(head,64)
        if count>cap or cap>8192 or count>4096 or (count>0 and (not descriptors or not records))then
            reader.reason='interactable bounds changed';return nil
        end
        local pointers=count>0 and read(descriptors,count*8)or ''
        if not pointers then reader.reason=fault or 'interactable descriptors unavailable';return nil end
        local attach=pointer_at(game+0x3326698)
        local entities=pointer_at(game+0x346bf98)
        local items={};local carried_gear=false
        for batch=0,count-1,128 do
            local n=math.min(128,count-batch)
            local block=read(records+batch*0x370,n*0x370)
            if not block then reader.reason=fault or 'interactable records unavailable';return nil end
            for j=0,n-1 do
                local offset=j*0x370;local zones=u32(block,offset+0x340)
                if zones>8 then reader.reason='zone count changed';return nil end
                local support,gear=false,false
                for z=0,zones-1 do
                    local kind=u32(block,offset+z*0x68+0x44)
                    if kind==3 then support,gear=true,true
                    elseif kind==28 then gear=true end
                end
                if gear then
                    local index=batch+j
                    local descriptor=ptr(pointers,index*8)
                    local raw=descriptor and read(descriptor,24)
                    if raw then
                        local entity,unit,goid=u32(raw,8),u32(raw,12),u32(raw,16)
                        local actual=lookup(manager+0x14050,entity)
                        if entity>0 and entity~=4294967295 and unit>0 and unit~=0x7fff and unit~=4294967295 and actual==index then
                            local side=attachment(entity,attach,entities)
                            if side=='carried' or side=='pod'then carried_gear=true end
                            if support then
                                items[#items+1]={entity=entity,unit=unit,goid=goid,record=records+index*0x370,
                                    free=side=='free',carried=side=='carried',podded=side=='pod'}
                            end
                        end
                    end
                end
            end
        end
        if fault then reader.reason=fault;return nil end
        -- A component-array relocation/count change makes the entire snapshot
        -- transient. The native cache also checks each candidate's current row.
        local final=read(manager+0x14030,80)
        if not final or u32(final,8)~=cap or u32(final,16)~=count or
           ptr(final,56)~=descriptors or ptr(final,64)~=records then
            reader.reason=fault or 'interactable changed during snapshot';return nil
        end
        if #items==0 then
            reader.reason='no support equipment: engine queries skipped'
            return {active=true,epoch=scope.epoch..':'..tostring(manager),owned=nil,items=items,carried_gear=carried_gear}
        end
        local owned,session,world,problem=ownership(true)
        if world==false then
            reader.session,reader.world=nil,nil
            reader.reason='no main world';return {active=false}
        end
        if world==nil then reader.reason=problem or 'world context unavailable';return nil end
        if reader.world and reader.world~=world then reader.generation=reader.generation+1 end
        reader.world=world
        if session then
            -- A host migration may replace the session while retaining this world.
            -- The reference keeps original caller history for the world's lifetime.
            reader.session=session
        end
        reader.reason=#items==0 and 'no support equipment' or
            (owned and 'observing source ownership' or 'ownership unavailable: unknown sources allowed')
        return {active=true,epoch=scope.epoch..':'..tostring(manager),owned=owned,items=items,carried_gear=carried_gear}
    end
    return reader
end
return M
