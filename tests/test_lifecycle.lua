local ROOT=assert(arg[1],'project root')
local Hook=assert(loadfile(ROOT..'/src/hook.lua'))()
local Controller=assert(loadfile(ROOT..'/src/controller.lua'))()
local P=assert(loadfile(ROOT..'/src/profile.lua'))()
local B=assert(loadfile(ROOT..'/src/native_blob.lua'))()
local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local function fixture()
    local original=Hook.bytes(P.original)
    local memory={[0x10000000+P.patch_rva]=original}
    for _,pin in ipairs(P.pins)do memory[0x10000000+pin.rva]=Hook.bytes(pin.hex)end
    local a={reads=0,exchanges=0,verifies=0,allocations=0,controls=0,control=false,blocked=0,game=0x10000000}
    function a.read(address,size)a.reads=a.reads+1;return memory[address]and memory[address]:sub(1,size)end
    function a.verify_build()
        a.verifies=a.verifies+1
        if a.refuse_build then return nil,'unsupported game build'end
        return a.game
    end
    function a.prepare()
        a.allocations=a.allocations+1
        if a.refuse_allocation then return nil,nil,'allocation failed'end
        return {},a.entry or 0x200000b0
    end
    function a.set_control(_,value)a.controls=a.controls+1;a.control=value end
    function a.counter()return a.blocked end
    function a.cleanup()
        if a.refuse_cleanup then return false,'protection restore pending'end
        return true
    end
    function a.compare_exchange(address,expected,desired)
        a.exchanges=a.exchanges+1
        if a.refuse_exchange then return false,'exchange refused'end
        if memory[address]~=expected then return false,'race'end
        memory[address]=desired
        if a.fail_after_commit then a.fail_after_commit=false;return false,'flush failed'end
        return true
    end
    a.memory=memory;a.original=original;a.site=a.game+P.patch_rva
    return a,Hook.new(a,P,B)
end

-- Off has no game reads, fingerprint work, allocation or code writes.
local a,h=fixture()
for i=1,1000 do check(h.disable(),'disable')end
check(a.reads==0 and a.exchanges==0 and a.allocations==0 and a.verifies==0,'off touches game')
check(h.enable() and h.active and h.installed,'enable')
local patch=a.memory[a.site]
check(patch:sub(4)==a.original:sub(4) and patch:sub(1,3)~=a.original:sub(1,3),'CALL displacement tail changed adjacent instructions')
check(a.control and a.allocations==1,'control/one allocation')
check(h.disable() and not a.control and a.memory[a.site]==a.original,'disable did not restore exact 8 bytes')
check(h.enable() and a.allocations==1,'toggle reallocates native pages')
check(h.disable(),'second off')

a,h=fixture();check(h.enable(),'prepare CALL prefix ownership')
a.memory[a.game+P.instruction_rva]='changed prefix'
check(not h.audit()and not h.active and not a.control,'externally changed CALL prefix stayed active')
local before=a.exchanges
check(h.disable()and a.exchanges==before,'audit cleanup overwrote external CALL prefix change')
a,h=fixture();check(h.enable(),'prepare direct prefix restore refusal')
a.memory[a.game+P.instruction_rva]='changed prefix';before=a.exchanges
check(not h.disable()and a.exchanges==before,'external CALL prefix change was overwritten')

for _,reason in ipairs({'refuse_build','refuse_allocation','refuse_exchange'})do
    a,h=fixture();a[reason]=true
    check(not h.enable() and not h.active and a.memory[a.site]==a.original,reason..' changed code')
end
a,h=fixture();a.memory[a.game+P.pins[1].rva]='changed'
check(not h.enable() and a.exchanges==0 and a.allocations==0,'pin mismatch wrote')
a,h=fixture();a.memory[a.site]='occupied'
check(not h.enable() and a.exchanges==0,'other mod overwritten')
a,h=fixture();a.entry=0x900000000
check(not h.enable() and a.exchanges==0 and not a.control,'out-of-range relative jump')
a,h=fixture();a.entry=0x200000b1
check(not h.enable()and a.exchanges==0 and not a.control,'incompatible CALL low byte was accepted')
a,h=fixture();a.fail_after_commit=true
check(not h.enable() and h.installed and not h.active and not a.control,'failed post-commit transaction not tracked')
check(h.disable() and a.memory[a.site]==a.original,'post-commit rollback failed')
a,h=fixture();check(h.enable(),'prepare external ownership test');a.memory[a.site]='another!'
local n=a.exchanges
check(not h.disable() and a.exchanges==n and not a.control,'rollback overwrote external owner')
a,h=fixture();check(h.enable(),'prepare restore retry');a.refuse_exchange=true
check(not h.disable() and h.installed and not h.active and not a.control,'failed restore kept predicate active')
a.refuse_exchange=false
check(h.disable() and a.memory[a.site]==a.original,'restore retry')
a,h=fixture();check(h.enable(),'prepare deferred page cleanup');a.refuse_cleanup=true
check(not h.disable() and h.cleanup_pending and not h.active and a.memory[a.site]==a.original,'pending page cleanup was hidden')
a.refuse_cleanup=false
check(h.disable() and not h.cleanup_pending,'deferred page cleanup retry')
a,h=fixture();check(h.enable(),'prepare audit');a.memory[a.site]='changed!'
check(not h.audit() and not h.active and not a.control,'external change not deactivated')
a,h=fixture();check(h.enable(),'prepare final diagnostics')
function a.native_stats()return {visits=27,primary_seen=7,local_matches=5}end
a.blocked=5
check(h.disable() and h.blocked==5 and h.native_stats.visits==27,
    'shutdown lost native diagnostics or final counters')

