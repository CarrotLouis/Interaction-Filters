local version='0.3.0'
local BUILD_ID='0.3.0-cache-primary.1'
local GUIDE=[===[Primary Pickup Blocker - quick guide
交互过滤 0.3.0：主武器过滤测试版（新缓存后端）

本版重新实现本机潜兵的地面主武器手动拾取过滤。首次默认开启，已有手动关闭值
仍保留。其余五项暂未恢复，保存值不删除；本包不是完整六项版本。
旧0.2.x包均已撤回，请用本包替换，不要同时安装两份。

关闭游戏后导入 Interaction-Filters-0.3.0-cache-primary-test.zip，并重新部署。
依赖 Bingus Shared Loader v18+ 和 Mod Options Menu v1.1+。
Esc → MODS → 交互过滤 · 主武器测试版 → 禁止捡起地面主要武器 → 应用。
不需要自定义按键。仅支持 Steam build 25480438，版本或指令证据不符则拒绝工作。

新实现不再使用撤回版的原生跳转入口、可执行页或动态展开表，也不调用游戏函数。
在普通Lua更新结束后、原生角色更新之前，重新解析本机网络ID及交互者；仅当当前
目标确为主要武器时，用同一份本机候选中允许的最高分目标替换，或将目标清空。
所有权、实体映射、空间槽位、候选范围、可用状态和写入前后值均检查。
只改本人交互者当前目标的8字节，不改世界武器、候选列表、共享模板或其他玩家。
原生消费者仍检查实际交互条件，不强制发出拾取请求。
关闭、暂停、死亡或退出时不回写旧指针；停止过滤后由原生刷新恢复正常目标选择。

请先进行一次新的验证：
1. 舰船确认开启并应用，进入任务正常活动至少3分钟，确认是否仍闪退。
2. 若稳定，在主武器单独落地时尝试拾取；再将支援武器与主武器放在同一位置，
   确认能捡支援武器、不会误捡主武器。关闭并应用后确认能重新捡主武器。
3. 再测试死亡、增援后过滤是否正常。房主/客机均待实机验证。
若闪退，报告发生阶段即可；不要继续重复同一崩溃测试。

日志：CowboyBingus/Helldivers2/Logs/PrimaryPickupBlocker.log 和
PrimaryPickupBlocker-STATUS.txt。应显示build_id=0.3.0-cache-primary.1，
runtime_profile=local_retained_cache，backend.primary_seen、backend.replaced/
backend.cleared为实际观察/改写次数；active=true本身不证明过滤成功。
写入验证失败时停止过滤，日志记录原因；无法确认布局时放行。

限制：目前仅处理主武器的手动拾取。自动交互、支援武器来源、样本及场景选项
尚未恢复。离线验证不能保证游戏内稳定性；额外世界更新路径及其他mod的更新
顺序可能影响覆盖，须依据这次的新日志和任务测试判断。尚未安装、启动或附加游戏。

English: PRIMARY-ONLY TEST CANDIDATE, NEW DATA-CACHE BACKEND. Default ON; saved OFF
is honored. The other five filters remain unavailable with their saved values preserved.
Replace older versions; requires Bingus Shared Loader v18+ and Mod Options Menu v1.1+.
Only the local actor's current retained target is changed. No game-code modifications,
executable allocations, engine calls, or saved-pointer restoration. First test mission
stability, primary/support pickups, OFF/APPLY, then death/reinforcement. Live acceptance
and host/client behavior remain pending; offline gates are not a stability guarantee.
]===]
local loader=rawget(_G,'CowboyBingusModLoader')
local directory=loader and loader.log_directory
local log_file=directory and io.open(directory..'/PrimaryPickupBlocker.log','a')or nil
local function timestamp()return os.date('!%Y-%m-%dT%H:%M:%SZ')end
local function note(message)
    if log_file then pcall(function()
        log_file:write(timestamp()..' '..tostring(message)..'\n');log_file:flush()
    end)end
end
local function write_status(c,backend)
    if not directory then return end
    pcall(function()
        local f=io.open(directory..'/PrimaryPickupBlocker-STATUS.txt','w')
        if not f then return end
        f:write('version='..version..'\nbuild_id='..BUILD_ID..'\nutc='..timestamp()..
            '\nruntime_profile=local_retained_cache\nfiltering_available=primary_manual\nsource_observer=not_included\n'..
            'supported_steam_build='..profile.steam_build..'\nvalidation=offline_only\n'..
            'menu_registered='..tostring(c.registered)..'\nenabled='..tostring(c.enabled)..
            '\nfilter.primary='..tostring(c.filters.primary)..'\nactive='..tostring(c.active)..
            '\nreason='..tostring(c.reason)..'\ngame_state='..tostring(c.game_state or 'Unknown')..'\n')
        local keys={}
        for key in pairs(backend.stats)do keys[#keys+1]=key end
        table.sort(keys)
        for _,key in ipairs(keys)do f:write('backend.'..key..'='..tostring(backend.stats[key])..'\n')end
        f:close()
    end)
end
local translation=bingus_text.new(locales.english,locales.bundled,function(s)note('Text: '..s)end)
local function text(key)translation:refresh();return translation:text(key)end
local memory=bingus_memory.new(bingus_runtime)
local mission=mission_factory.new(memory,profile)
local backend=cache_factory.new(memory,writer_factory.new(memory),profile)
local controller=controller_factory.new(_G,backend,text,note,write_status)
controller.set_scope(false,'game modules not ready','Unknown')
controller.version,controller.build_id=version,BUILD_ID
controller.runtime_profile='local_retained_cache'
rawset(_G,'PrimaryPickupBlocker',controller)
local now,status_at=0,0
local function scope()
    mission.poll();controller.set_scope(mission.mission,mission.reason,mission.state)
end
local function step(dt)
    scope();controller.step()
    now=now+((type(dt)=='number'and dt>0 and dt<2)and dt or 0.016)
end
local function after()
    -- Recheck after lower Lua updates; the native game plugin runs on return.
    scope();controller.filter_frame()
    if now>=status_at then
        status_at=now+5;write_status(controller,backend)
        local s=backend.stats
        note(string.format('Cache: active=%s frames=%d local=%d primary=%d support=%d replaced=%d cleared=%d reason=%s',
            tostring(controller.active),s.frames,s.local_matches,s.primary_seen,s.support_seen,s.replaced,s.cleared,s.reason))
    end
end
local guard=bingus_runtime.guard({name='PrimaryPickupBlocker',step=step,after=after,
    pause=controller.pause,stop=controller.stop,log=note,env=_G}).install()
controller.guard=guard
note('Startup '..BUILD_ID..'; primary-only data-cache candidate; source observer NOT INCLUDED; live result pending.')
write_status(controller,backend)
return controller
