-- Per-frame local retained-target filtering. All engine reads go through RPM.
-- Spatial records and payloads are distinct; no pointer survives a step.
local ffi=require('ffi')
local bit=require('bit')
local M={}
local HIGH=4294967296
local ZERO=string.rep('\0',8)
local float=ffi.new('float[1]')
local function u32(s,o)
    local a,b,c,d=s:byte(o+1,o+4);return a+b*256+c*65536+d*16777216
end
local function pointer(s,o)
    o=o or 0
    local n=u32(s,o)+u32(s,o+4)*HIGH
    return n>=65536 and n<140737488355328 and n or nil
end
local function f32(s,o)
    ffi.copy(float,s:sub(o+1,o+4),4);return tonumber(float[0])
end
local function bytes(h)return(h:gsub('..',function(v)return string.char(tonumber(v,16))end))end
-- Exact low 32 bits even when the full product exceeds Lua's 53-bit integers.
local function multiply(a,b)
    return ((a%65536)*b+math.floor(a/65536)*(b%65536)*65536)%HIGH
end
function M.new(memory,writer,profile)
    local h={active=false,installed=false,blocked=0,mask=0,
        stats={frames=0,local_matches=0,primary_seen=0,support_seen=0,replaced=0,cleared=0,
            refused=0,write_failures=0,last_type=-1,last_candidate_count=0,reason='off'}}
    local base,ready
    local S=profile.cache
    local function read(a,n,watch)
        if not a or a<65536 or a+n>=140737488355328 then return nil end
        local s=memory.read(ffi.cast('uint8_t *',a),n)
        if not s or #s~=n then return nil end
        if watch then watch[#watch+1]={a,s} end
        return s
    end
    local function ptr_at(a,watch)local s=read(a,8,watch);return s and pointer(s)end
    local function pinned()
        for _,p in ipairs(profile.pins)do
            if read(base+p.rva,#p.hex/2)~=bytes(p.hex)then
                return false,string.format('native evidence changed at %X',p.rva)
            end
        end
        return true
    end
    function h.audit()
        if not h.active then return true end
        local ok,why=pinned()
        if not ok then h.active=false;ready=false;h.stats.reason=why end
        return ok,why
    end
    function h.disable()
        -- Let the next native collector restore its own selection. Never replay
        -- a pointer saved before a death, despawn, row move or mission change.
        h.active=false;h.mask=0;h.stats.reason='off'
        return true
    end
    function h.configure(mask)
        if mask==0 then return h.disable()end
        if mask~=1 then return false,'unsupported filter mask' end
        if not ready then
            local module=memory.module('game.dll')
            if not module then return false,'game modules not ready' end
            local ok,why=memory.verify_build(profile)
            if not ok then return false,why or 'unsupported game build' end
            base=memory.address(module)
            ok,why=pinned();if not ok then return false,why end
            ready=true
        end
        h.mask=mask;h.active=true;h.stats.reason='waiting for local selection'
        return true
    end
    local function hash_index(header,key,offset,limit,watch)
        local buckets=pointer(header,offset)
        local capacity,empty,mul=u32(header,offset+8),u32(header,offset+12),u32(header,offset+16)
        if not buckets or capacity<2 or capacity>S.max_hash or bit.band(capacity,capacity-1)~=0 or
            key==empty then return nil end
        local start=multiply(key,mul)%capacity
        -- A corrupted/full hash must not stall the game. A long chain fails open.
        for j=0,math.min(capacity-1,S.max_probes-1)do
            local cell=read(buckets+((start+j)%capacity)*8,8,watch)
            if not cell then return nil end
            local found=u32(cell,0)
            if found==key then
                local index=u32(cell,4)
                return index<limit and index or nil
            end
            if found==empty then return nil end
        end
        return nil
    end
    local function context(watch)
        local player=ptr_at(base+profile.player_global,watch)
        local local_count=player and read(player+0x88,4,watch)
        local local_id=player and read(player+0x3a8,4,watch)
        if not local_count or u32(local_count,0)~=1 or not local_id then return nil,'local avatar unavailable' end
        local network=u32(local_id,0)
        if network==0x7fff then return nil,'local avatar unavailable' end
        local manager=ptr_at(base+S.interactor_global,watch)
        local header=manager and read(manager,0x50,watch)
        if not header then return nil,'interactor manager unavailable' end
        local count=u32(header,0x1c)
        local descriptors,rows=pointer(header,0x40),pointer(header,0x48)
        if count<1 or count>S.max_actors or not descriptors or not rows then return nil,'interactor bounds' end
        local pointers=read(descriptors,count*8,watch)
        if not pointers then return nil,'interactor descriptors unavailable' end
        local actor
        for i=0,count-1 do
            local address=pointer(pointers,i*8)
            local descriptor=address and read(address,24,watch)
            if not descriptor then return nil,'interactor descriptor unreadable' end
            if u32(descriptor,0x10)==network and bit.band(u32(descriptor,0x14),1)==1 then
                if actor then return nil,'ambiguous local avatar' end
                actor={index=i,descriptor=address,entity=u32(descriptor,8)}
            end
        end
        if not actor then return nil,'no owned local interactor' end
        if hash_index(header,actor.entity,0x28,count,watch)~=actor.index then return nil,'local entity map mismatch' end
        local row=rows+actor.index*0x880
        local data=read(row,0x880,watch)
        if not data or data:byte(0x835)~=1 then return nil,'local interactor inactive' end
        -- Follow the native +0x820 target-ID sentinel; the other result fields
        -- may retain bytes even when no request is pending. Do not clear them.
        local invalid=read(base+S.invalid_request_target,4,watch)
        if not invalid or u32(data,0x820)~=u32(invalid,0) then return nil,'pending interaction' end
        local candidates=u32(data,0x808)
        if candidates>S.max_candidates then return nil,'candidate bounds' end
        local target_manager=ptr_at(base+profile.interactable_global,watch)
        local target_header=target_manager and read(target_manager+0x14000,0x80,watch)
        if not target_header then return nil,'interactable manager unavailable' end
        -- Native constructor embeds 2048 spatial slots and 2048 payload slots.
        if pointer(target_header,0)~=target_manager or u32(target_header,8)~=S.slots or
            u32(target_header,12)~=0xffffffff or u32(target_header,16)~=2 or
            pointer(target_header,24)~=target_manager+0x4000 then return nil,'spatial pool layout mismatch' end
        local targets=u32(target_header,0x40)
        if targets<1 or targets>S.max_targets or not pointer(target_header,0x68) or
            not pointer(target_header,0x70)then return nil,'interactable bounds' end
        return {manager=manager,actor=actor,row=row,data=data,count=candidates,network=network,
            target_manager=target_manager,header=target_header,targets=targets},'local selection ready'
    end
    local function candidate(c,payload,watch)
        local manager,head=c.target_manager,c.header
        if not payload then return nil,'missing payload pointer' end
        local slot=(payload-manager-0xe000)/12
        if slot<0 or slot>=S.slots or slot%1~=0 then return nil,'payload slot bounds' end
        local pair=read(payload,12,watch)
        if not pair then return nil,'payload unreadable' end
        local entity,zone=u32(pair,0),u32(pair,4)
        local index=hash_index(head,entity,0x50,c.targets,watch)
        if not index then return nil,'target entity map mismatch' end
        local desc=ptr_at(pointer(head,0x68)+index*8,watch)
        local descriptor=desc and read(desc,24,watch)
        local at=pointer(head,0x70)+index*0x370
        local runtime=read(at,0x370,watch)
        if not descriptor or u32(descriptor,8)~=entity or not runtime then return nil,'target descriptor/runtime mismatch' end
        local zones,mode=u32(runtime,0x340),u32(runtime,0x364)
        if zones<1 or zones>8 or zone>=zones or mode>2 then return nil,'target zone/mode bounds' end
        local owned=bit.band(u32(descriptor,0x14),1)==1
        if (mode==0 and not owned)or(mode==2 and owned)then return nil,'target ownership mode' end
        local z=zone*0x68
        local spatial_index=u32(runtime,z+0x40)
        if spatial_index~=slot then return nil,'target zone slot mismatch' end
        local spatial=manager+0x4000+spatial_index*20
        local record=read(spatial,20,watch)
        if not record or u32(record,16)~=slot then return nil,'spatial record slot mismatch' end
        local key=u32(record,12)
        if key>=S.slots then return nil,'spatial record removed' end
        -- Cell keys can repeat; search by both key and slot, like native remove.
        local found=false
        for j=0,S.max_probes-1 do
            local bucket=read(manager+((key*2+j)%S.slots)*8,8,watch)
            if not bucket then return nil,'grid bucket unreadable' end
            if u32(bucket,0)==key and u32(bucket,4)==slot then found=true;break end
            if u32(bucket,0)==0xffffffff then break end
        end
        if not found then return nil,'spatial record not in grid' end
        local kind=u32(runtime,z+0x44)
        if kind<1 or kind>50 then return nil,'unknown interaction type' end
        local score=f32(pair,8)
        if score~=score or score==math.huge or score==-math.huge then return nil,'invalid candidate score' end
        return {spatial=spatial,raw=pair,kind=kind,entity=entity,zone=zone,score=score,
            eligible=runtime:byte(z+0x61)==1 and runtime:byte(z+0x67)==0 and score>0}
    end
    local function selected(c,watch)
        local spatial=pointer(c.data)
        if not spatial then return nil,'no retained target' end
        local slot=(spatial-c.target_manager-0x4000)/20
        if slot<0 or slot>=S.slots or slot%1~=0 then return nil,'retained spatial bounds' end
        local value,why=candidate(c,c.target_manager+0xe000+slot*12,watch)
        if not value then return nil,why end
        if value.spatial~=spatial then return nil,'retained spatial mapping changed' end
        return value
    end
    local function allow_type(c,kind)
        local count=u32(c.data,0x878)
        if count>16 then return false end
        if count==0 then return true end
        for i=0,count-1 do if u32(c.data,0x838+i*4)==kind then return true end end
        return false
    end
    local function encode_pointer(n)
        local out={}
        for i=1,8 do out[i]=string.char(n%256);n=math.floor(n/256) end
        return table.concat(out)
    end
    local function refuse(reason)
        h.stats.reason=reason;h.stats.refused=h.stats.refused+1
    end
    function h.step()
        if not h.active or h.mask~=1 then return end
        local d=h.stats;d.frames=d.frames+1
        local c,why=context()
        if not c then return refuse(why)end
        d.local_matches=d.local_matches+1;d.last_network_id=c.network;d.last_actor_entity=c.actor.entity
        d.last_candidate_count=c.count
        local current,invalid=selected(c)
        if not current then d.reason=invalid;return end
        d.last_type=current.kind
        if current.kind~=1 then d.reason='allowed retained target';return end
        d.primary_seen=d.primary_seen+1
        local best,best_payload
        for i=0,c.count-1 do
            local payload=pointer(c.data,8+i*8)
            local target=candidate(c,payload)
            if target then
                if target.kind==3 then d.support_seen=d.support_seen+1 end
                if target.kind~=1 and target.eligible and allow_type(c,target.kind) and
                    (not best or target.score>best.score)then best,best_payload=target,payload end
            end
        end
        local desired=best and encode_pointer(best.spatial)or ZERO
        local expected=c.data:sub(1,8)
        -- Reacquire the actor and validate only the selected/replacement objects.
        -- This snapshot and its readback exist only in this synchronous callback.
        local function validate()
            local watch={}
            local fresh=context(watch)
            if not fresh or fresh.row~=c.row or fresh.data~=c.data or fresh.network~=c.network or
                fresh.manager~=c.manager or fresh.target_manager~=c.target_manager or
                fresh.actor.descriptor~=c.actor.descriptor or fresh.actor.entity~=c.actor.entity then return false end
            local original=selected(fresh,watch)
            if not original or original.kind~=1 or original.raw~=current.raw then return false end
            if best then
                local replacement=candidate(fresh,best_payload,watch)
                if not replacement or replacement.spatial~=best.spatial or replacement.raw~=best.raw or
                    replacement.kind==1 or not replacement.eligible or not allow_type(fresh,replacement.kind) then return false end
            end
            for _,w in ipairs(watch)do if read(w[1],#w[2])~=w[2]then return false end end
            return true
        end
        local ok,reason=writer.replace(c.row,expected,desired,validate)
        if not ok then
            d.write_failures=d.write_failures+1
            h.active=false;h.mask=0;ready=false
            return refuse('writer stopped: '..tostring(reason))
        end
        h.blocked=h.blocked+1
        local action=best and 'replaced' or 'cleared';d[action]=d[action]+1;d.reason=action
    end
    return h
end
return M