local function menu_fixture(saved_value)
    local m={api=1,version=3,values={},pending={},callbacks={},registrations=0}
    if saved_value~=nil then m.values[Controller.OPTION]=saved_value end
    function m.register_option(id,spec)
        m.registrations=m.registrations+1
        if id==Controller.OPTION then m.spec=spec end
        if m.refuse then return false,'category full'end
        if m.values[id]==nil then m.values[id]=spec.default end
        return true
    end
    function m.get(id)return m.values[id]end
    function m.on_change(id,fn)m.callbacks[id]=fn end
    function m.apply(value)m.values[Controller.OPTION]=value;m.callbacks[Controller.OPTION](value)end
    return m
end
local function controller_fixture(menu)
    local env=menu and {ModOptionsMenu=menu}or{}
    local a,h=fixture()
    local statuses,logs={},{}
    local c=Controller.new(env,h,function(k)return k end,function(s)logs[#logs+1]=s end,
        function(state)statuses[#statuses+1]={active=state.active,reason=state.reason,registered=state.registered}end)
    return c,a,h,env,statuses,logs
end
local m=menu_fixture(false)
local c,ca,ch,env,statuses=controller_fixture(m)
c.step()
check(m.registrations==1 and m.spec.type=='toggle' and m.spec.default==true,'one option, primary default ON')
check(m.spec.mod_id==Controller.MOD_ID and type(m.spec.label)=='function','stable category/localized label')
check(not c.enabled and not c.active and ca.verifies==0 and ca.exchanges==0,'saved manual OFF must remain off')
m.pending[Controller.OPTION]=true
c.step()
check(not c.active and ca.exchanges==0,'unapplied edit took effect')
m.apply(true)
check(c.enabled and c.active and ch.active,'APPLY on did not activate')
m.pending[Controller.OPTION]=false;c.step()
check(c.active,'unapplied off disabled feature')
m.apply(false)
check(not c.active and ca.memory[ca.site]==ca.original,'APPLY off did not restore')
for i=1,1500 do c.step()end
check(m.registrations==1,'duplicate registrations/callbacks')
m.apply(true);c.pause('lower update failed')
check(not c.active and not ca.control and ca.memory[ca.site]==ca.original,'pause did not restore')
c.step()
check(c.active,'resume did not honor saved toggle')
c.stop('shutdown')
check(not c.active and ca.memory[ca.site]==ca.original,'shutdown did not restore')
c.step();check(not c.active,'stopped mod reinstalled')
check(statuses[#statuses].active==false,'status reported active after shutdown')
-- Menu may load later; saved/applied value is honored, never a second INI authority.
c,ca,ch,env=controller_fixture(nil)
for i=1,20 do c.step()end
check(ca.verifies==0,'missing dependency touched game')
m=menu_fixture();m.values['primary_pickup_tools.primary_pickup_blocker.enabled']=false;env.ModOptionsMenu=m;c.step()
check(c.active and c.registered,'late menu / persisted ON')
check(m.values[Controller.OPTION]==true,'legacy 0.1.0 OFF suppressed requested default ON')
env.ModOptionsMenu=nil;c.step()
check(not c.active and ca.memory[ca.site]==ca.original,'menu removal did not disable')
m=menu_fixture();m.refuse=true;c,ca,ch=controller_fixture(m);c.step()
check(not c.active and not c.registered and ca.exchanges==0,'refused menu still active')
m=menu_fixture(false);m.version=1;c,ca,ch=controller_fixture(m);c.step()
check(type(m.spec.label)=='string','legacy menu requires text strings')
check(not c.set('true') and not c.enabled,'nonboolean option accepted')
m=menu_fixture(false);c,ca,ch=controller_fixture(m);ca.fail_after_commit=true;c.step();m.apply(true)
check(not c.active and not ca.control and ca.memory[ca.site]==ca.original,'controller post-commit rollback')
-- Fresh installs start ON; an explicit OFF in v2 remains OFF across a new controller.
m=menu_fixture();c,ca,ch=controller_fixture(m);c.step()
check(c.enabled and c.active,'fresh installation is not ON')
m.apply(false);c.stop('first session end')
c,ca,ch=controller_fixture(m);c.step()
check(not c.enabled and not c.active and ca.verifies==0,'manual OFF did not survive restart')

print('PASS '..checks..' Lua lifecycle/menu checks; explicit simulated engine/system boundary')
