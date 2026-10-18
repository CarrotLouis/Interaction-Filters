# Interaction-Filters / 交互过滤

**全部已交付版本均已撤回。0.2.5仅入口诊断也在实际执行后退出；当前没有可推荐安装的过滤包。源码只保留用于离线复现，打包与源码ZIP导出已被门禁禁止。**

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

0.2.5 保留相同入口，删除了角色/候选读取和过滤写入，但依旧退出：
北京时间2026-10-18 14:17:15安装，14:17:46 shutdown，间隔31秒。
14:17:43的进入/返回计数均954；最终STATUS的返回计数1114。
因此这些被删除的操作不是该次退出的必要条件，应排查共同的原生机制和运行环境。
这不证明所有退出都出于同一原因，也没有把代码写入、分配或反作弊中的某项定为根因。

[HD2Runtime原文](https://github.com/SkyeShade/HD2Runtime/blob/master/docs/events.md#why-events-are-polled)
明确使用无detour、无游戏`.text`写入的观察方式。此前本项目选择了直接改写游戏入口；
当前停止沿这条路线发测试包，重新研究不改游戏代码且仅影响本机的后端。
[研究边界](docs/NATIVE-FREE-RESEARCH.md)记录了现有允许列表等方案的限制，尚无已证明的替代实现。

最新[缓存研究](docs/CACHE-BACKEND-RESEARCH.md)已复现旧版保留目标的结构错误，
并找到正常帧中无需跳板即可处理本机目标的窗口。8项离线原生消费者测试通过；
对象寿命、其他更新入口及真实拾取尚待验证，不代表闪退或过滤已修复。

## 当前使用与证据

请停用0.2.5，无需重复相同对照。不会自动修改游戏安装或其他模组。
此前手动关闭和移除后的对照仍有效，不要求重新做一遍。所有六项需求、默认值、
来源规则和保存ID均保留在[ROADMAP](docs/ROADMAP.md)，不以全局禁用替代本机过滤。

当前[发布策略](release-policy.json)是`withdrawn`、`user_live_status=failed`、
`packaging_allowed=false`。普通build和source-export会在生成交付目录前拒绝。
历史ZIP保留在本地忽略目录供追溯，不能因离线检查通过而重新交付。

日志和转储均已保存至本地incidents，私人材料不上传。
0.2.5转储的UTC头时间06:17:51Z，仍在本mod的shutdown之后约5秒，
为EXE+0x626296的调度器读异常。最初故障点未知。
追加日志的进入/返回计数完整；发现STATUS遗漏这两个新字段，故最终进入数未知，
不能把最终返回数1114写成最终双计数相等。这个记录缺口不影响已确认入口执行，
也不构成要求用户重复测试的理由。后续后端应补齐状态输出契约。

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
python -B scripts/build.py --verify-only
```

只有新后端通过审查并有对应发布策略后，才允许恢复打包。

[验证范围](docs/VALIDATION.md) / [技术说明](docs/TECHNICAL.md) /
[贡献与同步](CONTRIBUTING.md) / [版本记录](CHANGELOG.md) /
[第三方来源](THIRD_PARTY_NOTICES.md) / [0BSD许可](LICENSE)。
每组完成的修改均验证、提交和推送。任何 outputs、私人日志、转储、游戏文件和依赖均不提交。

English: ALL DELIVERED BUILDS WITHDRAWN. The entry-only0.2.5 control also exited
31seconds after activation, with954/954 paired entry/return counts at its last log
sample and1114 final returns. Actor/candidate reads and filter writes are not
necessary for that exit. The first fault remains unknown. No anti-cheat attribution
is proven. Do not repeat the same control; no replacement live package is offered.
Packaging/source-ZIP export is refused by release-policy.json even when offline gates pass.
Research now requires a backend without game-code detours/.text writes and with
proven local-player scope. Original feature requirements remain unfinished.
