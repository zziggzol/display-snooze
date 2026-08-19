// メニューバーのアイコンとメニューを組み立てる。画面の並びは開くたびに作り直す。
// 表示と入力の受け取りだけを担当し、実際の切り替えは DisplayController に任せる。

import AppKit

@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let controller: DisplayController

    init(controller: DisplayController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
    }

    // MARK: - メニューの組み立て

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !controller.isSupported {
            let item = NSMenuItem(title: "この Mac では使えません", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
            addQuitItem(to: menu)
            return
        }

        for display in controller.displays() {
            let item = NSMenuItem(
                title: display.name,
                action: #selector(toggleDisplay(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = NSNumber(value: display.id)
            item.state = display.isActive ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let restore = NSMenuItem(
            title: "すべて戻す",
            action: #selector(restoreAll),
            keyEquivalent: "d"
        )
        restore.keyEquivalentModifierMask = [.control, .option, .command]
        restore.target = self
        restore.isEnabled = !controller.disabled.isEmpty
        menu.addItem(restore)

        menu.addItem(.separator())
        addQuitItem(to: menu)
    }

    private func addQuitItem(to menu: NSMenu) {
        let quit = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - 操作

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        let id = CGDirectDisplayID(number.uint32Value)
        let turnOn = sender.state == .off
        do {
            try controller.setEnabled(id, turnOn)
            updateIcon()
        } catch {
            present(error)
        }
    }

    @objc private func restoreAll() {
        controller.restoreAll()
        updateIcon()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 見た目

    /// 切り離し中の画面があるかどうかでアイコンを変える。
    func updateIcon() {
        guard let button = statusItem.button else { return }
        let name = controller.disabled.isEmpty ? "display" : "display.slash"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "DisplaySnooze")
            ?? NSImage(systemSymbolName: "display", accessibilityDescription: "DisplaySnooze")
        image?.isTemplate = true
        button.image = image
    }

    private func present(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "画面を切り替えられませんでした"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
