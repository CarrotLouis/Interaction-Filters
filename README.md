# Interaction-Filters / 交互过滤

**这是隔离测试版，仅启用主武器选项；实际过滤和稳定性待游戏内验收。**

用于绝地潜兵 2 的本地交互过滤模组，避免捡回支援武器时误捡同位置的地面
主要武器。通过 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu)
提供独立开关，无需自定义按键。

用户已经完成对照：装入 0.2.2，在死亡前也会闪退；移除后，一次死亡与增援正常。具体致崩函数仍未确认。证据和已确认的身份比较错误见 [排查记录](docs/INVESTIGATION.md)。

本包将装备来源观察、来源历史和全部来源引擎查询从成品中移除，以隔离原生筛选与来源路径。只注册原有的主武器开关，首次默认 ON；以前应用的主武器 OFF 仍保留。五个可选过滤在本包不注册、不执行，其保存值不被改写。完整六选项需求未取消，需在隔离后继续恢复验证。

已修正一个确定错误：描述符 +0x0C 是单位句柄，玩家管理器 +0x3A8 是 avatar 网络 ID；应与描述符 +0x10 的网络 ID 比较。新的对照使用独立数值，覆盖旧版误放行、误匹配、无 avatar、重生后网络 ID 更新及单位复用。旧版测试混淆这两个命名空间，虽然通过也不能作为功能验收。

关闭游戏，导入 `Interaction-Filters-0.2.3-primary-only-test.zip` 替换旧版，启用并重新部署，再启动。沿用 GUID `8681784c-3da8-42e0-8982-3b4a2480b2d1` 和资源 `mods/primary_pickup_tools/primary_pickup_blocker`，不要并存。仍需 Bingus Shared Loader v18+ 和 Mod Options Menu v1.1+。Esc → MODS → 交互过滤 · 主武器隔离测试 → 禁止捡起地面主武器 → 应用。无按键绑定。

建议一次任务中测试：开启时不能拾取地面主武器，关闭并应用后恢复拾取，再开启并完成死亡/增援。用户已验证的移除基线不必重复。来源查询已隔离不等于原生路径已证实稳定；若本版仍崩溃，应沿原生路径继续隔离，不能直接归咎来源查询。

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

English: PRIMARY-ONLY ISOLATION TEST, not the full six-option release. The user reproduced an installed-mod crash before death and a successful death/reinforcement after removal. This package removes the entire equipment/source observer and its engine-query path, corrects avatar network-ID comparison, and preserves the primary setting. Five optional rows are absent and their saved values are retained. Offline checks do not establish actual stability or identify the exact old crash function.
