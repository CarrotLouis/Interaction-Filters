-- Independent read-only decoder of the Runtime's current-build GameState facts.
-- No engine API calls. Only a proven Mission state + one GameMode record allows work.
local ffi=require('ffi')
local M={}
local function u32(s,o)
    local a,b,c,d=s:byte(o+1,o+4);return a+b*256+c*65536+d*16777216
end
local function ptr(s)
    local n=u32(s,0)+u32(s,4)*4294967296
    return n>=65536 and n<140737488355328 and n or nil
end
local function bytes(h)return(h:gsub('..',function(v)return string.char(tonumber(v,16))end))end
function M.new(memory,profile)
    local g={mission=false,reason='game modules not ready',state='Unknown',epoch=nil}
    local base
    local S=assert(profile.mission_scope,'mission scope profile required')
    local function read(a,n)
        if not a then return nil end
        local s=memory.read(ffi.cast('uint8_t *',a),n)
        return s and #s==n and s or nil
    end
    local function pointer(a)local s=read(a,8);return s and ptr(s)end
    local function fail(reason,state)
        g.mission=false;g.reason=reason;g.state=state or 'Unknown';g.epoch=nil
        return false,reason
    end
    function g.poll()
        if not base then
            local module=memory.module('game.dll')
            if not module then return fail('game modules not ready')end
            local ok=memory.verify_build(profile)
            if not ok then return fail('unsupported game build')end
            local address=memory.address(module)
            for _,pin in ipairs(S.pins)do
                if read(address+pin.rva,#pin.hex/2)~=bytes(pin.hex)then
                    return fail('mission-state native consumer changed')
                end
            end
            base=address
        end
        local manager=pointer(base+S.game_global)
        local raw=manager and read(manager+S.state_offset,4)
        if not raw then return fail('game state unavailable')end
        local state=u32(raw,0)
        local name=S.names[state+1]
        if not name then return fail('unknown game state '..state)end
        if state~=4 then return fail('waiting for mission: '..name,name)end
        local mode=pointer(base+S.mode_global)
        local header=mode and read(mode,0x44)
        if not header or u32(header,8)~=1 then return fail('mission mode not ready','Mission')end
        local kind=u32(header,0x40)
        if kind<1 or kind>7 then return fail('unknown mission mode','Mission')end
        local descriptor=ptr(header:sub(57,64))
        local row=descriptor and read(descriptor,16)
        if not row then return fail('mission identity unavailable','Mission')end
        g.mission=true;g.reason='Mission';g.state='Mission'
        g.epoch=tostring(mode)..':'..u32(row,8)..':'..u32(row,12)
        return true,g.reason
    end
    return g
end
return M
