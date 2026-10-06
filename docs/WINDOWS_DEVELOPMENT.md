# Windows x64 本地组件开发与验收

Windows 是当前优先交付平台。它只支持原生 `x64`，不支持 Windows x86，也不会将 macOS 构建结果
当作 Windows 验收依据。

## 本地构建

```powershell
.\packaging\windows\build_component.ps1
```

构建流程固定 Cua Driver `0.34.0`，逐层校验官方 ZIP、文件白名单、逐文件 SHA-256 和
`cua-driver.exe` Authenticode，然后在仓库的 `build/` 中创建隔离 Python 环境，将 Sidecar 冻结为
无控制台 Windows x64 EXE。最终 ZIP 和未签名的哈希清单写入 `dist/`。

流程不运行 Cua 安装器，不修改 PATH，不注册自启动，不安装 Perception、FFmpeg、模型或工作流。
生成的哈希清单不是小助手生产签名；正式接入仍需由小助手已有签名发布链签署。

## 私有运行时

`runtime/windows/start_private_runtime.ps1` 只从组件目录启动 `cua-driver.exe serve`，使用唯一命名
管道、bounded 权限和明确的 capability manifest。启动时清空继承环境，只补入运行必需的 Windows
目录，并关闭遥测与更新检查。停止脚本只接受本组件命名管道及完全匹配的组件入口。

## 首轮安全验收

先构建专用窗口：

```powershell
.\acceptance\windows\build_test_window.ps1
```

脚本同时从模板生成绑定该 EXE 规范绝对路径的 bounded capability manifest；模板本身不能直接用于
启动 runtime，避免一个模糊的文件名授权到其他同名程序。

只在 `acceptance-safe-test-window.exe` 中验证窗口枚举、快照、后台文本和后台点击。验收必须同时记录
动作前后前台窗口句柄和真实鼠标位置；任何改变均判定失败。后台不可用、遮挡、过期或无法验证时必须
结构化拒绝，不能切前台或注入真实输入。微信等业务软件不作为底座测试。

当前真机边界：静态测试与构建完成不等于后台输入已经验收；只有在固定 Cua runtime 上观察到专用
窗口状态发生预期变化，同时前台、焦点和真实鼠标保持不变，才可宣称对应动作通过。

构建后的 ZIP 自带 `acceptance/test_component.ps1`。解压后从 PowerShell 运行它即可完成同一条安全
后台自检；脚本只启动专用窗口和私有 runtime，结束时会停止二者并删除临时权限清单。
用户在测试期间仍可使用鼠标和切换窗口；这类用户活动只作为桌面观察结果报告，不会被误判为组件
抢占。自检以 `delivery=background`、`route=accessibility` 和动作后新快照三项共同判定。

## 正式发布

GitHub 仓库只保存源码，不通过 GitHub Release 向小助手分发安装包。可选的手动工作流只生成保留
7 天的未签名构建产物，不会发布 Release。Windows ZIP、签名安装清单和签名外部组件目录统一发布
到小助手自有组件服务器。`create_release_metadata.ps1` 接收服务器最终 HTTPS 下载地址并生成待签名
元数据；签名和上传必须在持有 `COMPONENT_SIGNING_PRIVATE_KEY` 的受控发布环境完成。
