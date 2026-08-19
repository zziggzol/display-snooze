// グローバルホットキーの登録。Carbon の RegisterEventHotKey を使うので追加の権限許可が要らない。
// 画面を切り離してメニューバーに手が届かなくなったときに、確実に戻すための保険として置いている。

import AppKit
import Carbon.HIToolbox

/// C の関数ポインタはクロージャを捕まえられないので、押されたときの動作をここに置く。
nonisolated(unsafe) private var registeredAction: (@MainActor () -> Void)?

@MainActor
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// ホットキーを1つ登録する。他のアプリに先を越されている場合は nil を返す。
    /// - Parameters:
    ///   - keyCode: kVK_ANSI_D などの仮想キーコード。
    ///   - modifiers: controlKey / optionKey / cmdKey の組み合わせ。
    ///   - action: 押されたときに main アクター上で実行する処理。
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

    /// 登録を解除する。アプリ終了時に呼ぶ。
    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        registeredAction = nil
    }
}
