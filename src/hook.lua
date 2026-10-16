-- Native hook lifecycle. The adapter is the only system boundary; tests replace it.
local M={}
local function bytes(hex)return (hex:gsub('..',function(s)return string.char(tonumber(s,16))end))end
local function signed32(n)
    if n < -2147483648 or n > 2147483647 or n%1~=0 then return nil end
    if n<0 then n=n+4294967296 end
    local out={}
    for i=1,4 do out[i]=string.char(n%256);n=math.floor(n/256)end
    return table.concat(out)
end
function M.new(A,P,B)
    local h={installed=false,active=false,blocked=0,reason='off',mask=1,origin_rows={}}
    local original=bytes(P.original)
    local prepared,proven,site,patch
    local function sample()
        if not prepared then return end
        h.blocked=A.counter(prepared) or h.blocked
        if A.counters then h.counters=A.counters(prepared)end
        if A.native_stats then h.native_stats=A.native_stats(prepared)end
    end
    local function deactivate()
        h.active=false
        if prepared then A.set_control(prepared,false)end -- aligned u32, before removal
    end
    local function cleanup()
        if prepared and A.cleanup then
            local ok,why=A.cleanup(prepared)
            h.cleanup_pending=not ok
            if not ok then h.reason='off: '..tostring(why);return false,h.reason end
        end
        h.cleanup_pending=false
        return true
    end
    function h.disable()
        deactivate()
        sample() -- retain the last counts when shutdown writes STATUS
        local clean,problem=cleanup()
        if not h.installed then
            if not clean then return false,problem end
            h.reason='off';return true
        end
        local current=A.read(site,8)
        if current==original then
            h.installed=false
            if not clean then return false,problem end
            h.reason='off';return true
        end
        if current~=patch then
            -- Do not overwrite a change made by another addon. Our predicate is inert.
            h.reason='off: hook site changed externally';h.installed=false;return false,h.reason
        end
        local ok,why=A.compare_exchange(site,patch,original,prepared)
        if not ok then
            if A.read(site,8)==original then h.installed=false end
            cleanup()
            h.reason='off: restore pending: '..tostring(why);return false,h.reason
        end
        h.installed=false
        local done,why=cleanup()
        if not done then return false,why end
        h.reason='off';return true
    end
    function h.enable()
        if h.cleanup_pending then
            local ok,why=h.disable()
            if not ok then return false,why end
        end
        if h.installed then
            if A.read(site,8)~=patch then
                deactivate();h.installed=false;h.reason='candidate filter site changed externally'
                return false,h.reason
            end
            A.set_control(prepared,h.mask);h.active=true;h.reason='active';return true
        end
        if not proven then
            local game,why=A.verify_build(P)
            if not game then h.reason=why or 'game modules not ready';return false,h.reason end
            for _,pin in ipairs(P.pins)do
                if A.read(game+pin.rva,#pin.hex/2)~=bytes(pin.hex)then
                    h.reason='native instruction changed at '..string.format('%X',pin.rva)
                    return false,h.reason
                end
            end
            site=game+P.patch_rva
            if site%8~=0 or A.read(site,8)~=original then
                h.reason='candidate filter site is occupied or changed';return false,h.reason
            end
            local entry
            prepared,entry,why=A.prepare(game,P,B)
            if A.diagnostics then h.allocation=A.diagnostics()end
            if not prepared then h.reason=why or 'native allocation unavailable';return false,h.reason end
            local displacement=signed32(entry-(game+P.instruction_rva+5))
            if not displacement then
                deactivate();h.reason='native allocation outside near-jump range';return false,h.reason
            end
            patch=original:sub(1,3)..string.char(0xe9)..displacement
            proven=true
        end
        if A.read(site,8)~=original then
            h.reason='candidate filter site is occupied or changed';return false,h.reason
        end
        if A.publish_origins then A.publish_origins(prepared,h.origin_rows)end
        A.set_control(prepared,h.mask)
        local ok,why=A.compare_exchange(site,original,patch,prepared)
        if not ok then
            h.installed=A.read(site,8)==patch
            deactivate();h.reason=why or 'hook install refused';return false,h.reason
        end
        h.installed=true;h.active=true;h.reason='active';return true
    end
    function h.audit()
        sample()
        if h.installed and A.read(site,8)~=patch then
            deactivate();h.installed=false;h.reason='candidate filter site changed externally'
            return false,h.reason
        end
        return true
    end
    function h.configure(mask)
        assert(type(mask)=='number' and mask>=0 and mask<64 and mask%1==0,'invalid filter mask')
        h.mask=mask
        if mask==0 then return h.disable()end
        return h.enable()
    end
    function h.publish(rows)
        h.origin_rows=rows or {}
        if prepared and A.publish_origins then A.publish_origins(prepared,h.origin_rows)end
    end
    return h
end
M.bytes=bytes
return M
