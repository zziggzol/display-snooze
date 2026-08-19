// Entry point. Starts as a menu bar app with no Dock presence.
// DisplayController owns the display switching, StatusMenu the presentation, and
// HotKey the escape hatch.

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
        // Quitting always brings the displays back, so a detached display can never
        // outlive the app that detached it.
        controller?.restoreAll()
        hotKey?.unregister()
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
