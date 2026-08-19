// アプリの起動点。Dock に出さないメニューバー常駐アプリとして立ち上げる。
// 画面の切り替えは DisplayController、見た目は StatusMenu、保険のホットキーは HotKey が持つ。

import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: DisplayController?
    private var statusMenu: StatusMenu?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = DisplayController()
        let statusMenu = StatusMenu(controller: controller)
        self.controller = controller
        self.statusMenu = statusMenu

        hotKey = HotKey(
            keyCode: UInt32(kVK_ANSI_D),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        ) {
            controller.restoreAll()
            statusMenu.updateIcon()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 終了すれば必ず画面が戻るようにしておく。切り離したまま行方不明にならないための保険。
        controller?.restoreAll()
        hotKey?.unregister()
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
