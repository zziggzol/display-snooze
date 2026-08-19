// Registering and unregistering the app as a login item, through ServiceManagement
// (macOS 13 and later).
// Registering makes macOS post its own notification, after which System Settings owns
// the approval.

import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    /// The current registration state. Reports .notFound when the app is not running from a bundle.
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// Whether the app is registered and will actually launch.
    static var isEnabled: Bool { status == .enabled }

    /// Whether the user has to re-approve it in System Settings.
    /// Once disabled from the Login Items pane, the app cannot re-enable itself and lands here.
    static var needsApproval: Bool { status == .requiresApproval }

    /// Turns launching at login on or off.
    /// The first registration triggers the "background item added" notification from macOS.
    /// - Parameter enabled: True registers, false unregisters.
    /// - Throws: When the OS refuses the registration, for instance over signing or bundle requirements.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Opens the Login Items pane in System Settings. The route out of the approval-pending state.
    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
