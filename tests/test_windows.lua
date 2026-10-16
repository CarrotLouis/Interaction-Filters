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
assert(A.diagnostics().address==entry and A.diagnostics().last_error==0,'allocation diagnostics')
assert(math.abs(entry-(base+P.instruction_rva+5))<2147483648,'near allocation')
local desired=original:sub(1,3)..string.char(0xe9,0,0,0,0)
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
stats=A.native_stats(prepared)
assert(stats.visits==23 and stats.primary_seen==7 and stats.local_matches==5 and
       stats.last_resource=='0123456789ABCDEF' and stats.type_1==7 and
       stats.last_actor_network_id==329 and stats.last_local_network_id==329,'native diagnostics decode')
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
assert(k.ppb1_VirtualFree(prepared.entry,0,0x8000)~=0)
assert(k.ppb1_VirtualFree(second.entry,0,0x8000)~=0)
print('PASS real Windows '..A.diagnostics().backend..' and query fallback, bounded pages and atomic install/restore; no game process')
