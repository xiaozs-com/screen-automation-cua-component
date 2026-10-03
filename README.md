# Screen Automation Cua Component

屏幕自动化小助手的独立 Cua Driver 适配组件。它把 Cua Driver 的窗口级后台操作能力
收敛到一个可审计、可停止、可验证的 Sidecar 协议中，不把 Cua Driver 或具体应用工作流
写入屏幕自动化小助手核心。

本项目不是 Cua 官方项目，也不代表 Cua AI, Inc. 的授权或背书。Cua Driver 来源于
<https://github.com/trycua/cua>，采用 MIT License；正式分发前必须固定上游版本、校验发布
文件哈希并随包保留上游许可证和第三方声明。

## 平台范围

- Windows 仅支持 x64；Windows x86 明确不支持。
- macOS 支持 Intel x86_64 和 Apple Silicon arm64，最低 macOS 14；优先完成 Intel 真机验收。
- 只接受精确的 `pid + window_id` 窗口目标。
- 默认且强制优先使用 `delivery_mode=background`。
- 不接受桌面绝对坐标，不操作任务栏、系统托盘或任意当前前台窗口。
- 元素动作优先；像素动作必须携带同一次观察返回的 `capture_id`。
- 后台不可用时返回结构化拒绝，不自动切换前台。
- 前台降级必须由宿主显式开启，并且每次请求都携带用户确认。
- 不包含 Cua Perception 扩展、FFmpeg、模型文件或任何具体应用工作流。

## 组件身份

- 项目仓库：`screen-automation-cua-component`
- 小助手组件 ID：`cua-driver-windows`
- Sidecar 协议：`screen-automation-cua-sidecar@1`
- 提供能力：`desktop.background-input@1`

## 开发

```powershell
py -m unittest discover -s tests -q
py -m sah_cua_component.sidecar --driver C:\path\to\cua-driver.exe
```

固定上游版本和只读暂存流程见 [`docs/UPSTREAM_PIN.md`](docs/UPSTREAM_PIN.md)。当前锁定 Cua
Driver `0.30.4` 的官方 Windows x64 发布物；暂存脚本只下载、校验和解压到 Git 忽略的
`build/`，不会执行 Cua、安装全局组件、修改 PATH 或注册自启动。

macOS 版本的构建、私有 runtime 和无敏感内容真机验收见
[`docs/MACOS_DEVELOPMENT.md`](docs/MACOS_DEVELOPMENT.md)。macOS 固定上游 `0.32.0` universal
App Bundle，保留官方签名和 `com.trycua.driver` 权限身份。

Sidecar 通过标准输入逐行接收 JSON，通过标准输出逐行返回 JSON。协议和宿主接入要求见
[`docs/INTEGRATION_CONTRACT.md`](docs/INTEGRATION_CONTRACT.md)。

## 当前状态

Windows 仍处于上游固定和适配层阶段。macOS 已加入构建与专用测试窗口源码，但必须在真实
Intel Mac 上完成编译、权限、后台不抢焦点和鼠标验收后，才能宣称可供最终用户安装。
