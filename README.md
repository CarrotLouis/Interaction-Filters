# Interaction-Filters / 交互过滤

**0.3.0 是采用新缓存后端的主武器过滤测试包，尚待实机验收。旧0.2.x版本全部撤回；闪退的首个故障仍未定位。**

目的是防止拾回支援武器时误捡同位置的主武器。使用
[Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu)，无需自定义按键。
当前只提供“禁止捡起地面主要武器”，首次默认开启，已有手动关闭值保留。
其余五项尚未恢复，保存值不删除；完整需求见[ROADMAP](docs/ROADMAP.md)。

## 新后端与验证范围

0.3.0在普通Lua更新结束后处理本机潜兵的当前交互目标，不再使用旧版游戏代码
跳转、可执行页分配或动态展开表，不调用游戏函数。每帧重新解析本机网络ID、
角色行及当前空间槽；只在主武器成为目标时，用当前候选中有效的非主武器目标
替换，或清空目标。只写本人交互者当前目标的8字节。

关闭、暂停、舰船或退出时停止写入，由原生刷新恢复正常选择，不恢复旧指针。
不会自动安装、部署、启动或附加游戏。只支持Steam build 25480438；构建或
布局证据不符则拒绝工作。[审查说明](docs/CACHE-BACKEND-REVIEW.md)记录了空间
槽位、对象销毁、本机范围、写入校验和更新顺序。

生产Lua输出已交给保留的原生手动交互消费者执行，核对主武器请求改为支援武器
请求、OFF及房主拥有的其他角色不受影响。两套真实LuaJIT、实际Windows私有
缓冲写入和真正菜单作者API也属于构建门禁。这些是离线检查，**不证明任务稳定性、
真实换枪、死亡/增援或房主/客机已经通过实机测试**。额外世界更新路径及其他mod
的更新顺序仍可能影响覆盖。没有外部人工审查。

## 安装与测试

构建产生`outputs/Interaction-Filters-0.3.0-cache-primary-test.zip`。
关闭游戏后导入管理器替换旧版并重新部署，不要同时装两份。
依赖Bingus Shared Loader v18+、Mod Options Menu v1.1+。
Esc → MODS → 交互过滤 · 主武器测试版 → 禁止捡起地面主要武器 → 应用。

先确认进入任务后至少3分钟是否稳定；若稳定，再测试主武器单独落地、与支援
武器重叠、OFF/APPLY恢复拾取，以及死亡/增援。不要求重复旧版仅入口崩溃对照。
实际测试说明与包内README来自同一份Lua GUIDE。

日志为CowboyBingus/Helldivers2/Logs下的PrimaryPickupBlocker.log和
PrimaryPickupBlocker-STATUS.txt。核对build_id=0.3.0-cache-primary.1。
`backend.primary_seen`、`replaced`、`cleared`是实际观察/写入次数；
`active=true`不代表已拦截成功。失败原因和最终计数都会写入状态文件。

## 工程与构建

- `src/`：当前Lua缓存后端；旧hook/windows/native_blob不参与组合。
- `native/`、历史测试：撤回版的离线复现，不能重新作为游戏候选。
- `scripts/`：组合、源码/FFI/审查门禁、测试、打包和源码导出。
- `vendor/shared/`：按SHA固定的未修改共享源码。
- `build/`、`outputs/`、`external/`：本地生成证据、交付物和依赖，全部忽略。

按[开发环境](docs/DEVELOPMENT.md)设置依赖后运行：

```powershell
python -B scripts/build.py --verify-only
python -B scripts/build.py
python -B scripts/export_source.py --output-dir outputs
```

[发布策略](release-policy.json)只允许新候选，并要求审查过的源码SHA匹配。
完整门禁通过后才向outputs交付；旧失败ID永久拒绝，不能靠改标签重发。
源码、说明与每组完成的修改均提交并推送至本仓库，outputs和私人日志不上传。

[验证范围](docs/VALIDATION.md) / [技术说明](docs/TECHNICAL.md) /
[旧闪退调查](docs/INVESTIGATION.md) / [版本记录](CHANGELOG.md) /
[第三方来源](THIRD_PARTY_NOTICES.md) / [0BSD许可](LICENSE)。

English: 0.3.0 is a NEW PRIMARY-ONLY DATA-CACHE TEST CANDIDATE. Default ON,
saved OFF honored. Five optional filters remain unavailable. All old0.2.x builds
are withdrawn. No game-code detour, executable allocation, or engine calls.
Offline checks are not live acceptance; real pickups, mission stability, death/
reinforcement, extra update paths and host/client behavior remain pending.
