# Windows x64 本机验收记录

日期：2026-10-06（Asia/Shanghai）

环境：Windows 11 x64；Cua Driver 0.34.0；专用
`acceptance-safe-test-window.exe`。没有使用微信或其他业务软件，没有安装 Cua、修改 PATH、注册
自启动或启用前台降级。

## 已通过

- 官方 Windows x64 ZIP 的大小、官方 SHA-256、六文件白名单、逐文件 SHA-256、MIT License 和
  `cua-driver.exe` Authenticode 均通过固定锁校验。
- 私有 `serve` 使用随机命名管道、bounded permission mode、绑定专用测试 EXE 绝对路径的 capability
  manifest、关闭更新检查/遥测环境开关和 `--no-overlay`；`status` 确认 manifest 有效。
- 私有 runtime 可通过指定管道优雅停止，停止后无残留 `cua-driver` 进程。
- 专用 Win32 窗口以不激活方式显示；`list_windows` 与窗口 UIA 快照成功。
- 后台 `type_text` 通过 UIA ValuePattern 返回 `effect=confirmed`。
- 后台 `click` 通过 accessibility 路由执行。Driver 返回 `effect=unverifiable` 后按安全约定重新观察，
  新快照确认状态为 `clicks=1; text=bounded-background-ok`。
- 点击动作前后前台 HWND 保持 `1050078`，真实鼠标位置保持 `(710,415)`；没有抢前台或移动鼠标。
- 窗口最小化时点击返回结构化 `window_minimized` 拒绝，没有自动恢复、切前台或改走真实输入。

## 尚未覆盖的真机边界

- WPF 专用窗口、遮挡、窗口关闭/句柄变化、元素过期、窗口移动及用户并发修改。
- 管理员权限目标的可解释拒绝、Sidecar 崩溃/超时/取消和宿主“全部暂停”。
- 小助手组件管理器的签名清单、安装、升级失败保留旧版、回滚和卸载。

因此，本记录证明 Windows x64 独立本地组件的首条安全后台路径可工作，但不代表已经接入小助手，
也不代表剩余矩阵或生产签名发布已完成。
