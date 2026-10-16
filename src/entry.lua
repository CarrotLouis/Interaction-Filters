-- The entry is assembled after the byte-identical shared runtime and our modules.
local version='0.2.2'
local BUILD_ID='0.2.2-dev.1'
local GUIDE=[===[Primary Pickup Blocker - quick guide
交互过滤 / Interaction Filters 0.2.2 本机身份判定修订测试版
由 Primary Pickup Blocker 升级，保留同一 mod 标识。

安装：关闭游戏，将 ZIP 导入 Arsenal 或 HD2MM，替换旧版、启用并部署。
另需 Bingus Shared Loader v18+（建议 v19）和 Mod Options Menu v1.1+。
已有 Vanilla Plus Megapack 的菜单组件时使用一份菜单即可。
Shared Loader 的启动资源需要在管理器冲突处理中取得优先权。
更新后重启游戏。不要同时启用新旧两个版本。

位置：Esc → MODS → 交互过滤 / INTERACTION FILTERS。
六个独立开关，修改后点击 APPLY / 应用：
1. 禁止捡起地面主武器：默认开启。
2. 禁止捡起队友的支援武器：默认关闭。
3. 禁止捡起野生支援武器：默认关闭。
4. 禁止拾取样本瓶：默认关闭；指掉落的样本容器。
5. 禁止拾取样本：默认关闭；指普通、稀有及超级样本。
6. 禁止场景信息交互：默认关闭；指按交互键阅读背景信息，
   例如自动售货机、工具、叉车。任务终端、载具座位照常使用。
每个选项独立生效；关闭主要武器过滤后，其余开启的选项仍然生效。
全部关闭时恢复原有交互。没有自定义快捷键，不需要 Mod Bindings Menu。

仅在已确认的任务状态运行。舰船、菜单、加载阶段不安装筛选、不查询来源。
舰船上的 enabled=true / active=false 是正常状态；进入任务后自动生效。
仅过滤游戏当前本机角色 ID 对应的交互候选。
不再额外要求固定角色资源和网络归属标记；远端角色仍按不同 ID 放行。
本人和队友掉落的主武器都归主要武器。
支援武器按 Where's My Shit 的原始来源观察规则区分：
本人召唤的武器仍可捡回；队友召唤的武器被你拿过再丢下仍归队友；
地图原生武器被玩家拿过再丢下仍归野生。无需安装 Where's My Shit。
为保留原来源，在任务内持续做只读观察，即使这两个选项关闭。
新支援武器的召唤归属通常需要约 1.5 秒观察；来源未知或读取失败时允许拾取。
来源观察在启动约 20 秒后开始；连续读取消耗过高时自行停止，状态文件会说明原因。
从任务开始加载本 mod 可记录地图初始装备；中途加入无法完整重建此前历史。
不修改掉落物、武器定义或网络数据。其他玩家按原生逻辑处理。
已有拾取动作不会倒回；被过滤的物品不参与后续候选排序。

升级默认：首次从 0.1.0 升级时，主要武器开关采用新的默认开启保存项。
旧版测试后保存的关闭状态不沿用；此后手动关闭并应用会正常保存。
五个新增项首次默认为关闭，此后各自保留应用后的值。

0.2.0 已由用户报告舰船闪退。0.2.1 增加任务状态保护，
用户本次复测反馈不再闪退，但仍能捡起主武器。
0.2.1 日志确认任务内已安装筛选、主武器开关已开启、拦截数为 0。
旧日志没有分阶段计数，不能确定是哪一道原生条件放行。
0.2.2 修订本机身份判定，并增加原生候选分阶段计数。
尚待实际拾取复测；不要把离线检查当作已确认生效。
0.1.0 日志确认的失败原因：附近内存分配失败，筛选没有安装。
新版改用完整跳转范围的 Windows 分配方式，并记录分配方法和错误码。
仅支持 Steam build 25480438；模块哈希或指令签名不符时不启用筛选。
已通过离线逻辑、实际菜单 API、游戏 Lua DLL、私有测试进程分配、
原生指令仿真和包内容检查；本版尚未进游戏复测，仍是测试候选版。

日志：%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\PrimaryPickupBlocker.log
状态：同目录 PrimaryPickupBlocker-STATUS.txt。
设置：同目录 ModOptionsMenu.values（由菜单保存）。
状态中的 filter.* 是六个应用后的值；active=true 才表示筛选已安装。
reason 是未生效原因；blocked.* 是各类候选拦截计数，并非捡取次数。
origin_reason / origin_* 显示支援武器来源观察状态。
native.visits 是原生候选路径执行次数，native.primary_seen 是主武器候选数，
native.local_matches 是已启用候选匹配本机角色的次数。
native.local_not_ready / different_actor 记录本机角色未就绪或其他角色。
native.legacy_rejected 记录匹配本机 ID、但旧资源/归属条件会放行的候选数。
这些新计数用于查证实际路径，不代表已确认旧版零拦截的具体原因。
日志在任务中每约 15 秒记录一行 Native candidates；状态及退出时保留累计计数。
复测建议：先仅开启主武器过滤，在任务中靠近地面主武器并尝试拾取，
再关闭并应用，确认能恢复拾取；重生后重复。其余选项可随后分别测试。
升级会保留已应用的六项设置；五个新增项仅首次默认为关闭。

English: Import this ZIP in Arsenal/HD2MM, replacing the older mod, then restart.
Requires Bingus Shared Loader and Mod Options Menu; no hotkey dependency.
Esc > MODS > INTERACTION FILTERS > choose the six independent toggles > APPLY.
Primary defaults ON; teammate support, field support, dropped sample bottles,
loose samples and scenery-information interactions all default OFF.
Only your local Helldiver's selected categories are excluded before ranking.
Ship/menu/loading states do not install a native hook or query equipment sources.
The user reports no crash with 0.2.1, but primary pickups still succeed.
0.2.2 uses the exact current local-unit identity without blueprint/authority assumptions,
and adds staged native counters. The old log cannot prove the failing predicate stage.
This candidate's actual filtering and stability remain pending live re-test.
Support origin follows the reference's frozen call-in/map rule, not the last holder.
Own call-ins remain recoverable; unknown sources pass. Observe from mission start.
Only Steam build 25480438. OFFLINE-VERIFIED TEST CANDIDATE; live acceptance pending.
]===]

