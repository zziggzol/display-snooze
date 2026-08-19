// Registration of the global hotkey. Carbon's RegisterEventHotKey is used because it
// needs no permission grant from the user.
// It exists as a way out of the state where a display has been detached and the menu
// bar is no longer reachable.

import AppKit
import Carbon.HIToolbox

/// A C function pointer cannot capture, so what to run on press lives here.
nonisolated(unsafe) private var registeredAction: (@MainActor () -> Void)?

@MainActor
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Registers one hotkey. Returns nil if another app already holds the combination.
    /// - Parameters:
    ///   - keyCode: A virtual key code such as kVK_ANSI_D.
    ///   - modifiers: Any combination of controlKey, optionKey and cmdKey.
    ///   - action: Run on the main actor when the combination is pressed.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        registeredAction = action

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installed = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                Task { @MainActor in registeredAction?() }
                return noErr
            },
            1, &spec, nil, &handlerRef
        )
        guard installed == noErr else { return nil }

        let id = EventHotKeyID(signature: OSType(0x44535A4B), id: 1)  // 'DSZK'
        let registered = RegisterEventHotKey(
            keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard registered == noErr, hotKeyRef != nil else {
            RemoveEventHandler(handlerRef)
            handlerRef = nil
            return nil
        }
    }

    /// Releases the registration. Called when the app quits.
    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        registeredAction = nil
    }
}
