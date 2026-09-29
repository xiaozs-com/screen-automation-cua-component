# 小助手接入契约

## 1. 进程边界

正式组件由小助手作为本机子进程启动，通过 UTF-8 NDJSON 通信，不监听局域网端口。每条请求
都包含固定协议、请求 ID、方法和参数；每条响应必须回显请求 ID，并明确 `ok`。

```json
{"protocol":"screen-automation-cua-sidecar@1","id":"1","method":"windows.list","params":{}}
```

单条控制消息建议限制为 2 MiB。截图等大数据不得直接扩展成无界消息；宿主接入时应增加受控
临时文件通道和大小限制。

## 2. 方法

| Sidecar 方法 | Cua Driver 工具 | 是否修改状态 |
|---|---|---:|
| `health` | `--version`、`doctor --json` | 否 |
| `windows.list` | `list_windows` | 否 |
| `window.observe` | `get_window_state` | 否 |
| `action.click` | `click` | 是 |
| `action.type_text` | `type_text` | 是 |
| `action.press_key` | `press_key` | 是 |
| `action.hotkey` | `hotkey` | 是 |
| `action.scroll` | `scroll` | 是 |

## 3. 安全要求

1. 动作目标必须是 `{kind:"window", pid, window_id}`。
2. 不接受 `{kind:"desktop"}`，也不从当前前台窗口推断目标。
3. 默认只允许后台投递。
4. 像素动作必须绑定本次观察的 `capture_id`；不接受裸窗口坐标盲点。
5. Cua 返回 `background_unavailable`、`background_occluded`、`refused`、`unverifiable` 或
   `suspected_noop` 时，宿主必须重新观察、停止或请求用户决定，不能自动前台重试。
6. 如未来开放前台降级，必须同时满足宿主启动策略允许和该次请求 `user_confirmed=true`。
7. 发送、删除、支付、发布等业务确认仍由工作流和小助手负责，组件不能自行批准。

## 4. 生命周期

小助手组件中心负责下载、大小和 SHA-256 校验、组件签名、原子安装、版本切换、回滚和卸载。
本项目负责生成可验证组件包、上游来源记录、自检以及 Sidecar 协议。Cua Driver 的全局安装器、
PATH 修改、自动更新和 Agent Skill 安装不能在组件安装过程中静默执行。

