-- System operations under private FFI names; no user32 declarations, no DLL/helper files.
local M={}
local ffi=require('ffi')
if not pcall(ffi.typeof,'ppb1_word')then
    ffi.cdef [[
    typedef union ppb1_word { uint8_t bytes[8]; int64_t signed_value; } ppb1_word;
    void *ppb1_VirtualAlloc(void *address, size_t size, uint32_t allocation, uint32_t protection) __asm__("VirtualAlloc");
    int ppb1_VirtualFree(void *address, size_t size, uint32_t kind) __asm__("VirtualFree");
    int ppb1_VirtualProtect(void *address, size_t size, uint32_t protection, uint32_t *previous) __asm__("VirtualProtect");
    int ppb1_FlushInstructionCache(void *process, const void *address, size_t size) __asm__("FlushInstructionCache");
    ]]
end
local kernel=ffi.load('kernel32')
if not pcall(ffi.typeof,'ppb2_system_info')then
    ffi.cdef [[
    typedef struct ppb2_system_info {
        uint32_t architecture, page_size; void *minimum, *maximum;
        uintptr_t processor_mask; uint32_t processors, processor_type, granularity;
        uint16_t processor_level, processor_revision;
    } ppb2_system_info;
    typedef struct ppb2_region {
        void *base, *allocation_base; uint32_t allocation_protection;
        uint16_t partition, padding; size_t size;
        uint32_t state, protection, kind, padding2;
    } ppb2_region;
    typedef struct ppb2_address_requirements {void *lowest, *highest; size_t alignment;} ppb2_address_requirements;
    typedef struct ppb2_extended_parameter {uint64_t kind; void *data;} ppb2_extended_parameter;
    void ppb2_GetSystemInfo(ppb2_system_info *info) __asm__("GetSystemInfo");
    size_t ppb2_VirtualQuery(const void *address, ppb2_region *region, size_t size) __asm__("VirtualQuery");
    uint32_t ppb2_GetLastError(void) __asm__("GetLastError");
    void *ppb2_GetModuleHandleA(const char *name) __asm__("GetModuleHandleA");
    void *ppb2_GetProcAddress(void *module, const char *name) __asm__("GetProcAddress");
    ]]
end
local function pointer(n)return ffi.cast('uint8_t *',n)end
local function unhex(s)return(s:gsub('..',function(x)return string.char(tonumber(x,16))end))end
local function u32(s,o)
    local a,b,c,d=s:byte(o+1,o+4)
    return a+b*256+c*65536+d*16777216
end
local function put_pointer(target,offset,address)
    ffi.cast('uint64_t *',target+offset)[0]=ffi.cast('uintptr_t',address)
