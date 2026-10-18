# 版本记录

## 0.3.0 / 0.3.0-cache-primary.1 — 主武器缓存后端测试候选

- 移除当前artifact的游戏代码跳转、原生页分配及引擎函数调用，改在Lua更新after中
  处理本人当前目标。只写本机行首8字节，原生条件检查继续生效。
- 每帧重新解析网络ID、角色行、空间槽和payload；提交前重验，覆盖槽位销毁/复用、
  行压缩、死亡/增援、待处理请求及OFF。停止后不回写旧指针。
- 生产Lua输出交给保留原生消费者独立执行，验证支援区域0/1/7、清空、OFF、
  房主拥有的其他角色与高位32位hash；增加45条布局指令证据。
- 主武器首次默认开启、保存OFF有效，其余五项尚未恢复且保存值保留。
- 新候选只允许审查SHA一致并通过完整离线门禁后打包；旧失败ID永久拒绝。
  没有实机验收或外部人工审查，旧闪退首个故障仍未知。

## 未发布 — 2026-10-18 缓存后端离线研究

- 复现0.2.4把保留空间记录当候选payload的缺陷：删完候选仍能提交保留的主武器。
  修正历史测试的范围说明，不修改或重新启用撤回的跳板。
- 追踪正常帧的Lua update -> 游戏插件 -> 角色手动交互 -> 候选刷新顺序。
  新增53条指令证据、3段小消费者及可只读核对本地保留代码/Lua导出的工具。
- 8项原生消费者模拟验证清空/替换本机保留目标可改变请求边界；未验证全部更新
  路径、对象寿命和真实拾取。发布策略仍禁止打包；未产生新运行时或交付ZIP。

## 2026-10-18 — entry-only control failed; all builds withdrawn

- 0.2.5 executed in the mission and exited31seconds after install. Last paired
  sample954/954; final return count1114; role/candidate/filter body absent.
- Withdraw the diagnostic and stop repeating the same native entry live control.
  No initial fault or anti-cheat cause is claimed as identified.
- Add release-policy.json: normal build/source-export refuse the live-failed build
  before delivery writes. --verify-only runs offline gates without permitting shipment.
- Record the missing STATUS entry/return fields; use paired log samples and final
  visits correctly. No new runtime ZIP is produced for this bookkeeping gap.
- Begin offline feasibility review of a backend with no game-code detours/writes;
  full six-option behavior is still unfinished.

## 0.2.5-entry-only.1 (WITHDRAWN) — 2026-10-18

- User-approved entry-only diagnostic, explicitly NO FILTERING. Same CALL site,
  call frame, unwind registration, allocator, ownership checks and restore path.
- Removes every role/player/candidate/retained-target read and all filter writes
  from the production native blob. Counts original collector entry and return.
- Keeps one clearly labelled diagnostic toggle and the previous persisted ID;
  five optional filter values remain untouched. Logs explicitly say filtering is absent.
- Checks unmapped engine arguments, private-only data access, actual Windows
  execution/unwinding and historical regressions before packaging.
- Live diagnostic result is pending. 0.2.4 is withdrawn, not a confirmed crash fix.

## 0.2.4 (WITHDRAWN) / 0.2.4-call-wrapper.1 — 原生入口修订候选

- 用户完成 0.2.3 保留加载、关闭开关的任务对照，没有闪退；日志未安装原生代码。
- 用原生 CALL 包装器替代函数中段 JMP，保留原调用与返回，在收集后移除本机主武器候选。
- 动态代码必须注册 Win64 展开信息；表和页面保留到进程退出。
- 对齐八字节 CAS 仅改 CALL 位移的高三字节，保留操作码、低字节、返回点与后续指令；前缀/所有权变化时拒绝覆盖。
- 增加真实 Windows 调用/栈展开与新包装器原生仿真；来源观察和五个可选项仍未恢复。
- 实机稳定性、过滤、同位置支援捡取及死亡增援待验收；未确认旧版最初致崩机制。

## 0.2.3 撤回与两次任务闪退调查 — 2026-10-17

- 已备份两次 0.2.3 运行记录及转储，确认来源观察不在成品中。
- 原生筛选安装后约 27 秒、92 秒退出，均未进入主武器判定或拦截分支。
- 两份转储记录任务调度器读访问异常，生成时间晚于 Lua shutdown，尚不能
  确定最初退出原因。用户确认是普通游戏崩溃报告，没有看到错误码。
- 撤回 0.2.3 的启用/安装推荐，保留原源码和历史交付文件以供排查。
- 增加已保存主武器 OFF 时整份入口的舰船/任务回归，确认对照状态不准备
  或安装原生代码、不执行来源查询。该测试不证明真实游戏的稳定性。
- 尚无已验证的闪退修复，不发布新的修复版本或伪装成可用过滤器的空功能包。

## 工程整理 — 2026-10-17

- 建立独立公开仓库 `CarrotLouis/Interaction-Filters`。
- 当前分支整理为 `src/`、`native/`、`tests/`、`scripts/`、`docs/`、`vendor/`。
- 在初始 Git 提交保留已撤回的完整 0.2.2 源码，便于排查和恢复可选项。
- 去除对旧工作目录的 Python 依赖路径和机器专用工具链路径。
- 以 `outputs/` 为默认交付目录；生成内容和私人排查材料不提交。
- 源码导出只依赖本次构建生成的证据，不要求私人历史排查目录。
- 记录后续每组修改验证、提交、推送并核对远端的维护规则。
- 本次整理保留 0.2.3 运行时源码和模组标识，不增加实机验证结论。

## 0.2.3 / 0.2.3-primary-only.1 — 隔离候选

- 仅注册主要武器过滤，首次默认开启；已保存的手动关闭值仍有效。
- 修正单位句柄与 avatar 网络 ID 混比的问题，改用描述符 `+0x10`。
- 不包含装备来源读取、来源历史及其引擎查询；五个可选项暂不显示，保存值保留。
- 增加身份命名空间、无 avatar、重生、单位复用和来源路径隔离回归。
- 离线构建与包检查通过；实际过滤、稳定性和房主/客机验收待完成。

## 0.2.2 / 0.2.2-dev.1 — 已撤回

- 保留六项独立设置，增加原生候选分阶段诊断。
- 用户报告启用后在任务死亡时、以及尚未死亡时闪退。
- 日志中本机匹配和拦截均为零；后来确认身份比较混用了两个 ID 命名空间。
- 移除后完成一次死亡与增援。具体致崩调用未确定，不再将故障限定为死亡事件。

## 0.2.1 — 历史

- 增加任务状态保护。用户一次测试未闪退，但仍可拾取主武器。

## 0.2.0 — 历史

- 增加五个默认关闭的可选项及来源观察；用户报告舰船阶段闪退。

## 0.1.0 — 历史

- 初始主要武器过滤；实际日志显示附近内存分配失败。

这里只描述已有实现与反馈，不把历史版本的模拟结果当作实机验收。
