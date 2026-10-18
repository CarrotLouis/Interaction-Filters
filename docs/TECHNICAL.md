# 0.3.0 本机目标缓存后端

当前实现由`cache_backend.lua`和`data_writer.lua`组成，不组合旧hook、allocator、
windows或native_blob。原生汇编只保留在离线历史中。

`PlayerManager+0x3A8`为本机avatar网络ID。每帧匹配Interactor descriptor的
`+0x10`和owned bit，并验证entity hash对应index，重新计算`rows+index*0x880`。
当前目标是行首的20字节空间记录指针；候选数组中的指针则指向12字节payload。
这两种记录不是同一结构，撤回版混用它们导致删候选后仍可提交保留的主武器。

Interactable管理器含2048个固定槽。grid buckets从管理器基址开始，spatial在
`+0x4000`，payload在`+0xE000`。runtime区域`+0x40`保存槽号，`+0x44`是类型，
`+0x60`是原生可用条件，`+0x66`排除目标选择。类型1为主武器、3为支援武器。
空间记录`+0x0C`是grid key，`+0x10`是槽号；`+0x14020`是网格比例而非数量。
完整字段与指令依据见[CACHE-BACKEND-REVIEW](CACHE-BACKEND-REVIEW.md)。

共享guard先转发下层Lua更新，在after中再确认任务并过滤当前本机目标。原生正常
帧随后进行角色手动请求，再刷新候选。替代目标必须在当前本机候选中且符合原生
可用条件/类型列表/所有权模式，按分数选择；无替代则清空。原生模板和网络请求
流程继续负责剩余条件，不调用原生函数强行拾取。自动交互路径不在本版范围内。

写入只有本机行首8字节。写入前重新解析全部身份与两个目标并回读验证快照，
检查对齐与私有RW页面，通过当前进程WriteProcessMemory检查预期/返回/回读。
OFF/暂停/shutdown不写回旧指针，下一次原生刷新恢复选择。对象不确定则放行；
写失败停止，日志具体记录实体映射、槽位、grid、布局或请求状态的拒绝原因。

只提供主武器保存项`.enabled_v2`，首次ON，保存OFF有效。GUID、资源与singleton
保持不变。其他五项保存值不动，无GameSession来源观察或新热键。

两套真实LuaJIT和独立原生消费者交叉测试属于离线门禁。额外世界更新、实机寿命、
网络拾取和稳定性仍待验证。旧入口细节见[ENTRY-PROBE](ENTRY-PROBE.md)及
[NATIVE-ENTRY](NATIVE-ENTRY.md)，两者均不是本包的运行时实现。
