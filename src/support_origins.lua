-- Independent implementation of the reference mod's frozen call-in-source rule.
local M={UNKNOWN=0,OWN=1,TEAM=2,FIELD=3}
function M.new()
    local t={history={},early={},loading=true,epoch=nil,counts={},histories=0}
    function t.reset(epoch)
        t.history={};t.early={};t.loading=true;t.epoch=epoch;t.counts={};t.histories=0;t.capacity_exceeded=false
    end
    function t.observe(snapshot,now)
        if not snapshot then t.counts={};return {}end -- invalidate publication, retain origin history
        if not snapshot.active then t.reset(nil);return {}end
        if snapshot.epoch~=t.epoch then t.reset(snapshot.epoch)end
        local items=snapshot.items or {}
        if t.loading then
            for _,item in ipairs(items)do
                t.early[item.entity..':'..item.unit]=true
            end
        end
        -- The reference's initial-map boundary includes support packs as well
        -- as weapons. Packs only supply this signal; they never enter the cache.
        if snapshot.carried_gear then t.loading=false end
        local out={};local counts={own=0,team=0,field=0,unknown=0}
        for _,item in ipairs(items)do
            -- The reference keys the story by entity + unit. A goid can be
            -- assigned after the first observation; that must not erase map origin.
            local key=item.entity..':'..item.unit
            local h=t.history[key]
            if not h then
                if t.histories>=4096 then t.capacity_exceeded=true;return {}end
                h={};t.history[key]=h;t.histories=t.histories+1
            end
            if not h.first then
                if item.carried or item.podded then h.first='squad'
                elseif item.free then h.first='free'end
            end
            if item.carried or item.podded then t.loading=false end
            if snapshot.owned and item.goid>0 and item.goid<4294967295 and not h.decided then
                h.asked=h.asked or now
                if snapshot.owned[item.goid] then h.mine=true end
                if now-h.asked>=1.5 then h.decided=true end
            end
            local class=M.UNKNOWN
            if h.first=='free' and t.early[key] then class=M.FIELD
            elseif h.first and h.decided then class=h.mine and M.OWN or M.TEAM end
            if class==M.OWN then counts.own=counts.own+1
            elseif class==M.TEAM then counts.team=counts.team+1
            elseif class==M.FIELD then counts.field=counts.field+1
            else counts.unknown=counts.unknown+1 end
            if class~=M.UNKNOWN then out[#out+1]={entity=item.entity,class=class,record=item.record}end
        end
        -- A carried item can temporarily disappear from the interactable list.
        -- Keep its frozen story until mission/session reset, as the reference does.
        t.counts=counts
        table.sort(out,function(a,b)return a.entity<b.entity end)
        if #out>512 then t.capacity_exceeded=true;return {}end
        t.capacity_exceeded=false
        return out
    end
    return t
end
return M
