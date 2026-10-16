> 历史源码快照：0.2.2 已撤回，有闪退和身份判定错误。此提交仅用于保留完整六选项实现，不能用于安装。

# Interaction Filters / 交互过滤

**2026-10-17 对照已完成：** 重装 0.2.2 后，未死亡也闪退；移除后一次死亡与增援正常。当前组合中本 mod 的稳定性问题需继续处理，之前“移除后的死亡基线未完成”状态已更新。最新失败运行只记录到类型13，未进入已启用类别或目标清除分支；来源监视器已运行。独立的 `PrimaryPickupBlocker-PrimaryIsolation` 工程提供 0.2.3 仅主武器隔离候选，来源路径不打入包，网络 ID 比较已修正；实际稳定性仍待复测。此处 0.2.2 源码与历史安装包继续撤回。

**2026-10-16 后续调查：0.2.2 暂停使用。** 用户报告任务死亡后闪退。死亡退出与移除此 mod 后主动 Alt+F4 的小转储均落在引擎任务调度器 EXE+0x626296，不能据此精确定位初始触发点；移除后的死亡/增援对照尚未完成。同时已确认代码把 avatar 网络 ID（玩家管理器 +0x3A8）与单位句柄（描述符 +0x0C）混比，正确字段应为描述符网络 ID +0x10。离线对照已复现该错误，尚未发布新的死亡修复安装包。以下是原 0.2.2 候选的设计与验证历史，其“当前本机角色 ID”解释需要按此更正。

**0.2.2 本机身份判定修订测试版，实际过滤效果待复测。** 用户反馈 0.2.1 不再闪退，但仍能拾取主武器。已备份的 2026-10-16 日志确认运行 0.2.1-dev.1，任务内成功安装筛选，主武器选项开启，而六项拦截计数都为 0。旧日志未记录原生候选各阶段，因此尚不能确定当次运行在哪一步放行。

本版以游戏保存的当前本机角色 ID 判定交互者，要求恰好一个活动本机角色且 ID 有效；取消固定角色资源和网络归属标记这两个额外条件。原生分阶段计数区分路径未执行、未遇到主武器、本机身份不匹配及实际拦截，并记录旧条件会拒绝的本机候选。该改动通过原生指令测试，不等于已证明上次零拦截的确切原因。

保留 0.2.1 的任务状态保护：舰船、菜单、加载及未知状态不安装筛选、不读取装备来源，也不调用来源查询 API；空支援装备列表同样不调用这些 API。进入任务自动启用，返回舰船恢复原指令。0.2.0 的舰船闪退报告及转储调查仍留在验证记录中。

舰船上的 `enabled=true / active=false / game_state=Ship` 是正常状态，开关值仍保留。此前离线测试通过不等于真实游戏稳定，0.2.0 的验收状态已撤回。


从 Primary Pickup Blocker 升级，保留原来的资源名、GUID 及六项已应用设置。

只影响安装者的潜兵，避免需要捡回支援武器时误选同一位置的物品。在 Mod Options Menu 提供六个独立开关，修改后点击 **APPLY / 应用**。

| 选项 | 首次默认 |
| --- | --- |
| 禁止捡起地面主武器 | 开启 |
| 禁止捡起队友的支援武器 | 关闭 |
| 禁止捡起野生支援武器 | 关闭 |
| 禁止拾取样本瓶（掉落容器） | 关闭 |
| 禁止拾取样本（普通、稀有、超级） | 关闭 |
| 禁止场景信息交互（售货机、工具、叉车等背景信息） | 关闭 |

按原生交互类型识别。支援武器参考附件 Where's My Shit 1.0.1 的观察规则：地图开始时的原生装备归野生；召唤物在最初约 1.5 秒的归属观察后冻结来源。队友武器即使被你拿过再丢下仍归队友，野生武器也保留野生来源。本人召唤的武器允许捡回。来源未知或读取失败时允许拾取；从任务开始加载能记录初始地图装备，中途加入无法完整还原过去的历史。无需安装参考 mod。

来源观察在 mod 启动约 20 秒后开始，即使两个支援武器选项关闭也继续只读观察，以保留后来切换时所需的原来源。读取设有容量、次数、字节及耗时限制，连续消耗过高时停止来源查询，状态文件会显示原因。主武器、样本与场景信息过滤独立工作。

0.1.0 的真实日志显示附近内存分配失败。0.2.1 的实际日志已确认任务内 VirtualAlloc2 分配及筛选安装成功；这只能确认安装阶段，不能证明过滤生效。

安装需要 [Bingus Shared Loader v18+](https://github.com/CowboyBingus/BingusSharedLoader/releases/latest) 和 [Mod Options Menu v1.1+](https://github.com/CowboyBingus/ModOptionsMenu/releases/latest)。关闭游戏，导入新版替换旧版，重新部署并重启；不要同时启用两个版本。游戏中 **Esc → MODS → 交互过滤 / INTERACTION FILTERS**。没有自定义按键，不需要 Mod Bindings Menu；HD2Runtime 是开发参考。

首次从 0.1.0 升级时，主要武器使用新的默认开启保存项，旧版测试后保存的关闭值不沿用。之后手动关闭并应用会保留。五个新增项各自保存应用后的值，关闭主要武器不会关闭其余开启的选项。

仅支持 Steam build 25480438。哈希和原生指令核对一致后才安装筛选。过滤发生在候选排序前，不修改武器定义、掉落对象或网络数据；其他玩家沿用原有候选路径。副武器、背包、任务终端、载具座位等不在这六类中。已开始的拾取不会倒回。全部关闭、暂停及退出时恢复属于本 mod 的原指令；四页自有内存保留至进程退出。

日志及状态位于 `%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/PrimaryPickupBlocker.log` 和 `PrimaryPickupBlocker-STATUS.txt`。`filter.*` 是应用后的值；`active=true` 仅表示已安装；`blocked.*` 是候选拦截计数，非捡取次数；`origin_*` 是来源读取状态。新增 `native.visits / primary_seen / local_matches / legacy_rejected` 等计数，以及候选角色 ID、资源和标记样本。任务中每约 15 秒写一行原生摘要；退出前采集最终累计计数。字段样本为低频诊断，多个原生线程更新时不保证属于同一候选。

构建与验证见 [技术说明](docs/TECHNICAL.md)、[验证状态](docs/VALIDATION.md)。完整安装指南从 Lua 源码提取进 ZIP，源码包包含测试及构建证据。未导入管理器、部署或启动游戏；实际任务、房主/客机及 GameGuard 兼容性仍待验证。

English: Six independent local-player filters with unchanged defaults and settings. The user reports 0.2.1 no longer crashes, but primary pickups still work despite successful installation. 0.2.2 uses the current local-unit identity, removes blueprint/authority assumptions and adds staged native diagnostics. The old log cannot establish the failing predicate stage. Offline-verified candidate; this version's live acceptance remains pending.