end
function M.new(memory,allocator,note)
    local process=memory.windows.kernel32.GetCurrentProcess()
    assert(allocator and type(allocator.allocate)=='function','near allocator required')
    local A={read=function(address,size)return memory.read(pointer(address),size)end}
    local function log(s)if note then note(s)end end
    local function format_allocation(d)
        return string.format('allocation backend=%s range=%X..%X address=%X queries=%d attempts=%d free_regions=%d alloc2_error=%d last_error=%d reason=%s',
            d.backend or 'none',d.range_min or 0,d.range_max or 0,d.address or 0,d.queries or 0,
            d.attempts or 0,d.free_regions or 0,d.alloc2_error or 0,d.last_error or 0,d.reason or 'allocated')
    end
    function A.diagnostics()return A.allocation_info end
    local function os_allocator()
        assert(ffi.sizeof('ppb2_system_info')==48 and ffi.sizeof('ppb2_region')==48 and
               ffi.sizeof('ppb2_address_requirements')==24 and ffi.sizeof('ppb2_extended_parameter')==16,'Windows allocation ABI')
        local info=ffi.new('ppb2_system_info[1]')
        kernel.ppb2_GetSystemInfo(info)
        local OS={}
        function OS.limits()return {minimum=memory.address(info[0].minimum),maximum=memory.address(info[0].maximum),
            granularity=tonumber(info[0].granularity)}end
        local region=ffi.new('ppb2_region[1]')
        function OS.query(address)
            if kernel.ppb2_VirtualQuery(pointer(address),region,ffi.sizeof(region[0]))==0 then
                return nil,tonumber(kernel.ppb2_GetLastError())
            end
            return {base=memory.address(region[0].base),size=tonumber(region[0].size),free=region[0].state==0x10000}
        end
        function OS.alloc(address,size)
            local p=kernel.ppb1_VirtualAlloc(pointer(address),size,0x3000,4)
            if p==nil then return nil,tonumber(kernel.ppb2_GetLastError())end
            return memory.address(p)
        end
        function OS.release(address)kernel.ppb1_VirtualFree(pointer(address),0,0x8000)end
        local module=kernel.ppb2_GetModuleHandleA('KernelBase.dll')
        local export=module~=nil and kernel.ppb2_GetProcAddress(module,'VirtualAlloc2')or nil
        if export~=nil then
            local alloc2=ffi.cast('void *(*)(void *,void *,size_t,uint32_t,uint32_t,ppb2_extended_parameter *,uint32_t)',export)
            function OS.alloc2(low,high,size)
                local requirements=ffi.new('ppb2_address_requirements[1]')
                requirements[0].lowest=pointer(low);requirements[0].highest=pointer(high)
                local parameter=ffi.new('ppb2_extended_parameter[1]')
                parameter[0].kind=1;parameter[0].data=requirements
                local p=alloc2(process,nil,size,0x3000,4,parameter,1)
                if p==nil then return nil,tonumber(kernel.ppb2_GetLastError())end
                return memory.address(p)
            end
        end
        return OS
    end
    function A.verify_build(profile)
        local game,exe=memory.module('game.dll'),memory.module()
        if not game or not exe then return nil,'game modules not ready'end
        local ok,why=memory.verify_build(profile)
        if not ok then return nil,'unsupported game build: '..tostring(why)end
        return memory.address(game)
    end
    function A.prepare(game,P,B)
        local bytes=unhex(B.hex)
        if #bytes>4096 then return nil,nil,'native predicate exceeds one page'end
        -- Own four pages: one RX code page, three RW control/cache pages.
        -- Ask Windows to allocate inside the complete rel32 window. The old
        -- +/-64 MiB blind probes could miss free space in a real game process.
        local game_header=A.read(game,4096)
        if not game_header then return nil,nil,'module header unreadable'end
        local pe=u32(game_header,60)
        if pe<64 or pe+84>#game_header then return nil,nil,'module header invalid'end
        local image=u32(game_header,pe+80)
        if image~=74727424 then return nil,nil,'module image size changed'end
        local address,diagnostics=allocator.allocate(os_allocator(),game+P.instruction_rva,16384)
        A.allocation_info=diagnostics;log(format_allocation(diagnostics))
        if not address then return nil,nil,'could not reserve nearby native pages: '..format_allocation(diagnostics)end
        local allocation=pointer(address)
        local entry=ffi.cast('uint8_t *',allocation)
        local control=ffi.cast('uint32_t *',entry+4096)
        ffi.copy(entry,bytes,#bytes)
        put_pointer(entry,B.offsets.player,game+P.player_global)
        put_pointer(entry,B.offsets.control,entry+4096)
        put_pointer(entry,B.offsets.skip,game+P.skip_rva)
        put_pointer(entry,B.offsets.resume,game+P.resume_rva)
        local previous=ffi.new('uint32_t[1]')
        if kernel.ppb1_VirtualProtect(entry,4096,0x20,previous)==0 then
            local err=tonumber(kernel.ppb2_GetLastError())
            kernel.ppb1_VirtualFree(allocation,0,0x8000)
            return nil,nil,'could not protect native predicate as executable; win32_error='..err
        end
        if kernel.ppb1_FlushInstructionCache(process,entry,4096)==0 then
            local err=tonumber(kernel.ppb2_GetLastError())
            kernel.ppb1_VirtualFree(allocation,0,0x8000)
            return nil,nil,'could not flush new native predicate; win32_error='..err
        end
        -- These pages are retained until process exit: a caller may be inside the
        -- predicate when shutdown/another addon changes the site. No dangling jump.
        local prepared={entry=entry,control=control,
            cas=ffi.cast('int64_t (*)(void *,int64_t,int64_t)',entry+B.offsets.cas)}
        return prepared,memory.address(entry)
    end
    function A.set_control(p,mask)p.control[0]=type(mask)=='number' and mask or(mask and 1 or 0)end
    function A.counter(p)
        local total=0
        for i=2,7 do total=total+tonumber(p.control[i])end
        return total
    end
    function A.counters(p)
        local out={}
        for i=2,7 do out[i-1]=tonumber(p.control[i])end
        return out
    end
    function A.native_stats(p)
        -- Private control memory only; never query or dereference a game object.
        local d=ffi.cast('uint32_t *',ffi.cast('uint8_t *',p.control)+0x2100)
        local names={'visits','primary_seen','enabled_candidates','descriptor_missing',
            'local_not_ready','different_actor','local_matches','legacy_rejected',
            'last_type','last_actor_unit','last_local_network_id','resource_lo','resource_hi',
            'last_flags','retained_cleared','last_seen_type'}
        local out={}
        for i,name in ipairs(names)do out[name]=tonumber(d[i-1])end
        out.last_resource=string.format('%08X%08X',out.resource_hi,out.resource_lo)
        out.resource_lo,out.resource_hi=nil,nil
        for _,kind in ipairs({1,3,10,11,48})do out['type_'..kind]=tonumber(d[16+kind])end
        out.last_actor_network_id=tonumber(d[80])
        local seen={}
        for kind=0,63 do
            local count=tonumber(d[16+kind])
            if count>0 then seen[#seen+1]=kind..':'..count end
        end
        out.seen_types=#seen>0 and table.concat(seen,',')or 'none'
        return out
    end
    function A.publish_origins(p,rows)
        local count=#rows
        if count>512 then count=0 end
        for i=1,count do
            local v=rows[i]
            if type(v.entity)~='number' or v.entity<1 or v.entity>=4294967295 or v.entity%1~=0 or
               type(v.class)~='number' or v.class<1 or v.class>3 or v.class%1~=0 or
               type(v.record)~='number' or v.record<65536 or v.record>=140737488355328 or v.record%1~=0 then
                count=0;break
            end
        end
        local previous=tonumber(p.control[1])
        local sequence=(previous-previous%2+1)%4294967296
        p.control[1]=sequence -- odd even after a previously interrupted writer
        p.control[8]=0
        local entries=ffi.cast('uint8_t *',p.control)+64
        for i=1,count do
            local item=rows[i];local target=entries+(i-1)*16
            ffi.cast('uint32_t *',target)[0]=item.entity
            ffi.cast('uint32_t *',target)[1]=item.class
            ffi.cast('uint64_t *',target+8)[0]=item.record
        end
        p.control[8]=count
        p.control[1]=(sequence+1)%4294967296 -- publish complete rows or empty invalidation
    end
    function A.cleanup(p)
        if p.pending_flush then
            if kernel.ppb1_FlushInstructionCache(process,pointer(p.protection_site),8)==0 then
                return false,'instruction cache flush is still pending'
            end
            p.pending_flush=nil
        end
        if p.pending_protection then
            local scratch=ffi.new('uint32_t[1]')
            if kernel.ppb1_VirtualProtect(pointer(p.protection_site),8,p.pending_protection,scratch)==0 then
                return false,'code page protection restoration is still pending'
            end
            p.pending_protection=nil
        end
        return true
    end
    function A.compare_exchange(address,expected,desired,p)
        if address%8~=0 or #expected~=8 or #desired~=8 or A.read(address,8)~=expected then
            return false,'aligned hook ownership check failed'
        end
        local original_protection=ffi.new('uint32_t[1]')
        if kernel.ppb1_VirtualProtect(pointer(address),8,0x40,original_protection)==0 then
            return false,'code page protection change failed; win32_error='..tonumber(kernel.ppb2_GetLastError())
        end
        p.pending_protection=p.pending_protection or original_protection[0]
        p.protection_site=address
        local before,after=ffi.new('ppb1_word'),ffi.new('ppb1_word')
        ffi.copy(before.bytes,expected,8);ffi.copy(after.bytes,desired,8)
        -- Single aligned atomic 8-byte update: no partially written jump can execute.
        local observed=p.cas(pointer(address),after.signed_value,before.signed_value)
        local exchanged=observed==before.signed_value
        local flushed=kernel.ppb1_FlushInstructionCache(process,pointer(address),8)~=0
        p.pending_flush=not flushed or nil
        local scratch=ffi.new('uint32_t[1]')
        local restored=kernel.ppb1_VirtualProtect(pointer(address),8,p.pending_protection,scratch)~=0
        if restored then p.pending_protection=nil end
        if not exchanged then return false,'code changed before atomic exchange'end
        if not flushed or not restored then
            -- The control is switched off even if the jump cannot immediately be
            -- removed; retry removal on a later update. Never free a published stub.
            p.control[0]=0
            return false,'instruction cache or code protection restoration failed'
        end
        return true
    end
    return A
end
return M
