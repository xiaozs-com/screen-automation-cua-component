# Cua Driver 上游固定记录

核验日期：2026-09-29（Asia/Shanghai）

## 固定版本

- 稳定版本：`0.30.4`
- 标签：`cua-driver-rs-v0.30.4`
- 提交：`bf6c76786d938070f4ecf1e44004752f69f518b8`
- 发布时间：`2026-09-28T21:38:51Z`
- 平台：仅 `windows-x64`
- 许可证：MIT，固定副本见 `licenses/CUA_DRIVER_LICENSE.md`

GitHub 将该 Release 标记为 Pre-release，是因为同一 monorepo 包含多个独立发布产品。该版本的
Release 说明明确：纯 SemVer 的 Cua Driver 版本走稳定通道；带 `nightly` 后缀的构建才是夜间版。
核验时最新夜间构建为 `0.30.5-nightly...`，未采用。

## 官方发布物

- 文件：`cua-driver-rs-0.30.4-windows-x86_64-binary.zip`
- 官方下载地址：见 `upstream/cua-driver-0.30.4-windows-x64.lock.json`
- 大小：`30,771,456` 字节
- SHA-256：`7b0ec893797fdeb0514d96f5797ad6aa53617eadcba2e47856461f60140c757b`
- `cua-driver.exe` 大小：`34,281,808` 字节
- `cua-driver.exe` SHA-256：`94bb765aad94e2fdf715c6c152c4e2b2b1f93977779a7569e5abc6466beaeab2`
- `cua-driver.exe` Authenticode：有效，签名者 `Cua AI, Inc.`，证书指纹记录在锁文件中

实际 ZIP 包含 6 个根目录文件，而不是只有 `cua-driver.exe`。所有文件的大小和 SHA-256 都写入
锁文件，构建时必须精确匹配；既不漏掉上游随 Windows runtime 发布的 helper/SDK 文件，也不接受
上游无提示增加的新文件。

## 固定构建流程

`scripts/stage_upstream.ps1` 只完成上游运行时的可复现暂存：

1. 拒绝非 Windows x64 主机；
2. 只下载锁文件中的固定 URL，不调用安装脚本；
3. 先校验 ZIP 的精确大小和 SHA-256；
4. 解压前验证归档条目与 6 文件白名单完全一致，并拒绝嵌套、绝对路径和 `..`；
5. 解压到临时目录，再逐文件校验大小和 SHA-256；
6. 验证 `cua-driver.exe` 的 Authenticode 状态和固定签名证书指纹；
7. 加入固定 MIT License 和锁文件；
8. 仅在全部成功后原子移动到输出目录；已有输出时拒绝覆盖。

示例：

```powershell
.\scripts\stage_upstream.ps1
```

缓存和输出均位于被 Git 忽略的 `build/`。脚本不执行任何下载到的程序，不运行上游安装器，
不修改 PATH，不注册自启动，也不接触小助手主仓库。

## 权限、遥测与运行边界

- 官方 Windows 工具契约要求 `get_window_state(pid, window_id)` 在每轮动作前生成新快照；
  `element_index` 还必须绑定匹配的 `snapshot_id`，更推荐使用自带快照身份的 `element_token`。
  截图坐标应绑定一次性 `capture_id`。这比当前脚手架策略更严格，阶段 B 必须据真实 `0.30.4`
  输出更新 Sidecar 协议，不能把现有 16 项单元测试视为真机兼容证明。
- Windows 上裸 `cua-driver mcp` 可直接持有 SDK runtime，并在 stdin EOF 时清理；传 `--socket`
  才会选择外部 daemon。官方遥测文档同时说明一次性 CLI 调用会委托 daemon，因此当前
  `cua-driver call ...` 封装尚不能作为私有运行时方案的结论。阶段 B 应优先验证 MCP stdio
  私有子进程，再决定是否需要组件私有 `serve`，不得注册系统自启动。
- Windows/Linux 的裸 `cua-driver mcp` 自己持有 runtime；若要 bounded 模式，需要由可信启动方设置
  `CUA_DRIVER_PERMISSION_MODE=bounded`、固定 capability manifest 路径及批准标志，或启动私有
  `serve --permission-mode bounded`。这些属于阶段 B 的真实行为验证，阶段 A 不启动 daemon。
- 官方文档说明遥测默认启用，且启动 `mcp`、`serve`、`doctor` 时还可能单独检查 GitHub Release。
  私有组件运行时设计必须显式设置 `CUA_DRIVER_RS_TELEMETRY_ENABLED=false` 和
  `CUA_DRIVER_RS_UPDATE_CHECK=false`，并在阶段 B 验证无网络与无共享用户状态的行为。
- 后台投递是 best-effort。首个版本只允许 `background`；任何不可用、遮挡、无法验证或疑似无效
  结果都结构化拒绝，不切前台、不发送真实输入、不移动真实鼠标。
- 官方 Windows 发布只有 x86_64 和 arm64；本组件只锁定 x86_64，不支持 Windows x86，也不把
  arm64 误认为 x86 兼容包。

## 明确排除

此流程不下载或打包 Cua Perception、FFmpeg、模型文件、Skills、安装/卸载脚本以及任何具体应用
工作流。阶段 C 只能先用无敏感内容的专用 Win32/WPF 测试窗口验收。

## 官方核对入口

- Release：<https://github.com/trycua/cua/releases/tag/cua-driver-rs-v0.30.4>
- Windows 工具契约：<https://cua.ai/docs/reference/cua-driver/mcp-tools-windows>
- 权限模式：<https://cua.ai/docs/reference/cua-driver/permission-modes>
- 遥测与隐私：<https://cua.ai/docs/reference/cua-driver/telemetry>
- 进程模型：<https://cua.ai/docs/reference/cua-driver/process-model>
