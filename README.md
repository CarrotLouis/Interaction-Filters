# Interaction-Filters / 交互过滤

**0.2.3 已撤回：2026-10-17 用户两次测试均在下潜后闪退。不要继续开启过滤进行普通游玩；目前没有已确认稳定的版本。**

用于绝地潜兵 2 的本地交互过滤模组，避免捡回支援武器时误捡同位置的地面
主要武器。通过 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu)
提供独立开关，无需自定义按键。

0.2.3 的两次失败均已核对版本，且均未进入主武器判定/拦截分支；来源查询也不在此版本中。原生补丁安装后约 27 秒和 92 秒退出。用户确认出现普通游戏崩溃报告、没有看到错误码。详见 [排查记录](docs/INVESTIGATION.md)。

本包将装备来源观察、来源历史和全部来源引擎查询从成品中移除，以隔离原生筛选与来源路径。只注册原有的主武器开关，首次默认 ON；以前应用的主武器 OFF 仍保留。五个可选过滤在本包不注册、不执行，其保存值不被改写。完整六选项需求未取消，需在隔离后继续恢复验证。

已修正一个确定错误：描述符 +0x0C 是单位句柄，玩家管理器 +0x3A8 是 avatar 网络 ID；应与描述符 +0x10 的网络 ID 比较。新的对照使用独立数值，覆盖旧版误放行、误匹配、无 avatar、重生后网络 ID 更新及单位复用。旧版测试混淆这两个命名空间，虽然通过也不能作为功能验收。

已撤回包的身份为 `Interaction-Filters-0.2.3-primary-only-test.zip`，GUID 为 `8681784c-3da8-42e0-8982-3b4a2480b2d1`，资源为 `mods/primary_pickup_tools/primary_pickup_blocker`。历史依赖为 Bingus Shared Loader v18+ 与 Mod Options Menu v1.1+。这些资料用于核对历史安装，不代表推荐继续启用。

下一项必要对照是保留同一模组，在舰船设置中关闭“禁止捡起地面主武器”并应用，之后始终关闭再进入任务、正常活动 3–5 分钟。此时不安装原生补丁；不要求再次开启，也不要求为了触发故障故意死亡。该对照用于区分加载/轮询路径与启用原生补丁路径，仍不是修复包。用户已完成的移除基线不必重复。

日志仍在 `%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/PrimaryPickupBlocker.log` 和 `PrimaryPickupBlocker-STATUS.txt`。核对 `build_id=0.2.3-primary-only.1`、`runtime_profile=primary_only_isolation`、`source_observer=not_included`。舰船上 active=false 正常；任务中 active=true 仅表示安装完成。候选、ID 匹配与拦截需结合实际拾取验证。

仅支持 Steam build25480438，模块文件和14处原生签名需吻合。完整成品的源码门禁拒绝来源查询符号及可选项注册；打包后再次核对 Lua 资源逐字节相等。离线验证不会启动、附加或部署游戏。

## 工程与构建

```text
src/          Lua 模块与生成的原生字节
native/       x64 汇编源码
tests/        LuaJIT、Unicorn 与最小回归夹具
scripts/      汇编、校验、测试、打包和源码导出
docs/         设计、构建、验证、排查与后续范围
vendor/       允许分发的共享源码、原许可和来源校验
build/        本地中间产物与验证报告，忽略
outputs/      本地交付 ZIP、说明与校验，忽略
external/     单独取得的构建依赖，忽略
```

配置 Python 3.12、固定开发依赖、x64 GNU 工具链及本机 Lua DLL 后：

```powershell
python -B scripts/build.py
python -B scripts/export_source.py --output-dir outputs
```

- [开发环境与完整命令](docs/DEVELOPMENT.md)
- [技术设计](docs/TECHNICAL.md) / [验证边界](docs/VALIDATION.md)
- [待恢复的五个可选项与来源规则](docs/ROADMAP.md)
- [版本记录](CHANGELOG.md) / [贡献与同步流程](CONTRIBUTING.md)
- [第三方许可与来源](THIRD_PARTY_NOTICES.md)

原始 0.2.2 六选项实现保存在最早的 `archive:` 历史提交，已撤回，不用于安装。
本仓库沿用原工程的 [0BSD 许可](LICENSE)，第三方代码保留各自许可。
每组后续修改完成后验证、提交并推送；`outputs/` 等生成内容始终忽略。

English: WITHDRAWN. Two confirmed 0.2.3 runs exited shortly after entering a mission, without reaching any primary predicate or blocking branch. Source observers were absent. The user confirms the ordinary game crash reporter, with no visible error code. The initial cause remains unknown. Current code is retained for investigation, not a stable release. Do not claim a fix or re-enable the native patch for normal play.
