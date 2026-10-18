local ROOT=assert(arg[1])
local F=dofile(ROOT..'/tests/cache_fixture.lua')
local checks=0
local function check(v,why)assert(v,why);checks=checks+1 end
local function make(zone)local f=F.new(ROOT,zone);assert(f.backend.configure(1));return f,f.backend end
-- Primary/support selection and native pool slot round trips, including nonzero zones.
for _,zone in ipairs({0,1,7})do
    local f,h=make(zone)
    local before=f.get(f.rows,4*0x880)
    local pools=f.get(f.targets,0x14080)
    h.step()
    check(f.get(f.row,8)==F.u64(f.support),'did not replace primary with support spatial record')
    check(h.stats.primary_seen==1 and h.stats.support_seen==1 and h.stats.replaced==1,'observation counters')
    local after=f.get(f.rows,4*0x880);local o=2*0x880
    check(before:sub(1,o)==after:sub(1,o) and before:sub(o+9)==after:sub(o+9),'other actors/list/pending state changed')
    check(f.get(f.targets,0x14080)==pools,'shared objects changed')
    check(#f.writes==1,'more than one data write')
end
do
    local f,h=make();f.put(f.row+0x808,F.u32(0));h.step()
    check(f.get(f.row,8)==F.u64(0)and h.stats.cleared==1,'retained-only primary was not cleared')
    f.collect();f.put(f.support_row+0x60,'\0');f.put(f.row+0x808,F.u32(2));h.step()
    check(f.get(f.row,8)==F.u64(0),'unavailable support was chosen')
    f,h=make();f.put(f.row+0x818,F.u64(0x12345678));f.put(f.row+0x828,F.f32(-1))
    h.step();check(f.get(f.row,8)==F.u64(f.support),'inactive result padding suppressed filtering')
end
-- Fresh network identity, not unit handle or peer ownership alone (host scope).
local cases={
    {'remote network',function(f)f.put(f.descriptor+0x10,F.u32(900))end},
    {'unit matches but network differs',function(f)f.put(f.descriptor+0xc,F.u32(329));f.put(f.descriptor+0x10,F.u32(900))end},
    {'unowned local',function(f)f.put(f.descriptor+0x14,F.u32(0))end},
    {'ambiguous local',function(f)f.put(f.manager+0x3010,F.u32(329))end},
    {'no avatar',function(f)f.put(f.player+0x3a8,F.u32(0x7fff))end},
    {'two locals',function(f)f.put(f.player+0x88,F.u32(2))end},
    {'hash entity mismatch',function(f)f.put(f.manager+0x1000+(77%8)*8,F.u32(66))end},
    {'hash index mismatch',function(f)f.put(f.manager+0x1000+(77%8)*8+4,F.u32(0))end},
    {'inactive actor',function(f)f.put(f.row+0x834,'\0')end},
    {'pending request',function(f)f.put(f.row+0x820,F.u32(100))end},
    {'candidate overflow',function(f)f.put(f.row+0x808,F.u32(257))end},
    {'actor overflow',function(f)f.put(f.manager+0x1c,F.u32(257))end},
    {'payload alias as retained',function(f)f.put(f.row,F.u64(f.primary_payload))end},
    {'unmapped retained',function(f)f.put(f.row,F.u64(0x70000000))end},
    {'misaligned spatial',function(f)f.put(f.row,F.u64(f.primary+1))end},
    {'wrong spatial pool',function(f)f.put(f.targets+0x14018,F.u64(f.targets+0x4004))end},
    {'destroyed spatial',function(f)f.put(f.primary+0xc,F.u32(0xffffffff))end},
    {'slot reuse',function(f)f.put(f.primary+0x10,F.u32(6))end},
    {'zone slot mismatch',function(f)f.put(f.primary_row+0x40,F.u32(6))end},
    {'target descriptor identity',function(f)f.put(f.target_descriptors+0x108,F.u32(101))end},
    {'zone overflow',function(f)f.put(f.primary_row+0x340,F.u32(9))end},
    {'zone outside count',function(f)f.put(f.primary_payload+4,F.u32(7))end},
    {'hash capacity',function(f)f.put(f.targets+0x14058,F.u32(3))end},
    {'type unknown',function(f)f.put(f.primary_row+0x44,F.u32(99))end},
}
for _,case in ipairs(cases)do
    local f,h=make();case[2](f);h.step();check(#f.writes==0,case[1]..' wrote')
end
-- Replacement must still be a currently listed, eligible, positive-score target.
for _,mutate in ipairs({
    function(f)f.put(f.support_row+0x66,'\1')end,
    function(f)f.put(f.support_payload+8,F.f32(0))end,
    function(f)f.put(f.support_payload+8,string.char(0,0,192,127))end,
    function(f)f.put(f.support_row+0x40,F.u32(2048))end,
    function(f)f.put(f.row+0x808,F.u32(1))end,
    function(f)f.put(f.row+0x878,F.u32(1));f.put(f.row+0x838,F.u32(1))end,
})do local f,h=make();mutate(f);h.step();check(f.get(f.row,8)==F.u64(0),'invalid replacement selected')end
-- Reallocation, despawn and identity races between selection and commit fail closed on writes.
for _,mutate in ipairs({
    function(f)f.put(f.manager+0x48,F.u64(f.rows+0x880))end,
    function(f)f.put(f.player+0x3a8,F.u32(0x7fff))end,
    function(f)f.put(f.descriptor+8,F.u32(88))end,
    function(f)f.put(f.row,F.u64(f.support))end,
    function(f)f.put(f.support+0xc,F.u32(0xffffffff))end,
    function(f)f.put(f.targets+0x14070,F.u64(0x70000000))end,
    function(f)f.put(f.row+0x808,F.u32(0))end,
})do
    local f,h=make();f.on_validate=function()mutate(f)end;h.step()
    check(#f.writes==0 and not h.active and h.stats.write_failures==1,'changed snapshot committed')
end
do
    local f,h=make();h.step();local writes=#f.writes
    f.collect();h.disable();local reads=f.reads
    for i=1,1000 do h.step();h.disable()end
    check(#f.writes==writes and f.reads==reads,'OFF/restoration touched stale actor')
    check(f.get(f.row,8)==F.u64(f.primary),'OFF restored a saved old pointer')
    check(h.configure(1),'resume');h.step()
    f.put(f.player+0x3a8,F.u32(0x7fff));h.step()
    -- Reinforcement compacts the runtime and moves the local descriptor to index0.
    f.put(f.manager+0x1c,F.u32(1));f.put(f.manager+0x2000,F.u64(f.descriptor))
    f.put(f.manager+0x1000+(77%8)*8+4,F.u32(0))
    f.put(f.descriptor+0x10,F.u32(400));f.put(f.player+0x3a8,F.u32(400))
    f.put(f.rows,f.get(f.row,0x880));f.put(f.rows,F.u64(f.primary));f.row=f.rows
    h.step();check(f.get(f.rows,8)==F.u64(f.support),'reinforced/compacted actor was not reacquired')
    check(h.stats.last_network_id==400,'previous life network ID reused')
end
do
    local f=F.new(ROOT);f.supported=false
    check(not f.backend.configure(1)and #f.writes==0,'build mismatch')
    f=F.new(ROOT);f.put(f.game+f.P.pins[1].rva,'\0')
    check(not f.backend.configure(1)and #f.writes==0,'changed native evidence')
    f,h=make();f.readonly=true;h.step();check(not h.active and #f.writes==0,'readonly target')
end
print('PASS '..checks..' cache backend checks: exact current actor, slot lifetime, pending requests, safe replacement, OFF and reinforcement')
