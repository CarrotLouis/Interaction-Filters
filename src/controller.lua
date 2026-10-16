-- Six independent options; one native mask, no master/hotkey dependency.
local M={MOD_ID='primary_pickup_tools.primary_pickup_blocker'}
M.DEFS={
    {key='primary',id=M.MOD_ID..'.enabled_v2',default=true,bit=0},
    {key='team_support',id=M.MOD_ID..'.team_support',default=false,bit=1},
    {key='field_support',id=M.MOD_ID..'.field_support',default=false,bit=2},
    {key='sample_bottle',id=M.MOD_ID..'.sample_bottle',default=false,bit=3},
    {key='sample',id=M.MOD_ID..'.sample',default=false,bit=4},
    {key='info',id=M.MOD_ID..'.info',default=false,bit=5},
}
M.OPTION=M.DEFS[1].id
function M.new(env,hook,text,note,status)
    local c={enabled=false,active=false,mask=0,filters={},reason='off',registered=false,frames=0}
    local seen,attempted,stopped,paused,failed=nil,false,false,false,false
    local permitted,scope_reason=true,'Mission'
    for _,d in ipairs(M.DEFS)do c.filters[d.key]=false end
    local function publish(reason)
        local active=hook.active and c.enabled and not stopped and not paused
        if c.reason~=reason or c.active~=active then
            c.reason,c.active=reason,active
            note('mask='..c.mask..' enabled='..tostring(c.enabled)..' active='..tostring(active)..' '..reason)
        end
        status(c,hook)
    end
    local function off(reason)
        local ok,why=hook.disable()
        publish(ok and reason or tostring(why))
    end
    local function apply()
        local mask=0
        for _,d in ipairs(M.DEFS)do if c.filters[d.key]then mask=mask+2^d.bit end end
        if c.mask~=mask then failed=false end
        c.mask,c.enabled=mask,mask~=0
        if mask==0 then off('off');return end
        if not permitted then off(scope_reason);return end
        if stopped or paused or failed then return end
        local ok,why=hook.configure(mask)
        if not ok then hook.disable();failed=true end
        publish(ok and 'active' or tostring(why))
    end
    function c.set_option(key,value)
        if c.filters[key]==nil or type(value)~='boolean'then return false end
        c.filters[key]=value;apply();return true
    end
    function c.set(value)return c.set_option('primary',value)end
    function c.set_scope(allowed,reason,state)
        assert(type(allowed)=='boolean','mission scope must be boolean')
        local changed=permitted~=allowed
        permitted,scope_reason=allowed,reason or 'waiting for mission'
        c.in_mission,c.game_state=allowed,state or 'Unknown'
        if changed then failed=false end
        if not permitted then
            if c.active or hook.installed or c.reason~=scope_reason then off(scope_reason)end
        elseif changed and c.enabled then apply()end
    end
    function c.step()
        c.frames=c.frames+1
        if stopped then return end
        if paused then paused=false;failed=false;apply()end
        if hook.cleanup_pending or (not c.enabled and hook.installed)then off('native cleanup')end
        local menu=rawget(env,'ModOptionsMenu')
        if not menu or menu.api~=1 or type(menu.register_option)~='function'then
            if c.enabled or c.active then
                for _,d in ipairs(M.DEFS)do c.filters[d.key]=false end
                c.mask,c.enabled=0,false;off('waiting for ModOptionsMenu')
            end
            seen,attempted,c.registered=nil,false,false
            return
        end
        if menu~=seen then seen,attempted,c.registered=menu,false,false end
        if not attempted then
            attempted=true
            local translated=type(menu.version)=='number' and menu.version>=2
            local function label(key)
                if translated then return function()return text(key)end end
                return text(key)
            end
            local all=true
            for _,definition in ipairs(M.DEFS)do
                local d=definition
                local ok,why=menu.register_option(d.id,{type='toggle',default=d.default,mod_id=M.MOD_ID,
                    mod=label('name'),label=label(d.key),description=label(d.key..'_description')})
                if ok then
                    menu.on_change(d.id,function(value)c.set_option(d.key,value)end)
                else all=false;note('Registration refused '..d.id..': '..tostring(why))end
            end
            c.registered=all
            note('Registered six independent interaction filters; complete='..tostring(all))
        end
        if c.registered then
            local changed=false
            for _,d in ipairs(M.DEFS)do
                local value=menu.get(d.id)
                if type(value)=='boolean' and value~=c.filters[d.key]then c.filters[d.key]=value;changed=true end
            end
            if changed then apply()end
        end
        if c.frames%300==0 then
            local ok,why=hook.audit()
            if not ok then c.active=false;failed=true;publish(tostring(why))end
            status(c,hook)
        end
    end
    function c.pause(reason)paused=true;off('paused: '..tostring(reason))end
    function c.stop(reason)stopped=true;off('stopped: '..tostring(reason))end
    return c
end
return M
