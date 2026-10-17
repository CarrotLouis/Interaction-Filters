-- Primary-only diagnostic derivative; no equipment/source observer is assembled.
local version='0.2.4'
local BUILD_ID='0.2.4-call-wrapper.1'
local GUIDE=[===[Primary Pickup Blocker - quick guide
交互过滤 0.2.4：原生入口修订测试

此包替换已撤回的 0.2.3，仅提供主武器选项。实机过滤和稳定性仍待验证。
用户已完成的对照是：0.2.3 开启后两次任务退出，关闭后一次任务未闪退。
本版更换原生入口，不再从候选循环中段跳出和压栈。
保留原生 CALL/RET，在原有候选收集完成后过滤本机角色的主武器候选。
动态代码注册 Windows x64 栈展开信息，且在安装前核对所有原生签名。
这些改动消除已发现的结构问题，不能据此宣布找到了旧版最初致崩原因。

关闭游戏，导入本 ZIP 替换旧版，启用并重新部署后再启动。
需要 Bingus Shared Loader v18+ 与 Mod Options Menu v1.1+，无自定义按键。
Esc → MODS → 交互过滤 · 原生入口测试 → 禁止捡起地面主武器 → 应用。
首次默认开启；上次为排查保存的关闭值会保留，测试前需要手动打开并应用。
使用原 GUID、资源名和保存项，不要同时安装两份。

建议依次验收：
1. 打开并应用，下潜后正常活动 3–5 分钟，先确认稳定性。
2. 尝试拾取地面主武器，应无法拾取；同位置支援武器应仍可拾取。
3. 关闭并应用，主武器应恢复拾取；再按需测试死亡与增援。
若再次退出，保留日志与转储，停止继续开启本版。

只有本机角色且网络 ID 对应时过滤，其他角色保持原有候选。
无当前 avatar、未知类型、无效索引或超限哈希查询均放行。
舰船、菜单与加载状态不安装，关闭时恢复本 mod 拥有的 CALL 位移。
候选顺序保留；主武器的保留目标会清除，让其他候选继续原有流程。

队友/野生支援、样本瓶、样本和场景信息五项仍暂不提供，其保存值不改写。
本版没有装备来源观察或所有权引擎查询，不需要 HD2Runtime。
仅支持 Steam build 25480438。来源分类及完整六选项版本仍未验收。

日志为 CowboyBingus/Helldivers2/Logs 下的 PrimaryPickupBlocker.log 与
PrimaryPickupBlocker-STATUS.txt。核对 build_id=0.2.4-call-wrapper.1、
runtime_profile=primary_call_wrapper、source_observer=not_included。
任务中 native.unwind_registered=true 表示本进程展开信息已注册。
active=true 只表示入口已安装；native.visits 是收集函数调用次数，
primary_seen 与 blocked_candidates 是主武器候选观察/移除计数，均非实际拾取次数。
开关关闭后计数保留，原生页面与展开表保留到进程退出，避免仍在运行的调用失效。

English: 0.2.4 CALL-wrapper TEST, primary only. Live acceptance is pending.
Replace 0.2.3 and restart. Same resource/GUID/setting. A saved OFF remains OFF.
Enable and APPLY before testing. Verify mission stability, primary ON/OFF and support recovery.
The original collector is called once; a normal RET returns to its unchanged caller.
Windows x64 unwind information is registered before publication. No source observer is included.
Five optional filters remain absent and their saved values remain unchanged.
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
            '\nruntime_profile=primary_call_wrapper\nsource_observer=not_included\nsource_engine_calls=0\n'..
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
controller.runtime_profile='primary_call_wrapper'
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
            note(string.format('Native CALL wrapper: calls=%d primary=%d enabled=%d local=%d not_ready=%d other_actor=%d blocked=%d; actor_unit=%d actor_network_id=%d local_network_id=%d types=%s',
                d.visits or 0,d.primary_seen or 0,d.enabled_candidates or 0,d.local_matches or 0,
                d.local_not_ready or 0,d.different_actor or 0,native.blocked,d.last_actor_unit or 0,
                d.last_actor_network_id or 0,d.last_local_network_id or 0,tostring(d.seen_types or 'none')))
        end
    end
end
local guard=bingus_runtime.guard({name='PrimaryPickupBlocker',step=step,
    pause=controller.pause,stop=controller.stop,log=note,env=_G}).install()
controller.guard=guard
note('Startup '..BUILD_ID..'; CALL wrapper with registered Win64 unwind; source observer NOT INCLUDED; live test pending.')
write_status(controller,native)
return controller
