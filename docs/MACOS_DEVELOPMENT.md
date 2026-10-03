# macOS 组件开发与 Intel Mac 验收

## 当前范围

macOS 组件 ID 为 `cua-driver-macos`，支持 `macos-x64` 和 `macos-arm64`，最低系统为
macOS 14。上游固定为 Cua Driver `0.32.0` 的官方 universal `CuaDriver.app`，因此权限归属继续
使用官方签名 Bundle ID `com.trycua.driver`，而不是把裸可执行文件重新签进 Sidecar。

首个版本始终采用 `background-required`：组件不调用 `bring_to_front`，不自动重试
`delivery_mode=foreground`，不移动系统真实鼠标。后台不支持、结果无法验证或疑似无效时返回
结构化拒绝，由宿主决定停止或请求用户处理。

## 为什么必须保留 App Bundle

macOS 的 Accessibility 和 Screen Recording 权限绑定负责进程和签名应用身份。官方 CLI 在 macOS
默认代理到 `CuaDriver.app`，以保留该权限身份。因此组件包含经过官方签名验证的完整 App Bundle，
不会调用全局安装脚本，也不会把 CLI 加入 PATH。

组件每次运行使用组件自己的 Unix socket、PID 文件和 bounded capability manifest。它不注册
LaunchAgent，不启用上游 autostart，也不会连接默认全局 socket。遥测和版本检查通过启动环境关闭。

## 本机构建

在 Intel Mac 上：

```bash
git clone <仓库地址>
cd screen-automation-cua-component
PYTHONPATH=src python3 -m unittest discover -s tests -q
./packaging/macos/build_component.sh x86_64
```

产物写入 `dist/screen-automation-cua-component-0.1.0-macos-x64.zip`，旁边生成 SHA-256 文件。
Apple Silicon 使用 `arm64`。脚本要求在目标架构原生运行，不用 Rosetta 交叉冒充验收结果。

GitHub Actions 工作流仅支持手动触发，不会因 push 自动打包。Intel job 使用
`macos-15-intel`，arm64 job 使用 `macos-15`。

## 无敏感内容验收

先构建专用测试窗口：

```bash
./acceptance/macos/build_test_window.sh
open build/macos-acceptance/SafeTestWindow.app
```

不要用微信、浏览器账号、邮件或其他业务窗口代替它。测试窗口只有空文本框、计数按钮和状态文本。

解压组件包后，由用户明确执行一次权限授权：

```bash
./package/CuaDriver.app/Contents/MacOS/cua-driver permissions grant
```

在系统设置中只为 `CuaDriver.app` 开启 Accessibility 与 Screen Recording，然后重新启动该 App。
这是用户可见的 macOS 系统授权步骤，组件不得代替用户静默批准。

启动组件私有 runtime：

```bash
state_dir="$(mktemp -d)"
./package/runtime/start_private_runtime.sh \
  ./package \
  "$state_dir" \
  ./runtime/macos/test-window-capabilities.yaml
```

Sidecar 必须显式连接返回的私有 socket：

```bash
./package/screen-automation-cua-sidecar \
  --driver ./package/CuaDriver.app/Contents/MacOS/cua-driver \
  --socket "$state_dir/cua-driver.sock"
```

验收结束：

```bash
./package/runtime/stop_private_runtime.sh ./package "$state_dir"
```

## 真机验收清单

- `file` / `lipo` 确认 Intel 构建的 Sidecar 是 x86_64，上游 Driver 包含 x86_64 和 arm64；
- `codesign --verify --deep --strict` 验证 `CuaDriver.app`；
- 仅列出并绑定专用测试窗口的准确 PID、window ID 和 bundle ID；
- 每次元素动作使用新快照的 `element_token`，或同时携带 `element_index + snapshot_id`；
- 像素动作绑定一次性 `capture_id`；
- 将另一普通窗口保持前台，确认点击、文本设置和滚动不改变前台或真实鼠标位置；
- 遮挡、最小化、窗口关闭、元素过期和 PID/窗口变化均结构化拒绝或要求重新观察；
- capability manifest 之外的任意应用必须返回拒绝；
- 停止后私有 socket 和进程消失，没有 LaunchAgent、自启动项或 PATH 变化。

Windows 上的单元测试和 GitHub 构建不能代替上述 Intel Mac 权限、焦点和鼠标验收。
