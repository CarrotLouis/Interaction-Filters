# Interaction-Filters / 交互过滤

**当前为 0.2.5 仅入口诊断包，不拦截任何交互。用户已同意这次对照，游戏内结果待测。0.2.2、0.2.3、0.2.4 均已撤回。**

最终目标是只过滤安装者的交互，防止拾回支援武器时误捡同位置的主武器。
设置使用 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu)，无自定义按键。
六项功能的默认值和来源规则仍见 [ROADMAP](docs/ROADMAP.md)。当前没有交付可用的过滤版。

## 为什么做入口对照

0.2.3 开启后两次任务退出，关闭时用户一次任务未闪退。更换正常 CALL/RET
和动态展开表的 0.2.4 仍在任务内启用约22秒后退出。其最终记录为843次原函数
返回、843次本机匹配、404个类型13候选，主武器观察/拦截均为0。
本机身份比较已经执行成功，但这不能证明此后的读取或整个原生路径安全。

0.2.4 的小转储仍为 shutdown 之后约5秒的 EXE+0x626296 调度器读异常，
初始故障点未知。没有证据将普通崩溃报告认定为反作弊报错，也没有证据将
“已补展开表”当作已经解决闪退。详见 [排查记录](docs/INVESTIGATION.md)。

0.2.5 保留相同 CALL 位置、调用帧、展开表、分配与恢复，只递增自有计数并
原样调用收集函数一次。生产机器码不含角色、玩家、交互对象、候选、保留目标
读取或过滤写入。详见 [诊断设计](docs/ENTRY-PROBE.md)。

## 本次安装与测试

需要 Bingus Shared Loader v18+、Mod Options Menu v1.1+；仅支持 Steam build 25480438。
关闭游戏，导入 `Interaction-Filters-0.2.5-entry-only-diagnostic.zip` 替换旧版并部署。
沿用 GUID `8681784c-3da8-42e0-8982-3b4a2480b2d1`、原资源和原主武器保存 ID，
不要同时安装两份。

1. 在舰船 **Esc → MODS → 交互过滤 · 仅入口诊断** 开启“启用入口诊断（不拦截武器）”并应用。
2. 下潜后正常活动约3分钟；若正常，可返回舰船或正常退出。不要求武器或死亡测试。
3. 若闪退，报告阶段即可，不需要重复同一对照。

**能够捡起主武器是本版的预期行为。** 首次默认 ON，已有开关值保留。
其余五项仍不提供，保存值保留。关闭并应用会恢复本 mod 拥有的 CALL 位移。

日志为 `%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/PrimaryPickupBlocker.log`
及 `PrimaryPickupBlocker-STATUS.txt`。应见 `build_id=0.2.5-entry-only.1`、
`runtime_profile=entry_only_probe`、`filter_body=not_included`、`filtering_available=false`。
`native.entry_calls` / `native.returned_calls` 是进入/返回计数，每约5秒记录；
调用仍在执行时二者可以暂时不等。零进入计数的未闪退不能算入口对照通过。

若实际进入后仍退出，已移除的读取/过滤不是必要条件；若稳定，只能缩到移除
路径或时序差异。一次对照都不能证明具体致崩指令或完整过滤功能已经修复。

## 工程

```text
src/          Lua 模块和当前生成的原生字节
native/       当前 entry_probe.S；撤回版汇编保留为历史参考
tests/        当前诊断、Windows 实际调用/展开、历史筛选回归
scripts/      汇编、源码/FFI门禁、测试、打包和源码导出
docs/         构建、诊断、设计、证据与后续范围
vendor/       可分发共享源码及校验
build/        本地构建证据，忽略
outputs/      本地交付包，忽略
external/     独立依赖，忽略
```

按 [开发环境](docs/DEVELOPMENT.md) 准备依赖，再运行：

```powershell
python -B scripts/build.py
python -B scripts/export_source.py --output-dir outputs
```

[验证范围](docs/VALIDATION.md) / [技术说明](docs/TECHNICAL.md) /
[贡献与同步](CONTRIBUTING.md) / [版本记录](CHANGELOG.md) /
[第三方来源](THIRD_PARTY_NOTICES.md) / [0BSD许可](LICENSE)。
每组完成的修改均验证、提交和推送。任何 outputs、私人日志、转储、游戏文件和依赖均不提交。

English: 0.2.5 ENTRY-ONLY DIAGNOSTIC, NO FILTERING, user-approved live control pending.
0.2.4 still crashed after22seconds with zero primary blocks and is withdrawn.
The same CALL/frame/unwind/allocator path remains; actor/candidate reads and all
filter writes are absent. Enable/APPLY, enter a mission and play about3minutes.
Primary pickups are expected to work. Zero entry calls make a stable run inconclusive.
