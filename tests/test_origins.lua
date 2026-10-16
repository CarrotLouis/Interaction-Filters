local ROOT=assert(arg[1])
local Origins=dofile(ROOT..'/src/support_origins.lua')
local t=Origins.new()
local field={entity=10,unit=100,goid=1000,record=0x100000,free=true}
local mine={entity=20,unit=200,goid=2000,record=0x200000,podded=true}
local team={entity=30,unit=300,goid=3000,record=0x300000,podded=true}
local function snap(items,owned,epoch)return {active=true,epoch=epoch or 'mission1',items=items,owned=owned}end
local function classes(rows)local c={};for _,r in ipairs(rows)do c[r.entity]=r.class end;return c end
local rows=t.observe(snap({team,mine,field},{[2000]=true}),0)
assert(classes(rows)[10]==Origins.FIELD and not classes(rows)[20] and not classes(rows)[30])
rows=t.observe(snap({field,mine,team},{[2000]=true}),1.6)
assert(classes(rows)[10]==Origins.FIELD and classes(rows)[20]==Origins.OWN and classes(rows)[30]==Origins.TEAM)
-- A local pickup/ownership transfer does not alter frozen call-in origin.
team.podded=false;team.carried=true
field.free=false;field.carried=true
rows=t.observe(snap({field,mine,team},{[3000]=true,[1000]=true}),3)
assert(classes(rows)[10]==Origins.FIELD and classes(rows)[20]==Origins.OWN and classes(rows)[30]==Origins.TEAM)
team.carried=false;team.free=true
rows=t.observe(snap({field,mine,team},{[3000]=true}),4)
assert(classes(rows)[30]==Origins.TEAM,'local re-drop changed teammate origin')
-- Interactable membership and row address can change while carrying.
t.observe(snap({mine},{}),4.01)
team.record=0x700000
rows=t.observe(snap({field,mine,team},{[3000]=true}),4.02)
assert(classes(rows)[30]==Origins.TEAM and classes(rows)[10]==Origins.FIELD,'carrying gap erased source')
assert(#t.observe(nil,4.1)==0,'failed read did not invalidate publication')
rows=t.observe(snap({field,mine,team},{[3000]=true}),4.2)
assert(classes(rows)[20]==Origins.OWN and classes(rows)[30]==Origins.TEAM,'read fault lost origin history')
-- Later loose gear isn't map equipment; ownership can materialize late.
local later={entity=40,unit=400,goid=4000,record=0x400000,free=true}
t.observe(snap({field,mine,team,later},nil),5)
assert(not classes(t.observe(snap({field,mine,team,later},{[4000]=true}),6))[40])
assert(classes(t.observe(snap({field,mine,team,later},{[4000]=true}),7.6))[40]==Origins.OWN)
-- A recycled entity has a new identity and a new grace window.
later.unit=401;later.goid=4001;later.podded=true;later.free=false
assert(not classes(t.observe(snap({later},{[4001]=true}),8))[40])
assert(classes(t.observe(snap({later},{[4001]=true}),9.6))[40]==Origins.OWN)
assert(#t.observe({active=false},10)==0 and t.loading and next(t.history)==nil)
-- Initial object id assignment must not turn a map weapon into call-in gear.
local delayed={entity=50,unit=500,goid=0,record=0x500000,free=true}
t.observe(snap({delayed,mine},{}),0)
delayed.goid=5000
assert(classes(t.observe(snap({delayed,mine},{[5000]=true}),2))[50]==Origins.FIELD)
-- Missing attachment/source evidence stays unknown even after the grace window.
local unread={entity=60,unit=600,goid=6000,record=0x600000}
t.observe(snap({delayed,unread},{}),3)
assert(not classes(t.observe(snap({delayed,unread},{}),5))[60])
-- No silent truncation if a modded mission exceeds cache capacity.
local packs=Origins.new()
packs.observe({active=true,epoch='packs',items={},carried_gear=true},0)
assert(not packs.loading,'first carried pack did not end map-start observation')
local own_drop={entity=70,unit=700,goid=7000,record=0x700000,free=true}
packs.observe({active=true,epoch='packs',items={own_drop},owned={[7000]=true}},1)
local classified=packs.observe({active=true,epoch='packs',items={own_drop},owned={[7000]=true}},2.6)
assert(classified[1].class==Origins.OWN,'own later drop incorrectly called field gear')
local many={}
t=Origins.new()
for i=1,513 do many[i]={entity=i,unit=i,goid=i,record=i*16,free=true}end
assert(#t.observe(snap(many,{}),0)==0 and t.capacity_exceeded)
print('PASS support origins: field/own/team, pickup/re-drop, host transfer, delayed ownership, faults and recycling')
