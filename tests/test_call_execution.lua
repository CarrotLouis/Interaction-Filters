-- Execute the production native wrapper on actual Windows x64, on private pages.
-- The only collector is a tiny native test function; no game is started/attached.
local ROOT=assert(arg[1])
local ffi=require('ffi')
local Runtime=dofile(ROOT..'/vendor/shared/bingus_runtime.lua')
local Memory=dofile(ROOT..'/vendor/shared/bingus_memory.lua')
local Windows=dofile(ROOT..'/src/windows.lua')
local Allocator=dofile(ROOT..'/src/near_allocator.lua')
local B=dofile(ROOT..'/src/native_blob.lua')
local memory=Memory.new(Runtime)
local A=Windows.new(memory,Allocator)
local kernel=ffi.load('kernel32')
local block=kernel.ppb1_VirtualAlloc(nil,0x60000,0x3000,4)
assert(block~=nil)
local base=memory.address(block)
local function ptr(o)return ffi.cast('uint8_t *',block)+o end
local function dword(o,v)ffi.cast('uint32_t *',ptr(o))[0]=v end
local function qword(o,v)ffi.cast('uint64_t *',ptr(o))[0]=v end
local function read32(o)return tonumber(ffi.cast('uint32_t *',ptr(o))[0])end
local function read64(o)return tonumber(ffi.cast('uint64_t *',ptr(o))[0])end
dword(0x3c,0x80);dword(0x80+80,74727424)
local P={instruction_rva=0x1100,player_global=0x3200,interactable_global=0x3400,collect_rva=0x1000}
qword(0x3000+0x48,base+0x50000)
qword(0x3200,base+0x3300);dword(0x3300+0x88,1);dword(0x3300+0x3a8,329)
dword(0x3100+0x0c,4196913);dword(0x3100+0x10,329)
qword(0x3400,base+0x10000)
dword(0x10000+0x14040,4);qword(0x10000+0x14050,base+0x40000)
dword(0x10000+0x14058,8);dword(0x10000+0x14060,1)
qword(0x10000+0x14070,base+0x30000)
local kinds={1,3,48,1}
for i,kind in ipairs(kinds)do
    local n=i-1
    dword(0x40000+i*8,i);dword(0x40000+i*8+4,n)
    dword(0x30000+n*0x370+0x340,1);dword(0x30000+n*0x370+0x44,kind)
    dword(0x45000+n*8,i);dword(0x45000+n*8+4,0)
end
local collector=string.char(0xff,0x41,0x10,0xb8,0x78,0x56,0x34,0x12,0xc3)
ffi.copy(ptr(0x1000),collector,#collector)
local previous=ffi.new('uint32_t[1]')
assert(kernel.ppb1_VirtualProtect(ptr(0x1000),4096,0x20,previous)~=0)
assert(kernel.ppb1_FlushInstructionCache(memory.windows.kernel32.GetCurrentProcess(),ptr(0x1000),4096)~=0)
local prepared,entry,why=A.prepare(base,P,B)
assert(prepared,why)
assert(prepared.unwind_registered)
local call=ffi.cast('uint64_t (*)(void *,void *,uint32_t)',entry)
local row=0x50000+2*0x880
local function seed()
    qword(row,base+0x45000);dword(row+0x808,4)
    for i=0,3 do qword(row+8+i*8,base+0x45000+i*8)end
end
local calls=0
local function invoke()
    calls=calls+1
    assert(tonumber(call(ptr(0x3000),ptr(0x3100),2))==0x12345678,'collector return value changed')
    assert(read32(0x3010)==calls,'original collector did not execute exactly once')
end
seed();A.set_control(prepared,1);invoke()
assert(read32(row+0x808)==2 and read64(row)==0)
assert(read64(row+8)==base+0x45008 and read64(row+16)==base+0x45010,'non-primary order changed')
assert(A.counter(prepared)==2)
seed();A.set_control(prepared,0);invoke()
assert(read32(row+0x808)==4 and read64(row)==base+0x45000)
seed();dword(0x3110,330);A.set_control(prepared,1);invoke()
assert(read32(row+0x808)==4 and read64(row)==base+0x45000,'remote actor was filtered')
seed();dword(0x3110,411);dword(0x3300+0x3a8,411);invoke()
assert(read32(row+0x808)==2,'reinforced avatar network identity not refreshed')
seed();dword(0x3300+0x3a8,0x7fff);invoke()
assert(read32(row+0x808)==4,'missing avatar was filtered')
assert(kernel.ppb4_RtlDeleteFunctionTable(prepared.unwind_table)~=0)
assert(kernel.ppb1_VirtualFree(prepared.entry,0,0x8000)~=0)
assert(kernel.ppb1_VirtualFree(block,0,0x8000)~=0)
print('PASS actual Windows wrapper execution: original call/return, local primary only, support order, OFF, remote, reinforcement and missing avatar')
