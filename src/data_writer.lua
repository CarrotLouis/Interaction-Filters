-- Eight-byte, current-process, private RW data writes. No protection changes.
-- The caller must revalidate the current actor and both target records each time.
local ffi=require('ffi')
local M={}
if not pcall(ffi.typeof,'ifc3_write_size')then
    ffi.cdef[[
        typedef size_t ifc3_write_size;
        int ifc3_WriteProcessMemory(void *process, void *address, const void *buffer,
            size_t size, size_t *done) __asm__("WriteProcessMemory");
    ]]
end
function M.new(memory)
    local kernel=ffi.load('kernel32')
    local process=memory.windows.kernel32.GetCurrentProcess()
    local done=ffi.new('size_t[1]')
    local a={writes=0}
    function a.replace(address,expected,desired,validate)
        if type(address)~='number' or address<65536 or address>=140737488355320 or address%8~=0 or
            type(expected)~='string' or #expected~=8 or type(desired)~='string' or #desired~=8 or
            type(validate)~='function' then return false,'invalid write contract' end
        if expected==desired then return false,'no change' end
        if not memory.writable_data(address,8) then return false,'target is not private RW data' end
        if not validate() then return false,'snapshot changed' end
        local target=ffi.cast('uint8_t *',address)
        if memory.read(target,8)~=expected then return false,'selection changed' end
        done[0]=0
        if kernel.ifc3_WriteProcessMemory(process,target,ffi.cast('const char *',desired),8,done)==0 or
            tonumber(done[0])~=8 then return false,'data write failed' end
        a.writes=a.writes+1
        if memory.read(target,8)~=desired then return false,'data readback failed' end
        return true
    end
    return a
end
return M
