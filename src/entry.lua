-- Entry-only diagnostic; no role/candidate reads or filtering body is assembled.
local version='0.2.5'
local BUILD_ID='0.2.5-entry-only.1'
local GUIDE=[===[Primary Pickup Blocker - quick guide
交互过滤 0.2.5：仅入口诊断，不拦截武器

这是用户同意测试的定位工具，不是过滤功能修复版。所有交互保持原有行为。
0.2.4 开启后在任务内约22秒退出，843次本机匹配但没有主武器拦截；本版用于
区分共同的原生入口/调用机制与已经删除的角色读取、候选读取和过滤逻辑。

关闭游戏后，导入 Interaction-Filters-0.2.5-entry-only-diagnostic.zip 替换旧版，
启用并重新部署。需要 Bingus Shared Loader v18+ 与 Mod Options Menu v1.1+。
Esc → MODS → 交互过滤 · 仅入口诊断 → 启用入口诊断（不拦截武器）→ 应用。
沿用原 GUID、资源、保存项，首次默认开启，已有开关值会保留。不要同时安装两份。

本次只需一次测试：
1. 舰船上确认诊断开启并应用，再进入任务，正常活动约3分钟。
2. 若未闪退，正常返回舰船或退出游戏；不用专门测试武器、死亡或增援。
3. 若闪退，直接报告发生阶段，不需要重复同一测试。日志随后由维护者保存。
这版能捡起主武器是预期结果，不应把它当成过滤失败。

入口沿用0.2.4的CALL位置、正常调用帧、动态展开表、分配与恢复机制。
它只递增自有内存中的进入/返回计数，并按原参数调用原生收集函数一次。
不接收Lua回调，不读取角色、玩家管理器、交互对象、候选列表或保留目标，
也不修改上述数据。舰船和加载阶段不安装，关闭并应用后恢复拥有的CALL位移。
其余五个选项仍不提供；保存值保留。本次结果不证明其他模组或反作弊是否相关。

日志位于 CowboyBingus/Helldivers2/Logs/PrimaryPickupBlocker.log 与
PrimaryPickupBlocker-STATUS.txt。核对 build_id=0.2.5-entry-only.1、
runtime_profile=entry_only_probe、filtering_available=false、filter_body=not_included。
native.entry_calls和native.returned_calls分别为进入/返回次数；在调用过程中
可能暂时不相等。没有进入计数的“未闪退”不能算入口稳定性对照通过。
日志约每5秒记录计数，关闭或退出时再记录最终计数。原生页保留到进程退出。

若入口实际执行后仍退出，角色读取/候选修改不是必要条件，应继续查共同的
入口、分配、调用环境与模组组合。若本次稳定，只能缩小到删除的过滤路径
或相关时序差异，不能宣布已定位具体指令，更不能宣布过滤已修好。
仅支持Steam build 25480438；离线检查不能替代本次游戏内结果。

English: ENTRY-ONLY DIAGNOSTIC, NO FILTERING. Same CALL site/frame/unwind as0.2.4.
Enable and APPLY on the ship, enter a mission and play normally for about3minutes.
The wrapper counts entry/return and calls the original once. It does not read player,
actor, candidate or interactable data and does not change any interaction candidates.
Ground primary pickups are expected to work. A run with zero entry calls is inconclusive.
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
local function write_status(c,hook)
    if not directory then return end
    pcall(function()
        local f=io.open(directory..'/PrimaryPickupBlocker-STATUS.txt','w')
        if not f then return end
        f:write('version='..version..'\nbuild_id='..BUILD_ID..'\nutc='..timestamp()..
            '\nruntime_profile=entry_only_probe\nfiltering_available=false\nfilter_body=not_included\nsource_observer=not_included\nsource_engine_calls=0\n'..
            'supported_steam_build='..profile.steam_build..'\nvalidation=offline_only\n'..
            'menu_registered='..tostring(c.registered)..'\nenabled='..tostring(c.enabled)..
            '\nfilter_mask='..c.mask..'\nfilter.primary='..tostring(c.filters.primary)..
            '\nnative.unwind_registered='..tostring(hook.unwind_registered or false)..'\nactive='..tostring(c.active)..'\nreason='..tostring(c.reason)..
            '\ngame_state='..tostring(c.game_state or 'Unknown')..
            '\nin_mission='..tostring(c.in_mission or false)..
            '\nblocked_candidates='..tostring(hook.blocked)..'\n')
        local d=hook.native_stats or {}
        for _,key in ipairs({'visits','primary_seen','enabled_candidates','descriptor_missing',
            'local_not_ready','different_actor','local_matches','legacy_rejected','last_type',
            'last_actor_unit','last_actor_network_id','last_local_network_id','last_resource',
            'last_flags','retained_cleared','last_seen_type','seen_types'})do
            f:write('native.'..key..'='..tostring(d[key]or 0)..'\n')
        end
        local a=hook.allocation
        if a then f:write('allocation_backend='..tostring(a.backend or 'none')..
            '\nallocation_attempts='..tostring(a.attempts)..'\nallocation_last_error='..
            tostring(a.last_error)..'\n')end
        f:close()
    end)
end
local translation=bingus_text.new(locales.english,locales.bundled,function(s)note('Text: '..s)end)
local function text(key)translation:refresh();return translation:text(key)end
local memory=bingus_memory.new(bingus_runtime)
local mission=mission_factory.new(memory,profile)
local native=hook_factory.new(windows_factory.new(memory,near_allocator,note),profile,native_blob)
local controller=controller_factory.new(_G,native,text,note,write_status)
controller.set_scope(false,'game modules not ready','Unknown')
controller.version,controller.build_id=version,BUILD_ID
controller.runtime_profile='entry_only_probe'
rawset(_G,'PrimaryPickupBlocker',controller)
local now,status_at,native_at=0,0,0
local function step(dt)
    mission.poll()
    controller.set_scope(mission.mission,mission.reason,mission.state)
    controller.step()
    now=now+((type(dt)=='number'and dt>0 and dt<2)and dt or 0.016)
    if now>=status_at then
        status_at=now+5;write_status(controller,native)
        if native.active and now>=native_at then
            native_at=now+5
            local d=native.native_stats or {}
            note(string.format('Native entry probe: entered=%d returned=%d; filter_body=not_included blocked=0',
                d.entry_calls or 0,d.returned_calls or 0))
        end
    end
end
local guard=bingus_runtime.guard({name='PrimaryPickupBlocker',step=step,
    pause=controller.pause,stop=controller.stop,log=note,env=_G}).install()
controller.guard=guard
note('Startup '..BUILD_ID..'; ENTRY ONLY DIAGNOSTIC; filter body NOT INCLUDED; source observer NOT INCLUDED; live result pending.')
write_status(controller,native)
return controller