local loader=rawget(_G,'CowboyBingusModLoader')
local directory=loader and loader.log_directory
local log_file
if directory then log_file=io.open(directory..'/PrimaryPickupBlocker.log','a')end
local function timestamp()return os.date('!%Y-%m-%dT%H:%M:%SZ')end
local function note(message)
    if log_file then
        pcall(function()log_file:write(timestamp()..' '..tostring(message)..'\n');log_file:flush()end)
    end
end
local function write_status(c,hook)
    if not directory then return end
    pcall(function()
        local f=io.open(directory..'/PrimaryPickupBlocker-STATUS.txt','w')
        if not f then return end
        f:write('version='..version..'\nbuild_id='..BUILD_ID..'\nutc='..timestamp()..
            '\nsupported_steam_build='..profile.steam_build..'\nvalidation=offline_only\n'..
            'menu_registered='..tostring(c.registered)..'\nenabled='..tostring(c.enabled)..
            '\nfilter_mask='..c.mask..'\nactive='..tostring(c.active)..'\nreason='..tostring(c.reason)..
            '\ngame_state='..tostring(c.game_state or 'Unknown')..'\nin_mission='..tostring(c.in_mission or false)..
            '\nblocked_candidates='..tostring(hook.blocked)..'\n')
        for i,d in ipairs(controller_factory.DEFS)do
            f:write('filter.'..d.key..'='..tostring(c.filters[d.key])..'\n'..
                'blocked.'..d.key..'='..tostring(hook.counters and hook.counters[i]or 0)..'\n')
        end
        local stats=hook.native_stats or {}
        for _,key in ipairs({'visits','primary_seen','enabled_candidates','descriptor_missing',
            'local_not_ready','different_actor','local_matches','legacy_rejected','last_type',
            'last_actor_unit','last_local_unit','last_resource','last_flags','retained_cleared',
            'last_seen_type','seen_types','type_1','type_3','type_10','type_11','type_48'})do
            f:write('native.'..key..'='..tostring(stats[key]or 0)..'\n')
        end
        f:write('origin_reason='..tostring(c.origin_reason or 'waiting')..'\n'..
            'origin_published='..tostring(c.origin_published or 0)..'\n'..
            'origin_capacity_exceeded='..tostring(c.origin_capacity_exceeded or false)..'\n'..
            'origin_reads='..tostring(c.origin_reads or 0)..'\norigin_read_bytes='..tostring(c.origin_bytes or 0)..
            '\norigin_last_ms='..tostring(c.origin_ms or 0)..'\n')
        for _,key in ipairs({'own','team','field','unknown'})do
            f:write('origin_'..key..'='..tostring(c.origin_counts and c.origin_counts[key]or 0)..'\n')
        end
        local a=hook.allocation
        if a then
            f:write('allocation_backend='..tostring(a.backend or 'none')..'\n'..
                'allocation_queries='..tostring(a.queries)..'\nallocation_attempts='..tostring(a.attempts)..
                '\nallocation_last_error='..tostring(a.last_error)..'\n')
        end
        f:close()
    end)
