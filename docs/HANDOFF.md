# Screen Automation Cua Component 开发交接

更新时间：2026-09-29（Asia/Shanghai）

## 1. 目标

为“屏幕自动化小助手”开发一个独立的 Cua Driver 可选增强组件，让支持的 Windows 窗口操作
优先在后台完成，减少与用户争用真实鼠标、键盘和前台窗口，同时不削弱小助手原有的
“明确目标—动作前检查—动作后验证—不确定即停止”安全边界。

新项目不能包含具体软件、网站或内容平台的业务流程，也不能把 Cua 描述为小助手官方能力或
目标应用的官方授权功能。

## 2. 仓库与当前状态

- 独立本地仓库：`D:\ai\screen-automation-cua-component`
- 当前分支：`main`
- 当前提交：`d8e2c22 feat: scaffold bounded Cua component adapter`
- 远程仓库：尚未创建或配置
- 小助手主仓库：`D:\ai\screen-automation-helper`
- 小助手主仓库当前没有接入本组件；不要在未完成组件验收前宣称已经可用
- 尚未下载、安装、启动、打包或重新分发 Cua Driver 二进制

## 3. 已完成内容

### 3.1 组件身份

- 项目：`screen-automation-cua-component`
- 小助手组件 ID：`cua-driver-windows`
- Sidecar 协议：`screen-automation-cua-sidecar@1`
- 中立能力标识：`desktop.background-input@1`
- 当前版本：`0.1.0`

### 3.2 已实现代码

- `src/sah_cua_component/policy.py`
  - 只允许明确的窗口目标：`kind=window + pid + window_id`
  - 默认 `delivery_mode=background`
  - 禁止桌面绝对坐标目标
  - 像素动作必须携带 `capture_id`
  - 前台降级默认关闭；开启后仍要求该次请求 `user_confirmed=true`
  - 元素目标与像素目标不能混用
- `src/sah_cua_component/driver_cli.py`
  - 封装 `cua-driver --version`
  - 封装 `cua-driver doctor --json`
  - 封装 `cua-driver call <tool> <json>`
  - 限制超时与错误文本长度，保留退出码和诊断
- `src/sah_cua_component/sidecar.py`
  - UTF-8 NDJSON 请求/响应
  - 方法：`health`、`windows.list`、`window.observe`、`action.click`、
    `action.type_text`、`action.press_key`、`action.hotkey`、`action.scroll`
  - 未知协议、方法、参数和策略违规均返回结构化错误
- `component.json`
  - 当前仅声明 `windows-x64`
  - Windows x86 明确不支持，因为 Cua Driver 没有 Windows 32 位发布物
- `docs/INTEGRATION_CONTRACT.md`
  - 记录宿主进程、协议、安全和组件生命周期边界
- `THIRD_PARTY_NOTICES.md`
  - 记录 Cua Driver 来源和 MIT License
  - 明确不包含许可义务不同的 `cua-perception` 扩展

### 3.3 已完成验证

使用小助手仓库自带的 Python 3.12 工具链执行：

```powershell
$env:PYTHONPATH='D:\ai\screen-automation-cua-component\src'
& 'D:\ai\screen-automation-helper\packaging\toolchains\python312-x64-full\python.exe' `
  -m unittest discover -s tests -q
```

结果：13 项测试通过。

## 4. 必须保留的安全与产品边界

1. 后台失败时不能静默切换前台，也不能偷偷移动真实鼠标。
2. Cua 返回 `background_unavailable`、`background_occluded`、`refused`、
   `unverifiable` 或 `suspected_noop` 时，重新观察、停止或请求用户决定。
3. 优先使用 UIA 元素；像素动作必须来自同一次窗口观察并绑定 `capture_id`。
4. 不从当前前台窗口猜测目标，不允许 `kind=desktop`。
5. 用户与自动化同时修改同一个目标窗口时，必须检测状态变化并重新观察。
6. 发送、删除、支付、发布等高风险业务确认继续由小助手/工作流负责，组件不能批准。
7. Cua Driver 作为可选组件安装，不进入小助手主安装包。
8. 不调用 Cua 全局安装脚本，不修改用户 PATH，不静默注册自启动，不安装 Agent Skill。
9. 正式组件包必须固定上游版本，校验官方发布 ZIP 和二进制 SHA-256，保留许可证、来源和声明。
10. 不包含 FFmpeg、Cua Perception、模型文件或任何具体目标应用工作流。
11. 项目不是 Cua 官方项目，不得暗示 Cua AI, Inc. 背书。

## 5. 与小助手现有组件系统的关系

小助手已经具备可选组件生命周期：签名清单、文件大小、SHA-256、安全解压、入口验证、原子
安装、版本切换、回滚和卸载。浏览器增强组件是现有参考实现。

组件安装目录目标形态：

```text
components/cua-driver-windows/
├── current.json
└── versions/
    └── <component-version>/
        ├── screen-automation-cua-sidecar.exe
        ├── cua-driver.exe
        ├── component.json
        ├── LICENSE
        └── THIRD_PARTY_NOTICES.md
