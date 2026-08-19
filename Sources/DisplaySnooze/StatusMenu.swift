// メニューバーのアイコンとメニューを組み立てる。画面の並びは開くたびに作り直す。
// 表示と入力の受け取りだけを担当し、画面の切り替えは DisplayController、自動起動は LaunchAtLogin に任せる。
// 表示する文言は英語。コード中の説明は日本語で書く。

import AppKit

@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let controller: DisplayController

    /// メニューに出すアプリ名。Info.plist を正とするので、名前を変えても追従する。
    private let appName: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "DisplaySnooze"

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

        guard controller.isSupported else {
            let item = NSMenuItem(title: "Not available on this Mac", action: nil, keyEquivalent: "")
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
            title: "Restore All Displays",
            action: #selector(restoreAll),
            keyEquivalent: "d"
        )
        restore.keyEquivalentModifierMask = [.control, .option, .command]
        restore.target = self
        restore.isEnabled = !controller.disabled.isEmpty
        menu.addItem(restore)

        menu.addItem(.separator())
        addLaunchAtLoginItems(to: menu)
        menu.addItem(.separator())
        addQuitItem(to: menu)
    }

    /// 自動起動の切り替えと、承認待ちのときの案内を並べる。
    private func addLaunchAtLoginItems(to menu: NSMenu) {
        let toggle = NSMenuItem(
            title: "Open at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(toggle)

        guard LaunchAtLogin.needsApproval else { return }
        let approve = NSMenuItem(
            title: "Allow in System Settings…",
            action: #selector(openLoginItemSettings),
            keyEquivalent: ""
        )
        approve.target = self
        menu.addItem(approve)
    }

    /// 終了項目にはアプリ名を入れる。メニューバー常駐アプリは名前を出す場所がここしかない。
    private func addQuitItem(to menu: NSMenu) {
        let quit = NSMenuItem(title: "Quit \(appName)", action: #selector(quit), keyEquivalent: "q")
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
            present(error, title: "Could not change the display")
        }
    }

    @objc private func restoreAll() {
        controller.restoreAll()
        updateIcon()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            try LaunchAtLogin.setEnabled(sender.state == .off)
        } catch {
            present(error, title: "Could not change the login item")
        }
    }

    @objc private func openLoginItemSettings() {
        LaunchAtLogin.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 見た目

    /// 切り離し中の画面があるかどうかでアイコンを変える。
    func updateIcon() {
        guard let button = statusItem.button else { return }
        let name = controller.disabled.isEmpty ? "display" : "display.slash"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: appName)
            ?? NSImage(systemSymbolName: "display", accessibilityDescription: appName)
        image?.isTemplate = true
        button.image = image
    }

    private func present(_ error: Error, title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
