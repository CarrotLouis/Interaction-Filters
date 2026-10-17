# Interaction-Filters / 交互过滤

**当前为 0.2.4 原生入口修订测试版，仅主武器。离线验证通过后交付，实机过滤和稳定性仍待验收。0.2.2、0.2.3 已撤回。**

用于绝地潜兵 2 的本地交互过滤，避免捡回支援武器时误捡同位置的主武器。
设置位于 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu)，不需要自定义按键。

## 本轮修订与已知结果

0.2.3 开启后两次任务退出；同一版本关闭开关后，用户一次任务未闪退。
日志确认这次关闭对照没有安装原生代码。它将重点缩到启用原生路径，尚不能证明
某一条指令就是致崩原因。0.2.3 两次失败也未进入任何主武器判定/拦截分支。

0.2.4 不再从候选循环中段跳出并压栈。它保留原生 CALL/RET，在原有候选收集完成后，
仅移除本机角色的主武器候选，保留其他候选顺序及原来的筛选条件。动态代码注册
Windows x64 展开信息，安装前核对模块文件、原生签名和 CALL 位移。

已发现的旧架构缺陷是缺少可用于原函数中段跳出代码的栈展开信息；新方案消除
这一缺陷。旧版最初退出机制仍未证实，不能把本版称为已确认的闪退修复。
详见 [原生入口设计](docs/NATIVE-ENTRY.md) 和 [排查记录](docs/INVESTIGATION.md)。

## 安装与测试

需要 Bingus Shared Loader v18+、Mod Options Menu v1.1+；仅支持 Steam build 25480438。
关闭游戏，导入 `Interaction-Filters-0.2.4-call-wrapper-test.zip` 替换旧版并重新部署。
沿用 GUID `8681784c-3da8-42e0-8982-3b4a2480b2d1` 和资源
`mods/primary_pickup_tools/primary_pickup_blocker`，不要同时安装两份。

在 **Esc → MODS → 交互过滤 · 原生入口测试** 开启主武器选项并点击“应用”。
首次默认开启；**上次测试保存的关闭值会保留，需要手动打开**。
先在任务中正常活动 3–5 分钟，再验证主武器不能捡、支援武器仍能捡，最后验证
关闭恢复和死亡/增援。如果再次退出，保存日志后停用，不继续反复触发。

仅提供主武器选项。队友/野生支援、样本瓶、样本及场景信息五项暂不注册、
不执行，其保存值保留；完整需求仍在 [ROADMAP](docs/ROADMAP.md)。
来源观察及其引擎查询没有恢复。

日志为 `%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/PrimaryPickupBlocker.log`
及 `PrimaryPickupBlocker-STATUS.txt`。核对 `build_id=0.2.4-call-wrapper.1`、
`runtime_profile=primary_call_wrapper`。`native.visits` 现为收集函数调用次数，
`primary_seen` 与 `blocked_candidates` 为主武器候选观察/移除计数，均非实际拾取次数。
`native.unwind_registered=true` 只表示本进程展开信息已注册，不表示稳定性验收通过。

## 工程

```text
src/          Lua 模块与生成的原生字节
native/       当前 CALL 包装器和撤回版汇编参考
tests/        LuaJIT、Unicorn、Windows 执行/展开回归
scripts/      汇编、校验、测试、打包和源码导出
docs/         构建、设计、验证、排查和后续范围
vendor/       可分发共享源码、原许可和校验
build/        本地中间产物与证据，忽略
outputs/      本地交付 ZIP 与说明，忽略
external/     单独取得的依赖，忽略
```

准备 [开发环境](docs/DEVELOPMENT.md) 后：

```powershell
python -B scripts/build.py
python -B scripts/export_source.py --output-dir outputs
```

- [技术说明](docs/TECHNICAL.md) / [验证范围](docs/VALIDATION.md)
- [版本记录](CHANGELOG.md) / [贡献与同步](CONTRIBUTING.md)
- [第三方来源](THIRD_PARTY_NOTICES.md) / [0BSD 许可](LICENSE)

后续每组修改完成后验证、提交并推送。所有 `outputs/`、构建产物、私人日志、
转储及依赖都不提交。历史完整六项实现保存在初始 `archive:` 提交中。

English: 0.2.4 CALL-wrapper TEST, primary only; live acceptance pending. The user
reported two enabled 0.2.3 mission crashes and a successful OFF control. This
candidate preserves a normal call/return, filters the local actor's collected
primary candidates and registers Win64 unwind metadata before publication.
Saved OFF remains OFF. Five optional filters remain unavailable. No crash cause
or actual stability is claimed as proven by offline tests.