end
local translation=bingus_text.new(locales.english,locales.bundled,function(s)note('Text: '..s)end)
local function text(key)translation:refresh();return translation:text(key)end
local memory=bingus_memory.new(bingus_runtime)
local mission=mission_factory.new(memory,profile)
local native=hook_factory.new(windows_factory.new(memory,near_allocator,note),profile,native_blob)
local origins=origins_factory.new()
local origin_reader=origin_reader_factory.new(memory,profile,_G,mission)
local origin_at,origin_now,status_at,last_origin_reason=0,0,0,nil
local native_status_at=0
local origin_interval,origin_slow,origin_disabled=0.25,0,false
local controller=controller_factory.new(_G,native,text,note,write_status)
controller.set_scope(false,'game modules not ready','Unknown')
local last_epoch
controller.version=version
controller.build_id=BUILD_ID
rawset(_G,'PrimaryPickupBlocker',controller)
local function step(dt)
    mission.poll()
    if last_epoch~=mission.epoch then
        last_epoch=mission.epoch
        origins.reset(nil);native.publish({});origin_at=0
    end
    controller.set_scope(mission.mission,mission.reason,mission.state)
    controller.step()
    if not controller.registered then return end
    origin_now=origin_now+((type(dt)=='number' and dt>0 and dt<2)and dt or 0.016)
    if not mission.mission then
        if controller.origin_published~=0 or controller.origin_reason~=mission.reason then
            native.publish({});origins.reset(nil)
            controller.origin_published=0;controller.origin_counts={}
            controller.origin_reason=mission.reason;controller.origin_reads=0;controller.origin_bytes=0
        end
    elseif not origin_disabled and origin_now>=origin_at then
        local started=os.clock()
        local snapshot=origin_reader.snapshot(origin_now)
        local rows=origins.observe(snapshot,origin_now)
        local cost=(os.clock()-started)*1000
        controller.origin_ms=cost
        if cost>8 then
            origin_slow=origin_slow+1;origin_interval=math.min(origin_interval*2,4)
        else origin_slow=0;origin_interval=0.25 end
        if origin_slow>=3 then origin_disabled=true;rows={}end
        origin_at=origin_now+origin_interval
        native.publish(rows)
        controller.origin_counts=origins.counts
        controller.origin_reason=origin_disabled and 'source monitor disabled after repeated slow reads' or origin_reader.reason
        controller.origin_published=#rows
        controller.origin_capacity_exceeded=origins.capacity_exceeded
        controller.origin_reads,controller.origin_bytes=origin_reader.reads,origin_reader.bytes
    end
    if origin_now>=status_at then
        status_at=origin_now+5
        if last_origin_reason~=controller.origin_reason then
            last_origin_reason=controller.origin_reason
            note('Support sources: '..tostring(last_origin_reason)..'; published='..controller.origin_published)
        end
        write_status(controller,native)
        if native.active and origin_now>=native_status_at then
            native_status_at=origin_now+15
            local d=native.native_stats or {}
            note(string.format('Native candidates: visits=%d primary=%d enabled=%d local=%d not_ready=%d other_actor=%d legacy_rejected=%d blocked=%d; last_type=%d actor_unit=%d local_unit=%d resource=%s flags=%d; last_seen_type=%d types=%s',
                d.visits or 0,d.primary_seen or 0,d.enabled_candidates or 0,d.local_matches or 0,
                d.local_not_ready or 0,d.different_actor or 0,d.legacy_rejected or 0,native.blocked,
                d.last_type or 0,d.last_actor_unit or 0,d.last_local_unit or 0,
                tostring(d.last_resource or 'unobserved'),d.last_flags or 0,
                d.last_seen_type or 0,tostring(d.seen_types or 'none')))
        end
    end
end
local guard=bingus_runtime.guard({name='PrimaryPickupBlocker',step=step,
    pause=controller.pause,stop=controller.stop,log=note,env=_G}).install()
controller.guard=guard
note('Startup '..BUILD_ID..'; primary default ON; five new filters default OFF; waiting for applied values.')
write_status(controller,native)
return controller
