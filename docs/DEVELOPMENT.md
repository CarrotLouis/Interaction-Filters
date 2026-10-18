# 开发环境与构建

当前0.3.0使用Lua数据缓存后端；打包不再汇编或加载旧原生跳板。
Windows x64完整门禁需要Python、requirements-dev.txt，以及已安装游戏的
bin/lua51.dll。DLL只加载到独立测试进程，不启动或附加游戏；不上传任何DLL。
GNU MinGW仅用于手动研究旧汇编，不是当前构建依赖。

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
```

准备两项独立构建依赖，版本固定于vendor/PROVENANCE.json；external/被忽略：

```powershell
git clone https://github.com/CowboyBingus/BingusSharedLoader.git external/BingusSharedLoader
git -C external/BingusSharedLoader checkout 68b9d05fd8e49ba3fb07e7e669ea46d350e9df8f
git clone https://github.com/CowboyBingus/ModOptionsMenu.git external/ModOptionsMenu
git -C external/ModOptionsMenu checkout fd0160807b6cc75c2eeb74dbf9793a3c5d30deb6
```

| 环境变量 | 用途 | 缺省 |
| --- | --- | --- |
| PPB_BINGUS_TOOLS | build_addon.py、archive.py所在目录 | external/BingusSharedLoader/scripts |
| PPB_MOM_SOURCE | 菜单作者API测试源码 | external/ModOptionsMenu |
| HD2_LUA51_DLL | 本机已安装游戏bin/lua51.dll绝对路径 | 必须设置 |

已有依赖可指定原位置，无需重复下载。设置实际DLL路径后：

```powershell
python -B scripts/build.py --verify-only
python -B scripts/build.py
python -B scripts/export_source.py --output-dir outputs
```

build.py组合源码并校验vendor SHA，执行LuaJIT编译/FFI、两套VM、原生历史和当前
消费者交叉测试、策略及源码隔离，然后用官方工具打包、读取成品并核对完全相同的
Lua资源。全程不部署、启动或附加游戏。生成证据留build/，ZIP、GUIDE和校验留
outputs/；两者均忽略。已有同名不同内容的交付包不覆盖，改版本或换输出目录。

`backend-review.json`固定核对过的核心源码与证据。更改后须重审并更新记录，
不能只因测试变绿刷新。require_packaging拒绝已撤回ID、失败状态和不匹配审查。
build_mod.py直接打包也要求本次源码对应的完整门禁记录；--validate-only只校验
源码，不交付。当前候选的实机状态必须保持pending直到真实结果到达。

只读成品检查：

```powershell
python -B scripts/inspect_package.py outputs/Interaction-Filters-0.3.0-cache-primary-test.zip --resource mods/primary_pickup_tools/primary_pickup_blocker --source build/addon.lua --json
python -B scripts/verify_cache_research.py --self-test --json
```

第二个工具可显式传--capture-dir核对私人保留代码，再传--lua-dll只读核对Lua导出。
不加载DLL、不写游戏、不导出ZIP。正常构建不依赖私人capture。缓存消费者和新
后端的范围见[CACHE-BACKEND-REVIEW](CACHE-BACKEND-REVIEW.md)。每组完成的修改
按[CONTRIBUTING](../CONTRIBUTING.md)核验、提交和推送；outputs永不上传。
