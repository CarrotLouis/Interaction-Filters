-- Execute the PRODUCTION diagnostic on actual private Windows pages.
-- Invalid actor/manager arguments prove that the probe never dereferences them.
local ROOT=assert(arg[1])
local ffi=require('ffi')
local Runtime=dofile(ROOT..'/vendor/shared/bingus_runtime.lua')
local Memory=dofile(ROOT..'/vendor/shared/bingus_memory.lua')
local Windows=dofile(ROOT..'/src/windows.lua')
local Allocator=dofile(ROOT..'/src/near_allocator.lua')
local B=dofile(ROOT..'/src/native_blob.lua')
local memory=Memory.new(Runtime)
local A=Windows.new(memory,Allocator)
local k=ffi.load('kernel32')
local block=k.ppb1_VirtualAlloc(nil,0x4000,0x3000,4)
assert(block~=nil)
local base=memory.address(block)
local function ptr(o)return ffi.cast('uint8_t *',block)+o end
local function dword(o,v)ffi.cast('uint32_t *',ptr(o))[0]=v end
local function read32(o)return tonumber(ffi.cast('uint32_t *',ptr(o))[0])end
local function read64(o)return tonumber(ffi.cast('uint64_t *',ptr(o))[0])end
dword(0x3c,0x80);dword(0x80+80,74727424)
local P={instruction_rva=0x1100,collect_rva=0x1000}
-- Only this tiny native collector records the otherwise-invalid argument values.
local cell=ffi.new('uint64_t[1]',base+0x3000)
local body=string.char(0x48,0xb8)..ffi.string(cell,8)..
    string.char(0xff,0x00,0x48,0x89,0x48,0x08,0x48,0x89,0x50,0x10,
        0x4c,0x89,0x40,0x18,0x4c,0x89,0x48,0x20,0xb8,0x78,0x56,0x34,0x12,0xc3)
ffi.copy(ptr(0x1000),body,#body)
local previous=ffi.new('uint32_t[1]')
assert(k.ppb1_VirtualProtect(ptr(0x1000),4096,0x20,previous)~=0)
assert(k.ppb1_FlushInstructionCache(memory.windows.kernel32.GetCurrentProcess(),ptr(0x1000),4096)~=0)
local prepared,entry,why=A.prepare(base,P,B)
assert(prepared,why);assert(prepared.unwind_registered)
assert(B.offsets.player==nil and B.offsets.interactables==nil)
local call=ffi.cast('uint64_t (*)(void *,void *,uint32_t,uint64_t)',entry)
local n=0
for _,mask in ipairs({0,1,63})do
    A.set_control(prepared,mask)
    for _,args in ipairs({{0,0,0,0},{1,2,4294967295,4},{0xdead0000,0xbeef0000,99,0xfedcba98}})do
        n=n+1
        local result=call(ffi.cast('void *',args[1]),ffi.cast('void *',args[2]),args[3],args[4])
        assert(tonumber(result)==0x12345678,'original return changed')
        assert(read32(0x3000)==n,'original collector did not execute exactly once')
        for i=1,4 do assert(read64(0x3000+i*8)==args[i],'argument forwarding changed')end
        local stats=A.native_stats(prepared)
        assert(stats.entry_calls==n and stats.returned_calls==n and stats.visits==n,'entry/return instrumentation failed')
        assert(A.counter(prepared)==0 and stats.local_matches==0 and stats.primary_seen==0,'filter body ran')
    end
end
assert(k.ppb4_RtlDeleteFunctionTable(prepared.unwind_table)~=0)
assert(k.ppb1_VirtualFree(prepared.entry,0,0x8000)~=0)
assert(k.ppb1_VirtualFree(block,0,0x8000)~=0)
print('PASS actual Windows ENTRY-ONLY execution: 9 calls, invalid manager/actor arguments never read, exact forwarding/return and private counters; NO FILTERING')
