-- Primary-only diagnostic derivative; no equipment/source observer is assembled.
local version='0.2.3'
local BUILD_ID='0.2.3-primary-only.1'
local GUIDE=[===[Primary Pickup Blocker - quick guide
交互过滤 0.2.3：仅主武器隔离测试版

用途：排查 0.2.2 的异常退出，并单独验证主武器过滤。
这是隔离测试包，尚未确认修复实际闪退。

关闭游戏后导入 ZIP，替换旧版、启用并重新部署，再启动游戏。
沿用原 GUID 和资源名，不要同时安装新旧两份。
需要 Bingus Shared Loader v18+ 和 Mod Options Menu v1.1+。

Esc → MODS → 交互过滤 · 主武器隔离测试。
本版仅注册“禁止捡起地面主武器”，首次默认开启；改动后点击“应用”。
之前保存的主武器开关值仍保留。没有自定义按键。
其余五项不在本隔离版中注册或执行；其保存值不被改写。
完整六选项需求保留，需在本次隔离后继续恢复验证。

本版成品不包含装备来源扫描、来源历史模块或来源引擎查询。
因此队友/野生支援、样本瓶、样本、场景信息均不被本版过滤。
原生筛选仍限定安装者当前 avatar。舰船、菜单和加载状态不安装筛选。
本机身份按网络 ID 比较：角色描述符 +0x10 对玩家管理器 +0x3A8。
旧版将单位句柄 +0x0C 与网络 ID 混比，已离线复现该错误。
无当前 avatar（网络空值 0x7FFF）时放行；每次候选重新读取身份。

建议一次任务内依次验证：
1. 开关开启并应用，尝试拾取掉落主武器，应无法拾取。
2. 关闭并应用，确认原有拾取恢复；再开启。
3. 完成一次死亡与增援，观察稳定性与重生后的过滤。
4. 保留日志，再关闭游戏。

日志与状态仍为 CowboyBingus/Helldivers2/Logs 下的
PrimaryPickupBlocker.log 和 PrimaryPickupBlocker-STATUS.txt。
确认 build_id=0.2.3-primary-only.1、runtime_profile=primary_only_isolation。
source_observer=not_included、source_engine_calls=0 表示被隔离路径未打入包。
native.primary_seen / local_matches / blocked_candidates 分别记录候选、
本机网络 ID 匹配及拦截计数；这些不是实际捡取次数。
日志每约 15 秒记录原生摘要，退出前采集最终计数。

仅支持 Steam build 25480438。实际过滤和稳定性均待本版游戏内验证。
移除 0.2.2 后死亡与增援正常是用户已完成的对照，不需再重复该基线。
本版停止来源路径以继续隔离，尚不能仅凭旧转储认定具体致崩函数。

English: PRIMARY-ONLY ISOLATION TEST; not the full six-option build.
Replace the old mod and restart. Same GUID/resource/primary setting key.
Only primary filtering is registered; the five other settings are untouched.
Equipment/source observers and their engine queries are absent from this package.
Avatar NETWORK IDs are compared, rather than a unit handle against a network ID.
Test primary ON/OFF, then death/reinforcement. Live stability remains unverified.
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
            '\nruntime_profile=primary_only_isolation\nsource_observer=not_included\nsource_engine_calls=0\n'..
            'supported_steam_build='..profile.steam_build..'\nvalidation=offline_only\n'..
            'menu_registered='..tostring(c.registered)..'\nenabled='..tostring(c.enabled)..
            '\nfilter_mask='..c.mask..'\nfilter.primary='..tostring(c.filters.primary)..
            '\nactive='..tostring(c.active)..'\nreason='..tostring(c.reason)..
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
controller.runtime_profile='primary_only_isolation'
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
            native_at=now+15
            local d=native.native_stats or {}
            note(string.format('Native primary isolation: visits=%d primary=%d enabled=%d local=%d not_ready=%d other_actor=%d blocked=%d; actor_unit=%d actor_network_id=%d local_network_id=%d types=%s',
                d.visits or 0,d.primary_seen or 0,d.enabled_candidates or 0,d.local_matches or 0,
                d.local_not_ready or 0,d.different_actor or 0,native.blocked,d.last_actor_unit or 0,
                d.last_actor_network_id or 0,d.last_local_network_id or 0,tostring(d.seen_types or 'none')))
        end
    end
end
local guard=bingus_runtime.guard({name='PrimaryPickupBlocker',step=step,
    pause=controller.pause,stop=controller.stop,log=note,env=_G}).install()
controller.guard=guard
note('Startup '..BUILD_ID..'; PRIMARY ONLY; source observer NOT INCLUDED; avatar NETWORK ID comparison; live test pending.')
write_status(controller,native)
return controller
