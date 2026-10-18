# 开发环境与构建

完整门禁在 Windows x64、Python 3.12 环境执行，需要本机已安装游戏的
`bin/lua51.dll`。该 DLL 只加载进独立 Python 测试进程，不启动或附加游戏。
不要把 DLL、完整游戏数据或运行日志上传至仓库。

安装固定的 Python 开发依赖：

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
```

准备 x64 GNU 工具链，要求 `gcc`、`objcopy`、`objdump` 可用。通过
`PPB_TOOLCHAIN` 指定其 `bin` 目录，或将它加入当前终端的 `PATH`。

另外检出两项构建/测试依赖。`external/` 已忽略，第三方打包工具不随本仓库分发。
固定版本取自 `vendor/PROVENANCE.json`：

```powershell
git clone https://github.com/CowboyBingus/BingusSharedLoader.git external/BingusSharedLoader
git -C external/BingusSharedLoader checkout 68b9d05fd8e49ba3fb07e7e669ea46d350e9df8f
git clone https://github.com/CowboyBingus/ModOptionsMenu.git external/ModOptionsMenu
git -C external/ModOptionsMenu checkout fd0160807b6cc75c2eeb74dbf9793a3c5d30deb6
```

| 设置 | 用途 | 缺省 |
| --- | --- | --- |
| `PPB_TOOLCHAIN` | x64 GNU 工具链目录 | 从 `PATH` 查找 |
| `PPB_BINGUS_TOOLS` | 包含 `build_addon.py`、`archive.py` 的目录 | `external/BingusSharedLoader/scripts` |
| `PPB_MOM_SOURCE` | ModOptionsMenu 仓库根目录 | `external/ModOptionsMenu` |
| `HD2_LUA51_DLL` | 已安装游戏的 `bin/lua51.dll` 绝对路径 | 必须显式设置 |

在当前终端设置实际路径，例如：

```powershell
$env:PPB_TOOLCHAIN = 'C:\Tools\mingw64\bin'
$env:HD2_LUA51_DLL = 'D:\SteamLibrary\steamapps\common\Helldivers 2\bin\lua51.dll'
.\.venv\Scripts\python.exe -B scripts/build.py --verify-only
```

上面的盘符只是示例，应替换为实际安装路径。已有依赖可以通过环境变量指定，
不要求重复下载，也不要求它们位于本工程旁边。

`build.py` 依次执行汇编、源码拼接与校验、两套 LuaJIT 测试、Unicorn 原生测试、
FFI 与隔离门禁、信封打包和成品读取检查。任一步失败都不会交付候选包。
完整检查不会默默跳过游戏 Lua DLL；缺少依赖会明确失败。

生成证据留在 `build/`，可导入的 ZIP 与说明输出到 `outputs/`，两者均忽略。
如需另一个交付目录，传入 `--output-dir <目录>`。若同名交付包内容不同，
构建拒绝覆盖；使用新目录或更新版本，不覆盖已给用户测试的历史包。

只读复查与源码门禁：

```powershell
.\.venv\Scripts\python.exe -B scripts/verify_isolation.py --source build/addon.lua --json
.\.venv\Scripts\python.exe -B scripts/inspect_package.py outputs/Interaction-Filters-0.2.5-entry-only-diagnostic.zip --resource mods/primary_pickup_tools/primary_pickup_blocker --source build/addon.lua --json
```

当前所有交付版均已撤回，0.2.5的实机结果为失败，见[VALIDATION.md](VALIDATION.md)。
release-policy.json禁止普通build/source-export生成交付；这些命令应退出2并说明撤回原因。
直接调用build_mod.py打包也受同一策略限制；--validate-only仍可只读校验源码。
--verify-only执行离线门禁而不生成ZIP。修改策略必须对应新后端的独立审查，
离线检查通过本身不允许重新发布失败版本。原有ZIP只供读取检查，不要重新安装。

维护者每组修改完成后按 [CONTRIBUTING.md](../CONTRIBUTING.md) 提交并推送。

缓存后端的离线证据检查不接触游戏进程，也不加载DLL：

```powershell
python -B scripts/verify_cache_research.py --self-test --json
python -B tests/test_cache_consumers.py
```

仅需Python和开发依赖中的Capstone/Unicorn。显式传入`--capture-dir <保留目录>`
可核对本地保留代码；再传入`--lua-dll <lua51.dll>`可只读核对Lua导出与IAT。
缺依赖、文件不符或证据不符退出2；默认不写文件，不导出包。完整门禁也执行8项
缓存消费者模拟，但不依赖私人capture。其范围见[CACHE-BACKEND-RESEARCH](CACHE-BACKEND-RESEARCH.md)。
