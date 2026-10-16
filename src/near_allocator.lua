-- Near-code allocation over the complete signed rel32 window. No engine reads.
-- OS methods are injected so address-space fragmentation can be replayed offline.
local M={}
local function ceil(n,g)return math.ceil(n/g)*g end
local function floor(n,g)return math.floor(n/g)*g end
function M.bounds(instruction,size,limits)
    local origin=instruction+5
    local g=limits.granularity
    assert(g>=4096 and g%4096==0,'invalid allocation granularity')
    local low=ceil(math.max(origin-2147483648,limits.minimum),g)
    local high=floor(math.min(origin+2147483647,limits.maximum)+1,g)-1
    if high-low+1<size then return nil,'relative-jump window has no usable range'end
    return low,high,g
end
function M.allocate(OS,instruction,size)
    local low,high,g=M.bounds(instruction,size,OS.limits())
    if not low then return nil,{reason=high,queries=0,attempts=0,last_error=0}end
    local d={range_min=low,range_max=high,queries=0,attempts=0,free_regions=0,last_error=0}
    local function accept(p,backend)
        if not p then return nil end
        local delta=p-(instruction+5)
        if p<low or p+size-1>high or p%g~=0 or delta< -2147483648 or delta>2147483647 then
            OS.release(p);d.reason='allocator returned an out-of-range address';return nil
        end
        d.backend=backend;d.address=p;d.last_error=0
        return p
    end
    if OS.alloc2 then
        d.attempts=d.attempts+1
        local p,err=OS.alloc2(low,high,size)
        d.alloc2_error=err or 0;d.last_error=err or 0
        local chosen=accept(p,'VirtualAlloc2')
        if chosen then return chosen,d end
    end
    local middle=math.min(high+1,math.max(low,floor(instruction,g)))
    -- Search upward first, then below the instruction. VirtualQuery skips entire
    -- occupied regions; only actual MEM_FREE regions receive a VirtualAlloc call.
    for _,span in ipairs({{middle,high+1},{low,middle}})do
        local cursor,ending=span[1],span[2]
        while cursor<ending and d.queries<4096 do
            d.queries=d.queries+1
            local region,err=OS.query(cursor)
            if not region then
                d.last_error=err or 0;d.reason='VirtualQuery failed';return nil,d
            end
            local next_address=region.base+region.size
            if region.size<=0 or region.base>cursor or next_address<=cursor then
                d.reason='VirtualQuery returned an invalid region';return nil,d
            end
            if region.free then
                local address=ceil(math.max(cursor,region.base,low),g)
                local end_address=math.min(next_address,ending,high+1)
                if address+size<=end_address then
                    d.free_regions=d.free_regions+1;d.attempts=d.attempts+1
                    local p,alloc_error=OS.alloc(address,size)
                    d.last_error=alloc_error or 0
                    local chosen=accept(p,'VirtualQuery + VirtualAlloc')
                    if chosen then return chosen,d end
                    -- Access denied or exhausted commit cannot be repaired by
                    -- repeatedly requesting different addresses. Keep the feature off.
                    if alloc_error==5 or alloc_error==8 or alloc_error==1455 then
                        d.reason='native allocation refused';return nil,d
                    end
                end
            end
            cursor=next_address
        end
    end
    d.reason=d.queries>=4096 and 'address-space query budget exhausted' or 'no usable free region in rel32 window'
    return nil,d
end
return M
