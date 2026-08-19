// Detaching a display from the macOS display layout, and putting it back.
// The dependency on SkyLight's private API is confined to this file; everything
// else in the app sees an ordinary Swift type.

import AppKit
import CoreGraphics

/// One display, reduced to what the menu needs to show it.
struct DisplayInfo {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltin: Bool
    /// Whether the system is drawing to it. False means it is currently detached.
    let isActive: Bool
}

/// Why a detach failed, or was refused.
enum DisplayControlError: LocalizedError {
    case symbolUnavailable
    case wouldLeaveNoScreen
    case configurationFailed(CGError)

    var errorDescription: String? {
        switch self {
        case .symbolUnavailable:
            return "This version of macOS does not provide the function needed to turn displays off."
        case .wouldLeaveNoScreen:
            return "The last active display cannot be turned off — no screen would be left to work on."
        case .configurationFailed(let error):
            return "macOS refused the display change (code \(error.rawValue))."
        }
    }
}

/// Signature of SkyLight's display-enable call.
/// It is not declared in any public header, so it is looked up at runtime with dlsym.
private typealias ConfigureDisplayEnabled =
    @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

@MainActor
final class DisplayController {
    /// Displays this app has detached. Remembered so they keep a menu entry even
    /// once the system stops listing them.
    private(set) var disabled: Set<CGDirectDisplayID> = []

    /// A detached display no longer reports a name, so names are cached while visible.
    private var cachedNames: [CGDirectDisplayID: String] = [:]

    private let configureDisplayEnabled: ConfigureDisplayEnabled?

    /// Whether detaching works at all. When it does not, the menu says so instead of failing silently.
    var isSupported: Bool { configureDisplayEnabled != nil }

    /// The same call is exported by SkyLight under both a new and an old name, and by
    /// CoreGraphics under the old name only. Trying them newest-first keeps the app
    /// working if any single one is withdrawn.
    private static let candidates: [(library: String, symbol: String)] = [
        ("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", "SLSConfigureDisplayEnabled"),
        ("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", "CGSConfigureDisplayEnabled"),
        ("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", "CGSConfigureDisplayEnabled"),
    ]

    init() {
        var resolved: ConfigureDisplayEnabled?
        for candidate in Self.candidates {
            guard let handle = dlopen(candidate.library, RTLD_NOW),
                  let symbol = dlsym(handle, candidate.symbol) else { continue }
            resolved = unsafeBitCast(symbol, to: ConfigureDisplayEnabled.self)
            break
        }
        configureDisplayEnabled = resolved
    }

    /// Every attached display, including ones this app has detached. Built-in first.
    func displays() -> [DisplayInfo] {
        refreshNames()
        let active = Set(Self.enumerate(CGGetActiveDisplayList))
        let online = Set(Self.enumerate(CGGetOnlineDisplayList))
        return online.union(disabled)
            .map { id in
                DisplayInfo(
                    id: id,
                    name: cachedNames[id] ?? "Display \(id)",
                    isBuiltin: CGDisplayIsBuiltin(id) != 0,
                    isActive: active.contains(id)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isBuiltin != rhs.isBuiltin { return lhs.isBuiltin }
                return lhs.name < rhs.name
            }
    }

    /// Detaches a single display, or puts it back.
    /// - Parameters:
    ///   - id: The display to act on.
    ///   - enabled: True restores the display, false detaches it.
    /// - Throws: When this would leave no active display, or when macOS refuses the change.
    func setEnabled(_ id: CGDirectDisplayID, _ enabled: Bool) throws {
        guard let configure = configureDisplayEnabled else {
            throw DisplayControlError.symbolUnavailable
        }
        if !enabled && Self.enumerate(CGGetActiveDisplayList).count <= 1 {
            throw DisplayControlError.wouldLeaveNoScreen
        }

        var config: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success else { throw DisplayControlError.configurationFailed(begin) }

        let applied = configure(config, id, enabled)
        guard applied == .success else {
            CGCancelDisplayConfiguration(config)
            throw DisplayControlError.configurationFailed(applied)
        }

        // .forSession is what makes a reboot undo everything — the last way out if
        // the user ever ends up stuck.
        let completed = CGCompleteDisplayConfiguration(config, .forSession)
        guard completed == .success else { throw DisplayControlError.configurationFailed(completed) }

        if enabled { disabled.remove(id) } else { disabled.insert(id) }
    }

    /// Restores every detached display. Backs the hotkey and runs on quit.
    func restoreAll() {
        for id in disabled { try? setEnabled(id, true) }
        disabled.removeAll()
    }

    /// Re-reads the names of the displays currently visible. Detached displays report no
    /// name, so their cached entries are left alone.
    private func refreshNames() {
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else { continue }
            cachedNames[CGDirectDisplayID(number.uint32Value)] = screen.localizedName
        }
    }

    /// Wraps the two-pass calling convention of CGGetActiveDisplayList / CGGetOnlineDisplayList.
    private static func enumerate(
        _ list: (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>?) -> CGError
    ) -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard list(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard list(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }
}
