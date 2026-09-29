# Screen Automation Cua Component

屏幕自动化小助手的独立 Cua Driver 适配组件。它把 Cua Driver 的窗口级后台操作能力
收敛到一个可审计、可停止、可验证的 Sidecar 协议中，不把 Cua Driver 或具体应用工作流
写入屏幕自动化小助手核心。

本项目不是 Cua 官方项目，也不代表 Cua AI, Inc. 的授权或背书。Cua Driver 来源于
<https://github.com/trycua/cua>，采用 MIT License；正式分发前必须固定上游版本、校验发布
文件哈希并随包保留上游许可证和第三方声明。

## 第一阶段边界

- 仅支持 Windows x64；Windows x86 明确不支持。
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

Sidecar 通过标准输入逐行接收 JSON，通过标准输出逐行返回 JSON。协议和宿主接入要求见
[`docs/INTEGRATION_CONTRACT.md`](docs/INTEGRATION_CONTRACT.md)。

## 当前状态

第一阶段只实现适配层和安全策略。正式可安装 ZIP、签名清单、小助手组件中心接入以及真实
Windows x64 验收属于下一阶段；在这些完成前不能宣称已经可供最终用户安装。

