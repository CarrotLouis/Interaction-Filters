# 开发与同步

开发环境与构建命令见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)。

1. 开始修改前检查工作区和远端，保留已有未提交工作；拉取只接受 fast-forward。
2. 在 `src/` 修改 Lua，在 `native/filter_v2.S` 修改原生筛选。
   `src/native_blob.lua` 由汇编脚本生成，不手工改写。
3. 修改行为时更新有实际判别力的回归用例、验证状态和版本记录。
   文档修改只需与代码和现有证据核对。
4. 运行适用检查；原生、运行时和打包流程修改须完成整套构建门禁。
5. 检查差异与暂存列表，提交并推送；每一组完成的相关修改都同步到 GitHub。

```powershell
git diff --check
git status --short
git add <本次修改的文件>
git diff --cached --stat
git commit -m "fix: 描述具体问题与修正"
git push
git rev-parse HEAD
git ls-remote origin refs/heads/main
```

`outputs/` 在任意层级都被忽略。生成文件、运行日志、崩溃转储、个人配置、
游戏文件和依赖检出不进入提交；不要使用 `git add -f` 绕过这些排除规则。

保留稳定的模组标识和保存项。支援武器按原始召唤来源分类的需求仍在
[ROADMAP](docs/ROADMAP.md)，不要将 0.2.3 描述为完整六项功能版本。

公开仓库沿用原工程的 0BSD 许可证；第三方文件保留各自许可和校验。
