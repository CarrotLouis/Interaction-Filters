-- Exercise the REAL Windows allocator, page protection and x64 CAS in a private
-- synthetic allocation of this test process. Never attach to or start the game.
local ROOT=assert(arg[1])
local ffi=require('ffi')
local Windows=assert(loadfile(ROOT..'/src/windows.lua'))()
local Allocator=assert(loadfile(ROOT..'/src/near_allocator.lua'))()
local Hook=assert(loadfile(ROOT..'/src/hook.lua'))()
local P=assert(loadfile(ROOT..'/src/profile.lua'))()
local B=assert(loadfile(ROOT..'/src/native_blob.lua'))()
ffi.cdef [[
void *ppb_test_GetCurrentProcess(void) __asm__("GetCurrentProcess");
]]
local k=ffi.load('kernel32')
local process=k.ppb_test_GetCurrentProcess()
local block=k.ppb1_VirtualAlloc(nil,4096,0x3000,4)
assert(block~=nil,'fixture allocation')
local base=tonumber(ffi.cast('uintptr_t',block))
local original=Hook.bytes(P.original)
ffi.copy(ffi.cast('uint8_t *',block)+0x100,original,8)
local header=ffi.new('uint8_t[4096]')
ffi.cast('uint32_t *',header+0x3c)[0]=0x80
ffi.cast('uint32_t *',header+0x80+80)[0]=74727424
local memory={windows={kernel32={GetCurrentProcess=function()return process end}}}
function memory.address(ptr)return tonumber(ffi.cast('uintptr_t',ptr))end
function memory.read(ptr,size)
    local n=memory.address(ptr)
    if n==base and size==4096 then return ffi.string(header,4096)end
    if n==base+0x100 and size==8 then return ffi.string(ptr,size)end
    error('unexpected fixture read')
end
local A=Windows.new(memory,Allocator)
local prepared,entry,why=A.prepare(base,P,B)
assert(prepared,why)
assert(A.diagnostics().backend=='VirtualAlloc2' or A.diagnostics().backend=='VirtualQuery + VirtualAlloc','allocation backend not recorded')
assert(A.diagnostics().address+B.offsets.entry==entry and A.diagnostics().last_error==0,'allocation diagnostics')
assert(math.abs(entry-(base+P.instruction_rva+5))<2147483648,'near allocation')
local desired=string.char(1,2,3)..original:sub(4)
for i=1,100 do
    A.set_control(prepared,true)
    assert(A.compare_exchange(base+0x100,original,desired,prepared),'real atomic install')
    assert(memory.read(ffi.cast('uint8_t *',block)+0x100,8)==desired)
    A.set_control(prepared,false)
    assert(A.compare_exchange(base+0x100,desired,original,prepared),'real atomic restore')
    assert(memory.read(ffi.cast('uint8_t *',block)+0x100,8)==original)
end
assert(not A.compare_exchange(base+0x100,'occupied',desired,prepared),'ownership refusal')
assert(not A.compare_exchange(base+0x101,original,desired,prepared),'unaligned refusal')
assert(tonumber(prepared.control[0])==0,'control off')
local stats=A.native_stats(prepared)
assert(stats.visits==0 and stats.primary_seen==0 and stats.local_matches==0 and
       stats.last_resource=='0000000000000000','uninitialized native diagnostics')
local diagnostic=ffi.cast('uint32_t *',ffi.cast('uint8_t *',prepared.control)+0x2100)
diagnostic[0]=23;diagnostic[1]=7;diagnostic[6]=5;diagnostic[11]=0x89abcdef
diagnostic[12]=0x01234567;diagnostic[17]=7
diagnostic[80]=329;diagnostic[10]=329
diagnostic[81]=31;diagnostic[82]=30
stats=A.native_stats(prepared)
assert(stats.visits==23 and stats.primary_seen==7 and stats.local_matches==5 and
       stats.last_resource=='0123456789ABCDEF' and stats.type_1==7 and
       stats.last_actor_network_id==329 and stats.last_local_network_id==329,'native diagnostics decode')
assert(stats.entry_calls==31 and stats.returned_calls==30,'entry/return diagnostics decode')
-- The support cache crosses page boundaries at its full supported capacity.
local origins={}
for i=1,512 do origins[i]={entity=i,class=i%3+1,record=base+i*16}end
A.set_control(prepared,63)
A.publish_origins(prepared,origins)
assert(A.native_stats(prepared).visits==23 and A.native_stats(prepared).type_1==7,
       'full source cache overwrote native diagnostics')
assert(tonumber(prepared.control[0])==63 and tonumber(prepared.control[1])==2 and tonumber(prepared.control[8])==512)
local last=ffi.cast('uint8_t *',prepared.control)+64+511*16
assert(tonumber(ffi.cast('uint32_t *',last)[0])==512 and
    tonumber(ffi.cast('uint64_t *',last+8)[0])==base+512*16)
