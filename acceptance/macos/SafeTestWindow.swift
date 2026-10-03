import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let status = NSTextField(labelWithString: "状态：等待后台操作")
    private let input = NSTextField(string: "")
    private var count = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSRect(x: 0, y: 0, width: 520, height: 280)
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Cua 后台安全验收窗口（无敏感内容）"
        window.center()

        let title = NSTextField(labelWithString: "专用测试窗口")
        title.font = .boldSystemFont(ofSize: 22)
        title.alignment = .center

        input.placeholderString = "在这里测试后台文本输入"
        input.identifier = NSUserInterfaceItemIdentifier("safe-input")

        let button = NSButton(title: "增加计数", target: self, action: #selector(increment))
        button.identifier = NSUserInterfaceItemIdentifier("increment-button")

        let reset = NSButton(title: "重置", target: self, action: #selector(resetState))
        reset.identifier = NSUserInterfaceItemIdentifier("reset-button")

        let buttons = NSStackView(views: [button, reset])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let stack = NSStackView(views: [title, input, buttons, status])
        stack.orientation = .vertical
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 32, bottom: 28, right: 32)
        window.contentView = stack
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func increment() {
        count += 1
        status.stringValue = "状态：计数 = \(count)"
    }

    @objc private func resetState() {
        count = 0
        input.stringValue = ""
        status.stringValue = "状态：等待后台操作"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