```

小助手主仓库后续需要新增目录定义、组件中心展示、平台支持判断、组件验证器、Sidecar 客户端和
公共 SDK 路由。但必须先完成独立项目的可安装包与真实验收，再进入主仓库接入。

## 6. 下一阶段建议顺序

### 阶段 A：核对上游并固定版本

1. 重新查询 Cua Driver 当前稳定版本，不沿用旧查询结果。
2. 阅读该版本 Release、MIT License、Windows 工具契约、权限模式和遥测说明。
3. 固定 Windows x86_64 `binary.zip` 的下载地址、大小和 SHA-256。
4. 下载到临时构建目录，校验 ZIP 和解压后的 `cua-driver.exe`。
5. 记录上游版本、提交、来源、哈希和许可证；不要运行全局安装器。

### 阶段 B：私有运行时与 Sidecar 可执行文件

1. 调研并验证不依赖全局 daemon/自启动的运行方式；优先使用组件私有进程和私有会话。
2. 如果必须启动 daemon，使用受限权限模式、组件私有配置/管道，并保证停止和清理。
3. 将 Python Sidecar 打包成 Windows x64 无控制台 EXE。
4. 组件进程不能继承不必要的敏感环境变量。
5. 增加消息大小、并发、取消、超时和子进程退出清理测试。

### 阶段 C：真实 Windows x64 验收

至少覆盖：

- 标准 Win32/WPF 测试窗口的 UIA 后台点击和文本设置；
- 用户在另一窗口移动鼠标、输入文字时不被抢占；
- 后台不支持的动作准确拒绝，且不改变前台、焦点或真实鼠标；
- 目标窗口关闭、句柄变化、元素过期、窗口移动、遮挡和最小化；
- 用户同时修改目标窗口时重新观察；
- Sidecar 停止、崩溃、超时和小助手“全部暂停”；
- 管理员权限目标产生可解释拒绝；
- 操作后通过新快照或控件状态验证实际结果。

不要先用微信等具体业务流程作为底座验收；先使用无敏感内容的专用测试窗口。

### 阶段 D：生成组件包

1. 生成 `screen-automation-cua-sidecar.exe`。
2. 打包固定版本 `cua-driver.exe`、MIT License、第三方声明和组件元数据。
3. 生成 ZIP、大小、SHA-256 和小助手签名清单。
4. 验证安全解压、自检、安装、更新失败保留旧版、回滚和卸载。
5. 卸载必须只删除组件管理目录，不能删除用户独立安装的 Cua。

### 阶段 E：接入小助手

1. 在小助手“设置 → 功能组件”增加“后台窗口操作（Cua Driver）”。
2. Windows x64 可安装；Windows x86 显示“当前系统不支持”并禁用安装。
3. 公共动作路由采用“后台优先、前台逐次确认”的策略。
4. 保留当前真实鼠标键盘驱动作为独立、明确的前台路径。
5. 补齐主仓库静态测试、Sidecar 测试、远程组件安装测试和冻结 EXE 验收。

## 7. 当前待确认的设计问题

- 是否采用 Cua CLI daemon，还是直接通过 MCP stdio/SDK 创建组件私有运行时；必须用源码和真实
  Windows 行为验证，不能只根据 README 决定。
- Cua 的权限 manifest 如何映射到小助手已有的 capability/access 授权。
- 窗口截图是通过受控临时文件传递还是增加有界二进制通道。
- 组件协议是否加入取消方法、会话 ID、快照代次和一次性元素令牌。
- 是否允许任何前台降级；推荐首个版本采用 `background-required`，前台操作继续走小助手现有路径。
- 新仓库何时创建 GitHub 远程，以及仓库公开性和发布地址。

## 8. 开始新对话后的第一批检查

```powershell
cd D:\ai\screen-automation-cua-component
git -c safe.directory='D:/ai/screen-automation-cua-component' status --short --branch
git -c safe.directory='D:/ai/screen-automation-cua-component' log -3 --oneline
```

如果 Git 报目录所有权不同，继续对单次命令使用 `-c safe.directory=...`；不要未经用户同意修改
全局 Git 配置。

然后完整阅读：

- `README.md`
- `docs/INTEGRATION_CONTRACT.md`
- `src/sah_cua_component/policy.py`
- `src/sah_cua_component/driver_cli.py`
- `src/sah_cua_component/sidecar.py`
- `tests/`

最后重新运行 13 项测试，再开始阶段 A。不要修改或清理小助手主仓库中的现有未跟踪图片和
`tmpdir/`。