A.publish_origins(prepared,{})
assert(tonumber(prepared.control[1])==4 and tonumber(prepared.control[8])==0)
origins[513]={entity=513,class=2,record=base}
A.publish_origins(prepared,origins)
assert(tonumber(prepared.control[1])==6 and tonumber(prepared.control[8])==0,'oversized cache published partial rows')
A.set_control(prepared,0)
prepared.control[1]=7
A.publish_origins(prepared,{{entity=77,class=2,record=nil}})
assert(tonumber(prepared.control[1])==8 and tonumber(prepared.control[8])==0,'interrupted/invalid publication')
-- Real OS unwinding, not merely a parsed metadata assertion. Each synthetic
-- context is stopped at an exact prologue/body/epilogue instruction boundary.
ffi.cdef [[
ppb4_runtime_function *ppb_test_RtlLookupFunctionEntry(uint64_t pc,uint64_t *base,void *history) __asm__("RtlLookupFunctionEntry");
void *ppb_test_RtlVirtualUnwind(uint32_t kind,uint64_t base,uint64_t pc,ppb4_runtime_function *fn,
    void *context,void **handler_data,uint64_t *frame,void *pointers) __asm__("RtlVirtualUnwind");
]]
local image=memory.address(prepared.entry)
local image_out=ffi.new('uint64_t[1]')
local function_entry=k.ppb_test_RtlLookupFunctionEntry(image+B.offsets.body,image_out,nil)
assert(function_entry~=nil and tonumber(image_out[0])==image,'dynamic function lookup failed')
assert(function_entry[0].begin_address==B.offsets.entry and
       function_entry[0].end_address==B.offsets.wrapper_end,'wrong registered function range')
local stack=k.ppb1_VirtualAlloc(nil,4096,0x3000,4)
assert(stack~=nil)
local S=memory.address(stack)+0x708
local function qword(a,v)ffi.cast('uint64_t *',a)[0]=v end
qword(S,0x123456789abc);qword(S-8,0x1111);qword(S-16,0x2222);qword(S-24,0x3333)
local epilogue=B.offsets.epilogue-B.offsets.entry
local contexts={{0,0},{1,8},{2,16},{3,24},{7,88},
    {epilogue,88},{epilogue+5,88},{epilogue+9,24},
    {epilogue+10,16},{epilogue+11,8},{epilogue+12,0}}
for _,case in ipairs(contexts)do
    local storage=ffi.new('uint8_t[1280]')
    local address=memory.address(storage);address=address+(16-address%16)%16
    local context=ffi.cast('uint8_t *',address)
    local function put(o,v)ffi.cast('uint64_t *',context+o)[0]=v end
    local function get(o)return tonumber(ffi.cast('uint64_t *',context+o)[0])end
    local pc=image+B.offsets.entry+case[1]
    put(0x90,0x1111);put(0xa8,0x2222);put(0xb0,0x3333)
    if case[2]>=8 then put(0x90,0x9999)end
    if case[2]>=16 then put(0xa8,0x8888)end
    if case[2]>=24 then put(0xb0,0x7777)end
    put(0x98,S-case[2]);put(0xf8,pc)
    ffi.cast('uint32_t *',context+0x30)[0]=0x10000b
    local handler,frame=ffi.new('void *[1]'),ffi.new('uint64_t[1]')
    k.ppb_test_RtlVirtualUnwind(0,image,pc,function_entry,context,handler,frame,nil)
    assert(get(0xf8)==0x123456789abc and get(0x98)==S+8,
        'bad OS unwind at wrapper offset '..case[1])
    assert(get(0x90)==0x1111 and get(0xa8)==0x2222 and get(0xb0)==0x3333,
        'nonvolatile unwind failure')
end
assert(k.ppb1_VirtualFree(stack,0,0x8000)~=0)
print('PASS actual RtlLookupFunctionEntry/RtlVirtualUnwind: 11 prologue/body/epilogue contexts')
-- Exercise the real VirtualQuery/VirtualAlloc fallback too, without replacing
-- any Windows function or changing the production factory's interface.
local fallback={allocate=function(OS,instruction,size)
    OS.alloc2=nil
    return Allocator.allocate(OS,instruction,size)
end}
local F=Windows.new(memory,fallback)
local second,second_entry,second_why=F.prepare(base,P,B)
assert(second,second_why)
assert(F.diagnostics().backend=='VirtualQuery + VirtualAlloc','real fallback was not used')
assert(F.compare_exchange(base+0x100,original,desired,second),'real fallback CAS install')
assert(F.compare_exchange(base+0x100,desired,original,second),'real fallback CAS restore')
assert(k.ppb1_VirtualFree(block,0,0x8000)~=0)
-- The fixture stub was never published to any engine code; no call is in flight.
assert(k.ppb4_RtlDeleteFunctionTable(prepared.unwind_table)~=0)
assert(k.ppb4_RtlDeleteFunctionTable(second.unwind_table)~=0)
assert(k.ppb1_VirtualFree(prepared.entry,0,0x8000)~=0)
assert(k.ppb1_VirtualFree(second.entry,0,0x8000)~=0)
print('PASS real Windows '..A.diagnostics().backend..' and query fallback, bounded pages and atomic install/restore; no game process')
