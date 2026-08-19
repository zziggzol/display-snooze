// 画面を macOS のレイアウトから切り離す/戻す処理の中核。
// SkyLight の非公開 API への依存をこのファイルだけに閉じ込め、他のファイルからは普通の型として見えるようにする。

import AppKit
import CoreGraphics

/// メニューに出すために必要な、画面1枚ぶんの情報。
struct DisplayInfo {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltin: Bool
    /// 描画対象になっているか。false なら切り離し済み。
    let isActive: Bool
}

/// 切り離しに失敗した、または拒否した理由。
enum DisplayControlError: LocalizedError {
    case symbolUnavailable
    case wouldLeaveNoScreen
    case configurationFailed(CGError)

    var errorDescription: String? {
        switch self {
        case .symbolUnavailable:
            return "この macOS には画面の切り離しに必要な機能が見つかりませんでした。"
        case .wouldLeaveNoScreen:
            return "最後の1枚は切り離せません。何も映らなくなってしまいます。"
        case .configurationFailed(let error):
            return "画面設定の変更に失敗しました（コード \(error.rawValue)）。"
        }
    }
}

/// SkyLight の CGSConfigureDisplayEnabled の型。
/// 公開されていない関数なので、ヘッダではなく実行時に dlsym で引く。
private typealias ConfigureDisplayEnabled =
    @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

@MainActor
final class DisplayController {
    /// このアプリが切り離した画面。OS の一覧から消えても項目を出し続けるために覚えておく。
    private(set) var disabled: Set<CGDirectDisplayID> = []

    /// 切り離すと画面名が取れなくなるので、見えているうちに控えておく。
    private var cachedNames: [CGDirectDisplayID: String] = [:]

    private let configureDisplayEnabled: ConfigureDisplayEnabled?

    /// 切り離し機能が使えるか。使えない macOS では UI 側で理由を出す。
    var isSupported: Bool { configureDisplayEnabled != nil }

    init() {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let handle = dlopen(path, RTLD_NOW),
              let symbol = dlsym(handle, "CGSConfigureDisplayEnabled") else {
            configureDisplayEnabled = nil
            return
        }
        configureDisplayEnabled = unsafeBitCast(symbol, to: ConfigureDisplayEnabled.self)
    }

    /// 繋がっている画面を、切り離し済みのものも含めて返す。内蔵を先頭に並べる。
    func displays() -> [DisplayInfo] {
        refreshNames()
        let active = Set(Self.enumerate(CGGetActiveDisplayList))
        let online = Set(Self.enumerate(CGGetOnlineDisplayList))
        return online.union(disabled)
            .map { id in
                DisplayInfo(
                    id: id,
                    name: cachedNames[id] ?? "画面 \(id)",
                    isBuiltin: CGDisplayIsBuiltin(id) != 0,
                    isActive: active.contains(id)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isBuiltin != rhs.isBuiltin { return lhs.isBuiltin }
                return lhs.name < rhs.name
            }
    }

    /// 画面1枚を切り離す、または戻す。
    /// - Parameters:
    ///   - id: 対象の画面。
    ///   - enabled: true で戻し、false で切り離す。
    /// - Throws: 最後の1枚を切ろうとした場合や、OS が設定変更を拒否した場合。
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

        // .forSession なので再起動すれば必ず元に戻る。詰んだときの最後の逃げ道。
        let completed = CGCompleteDisplayConfiguration(config, .forSession)
        guard completed == .success else { throw DisplayControlError.configurationFailed(completed) }

        if enabled { disabled.remove(id) } else { disabled.insert(id) }
    }

    /// 切り離してある画面をすべて戻す。ホットキーとアプリ終了時の保険。
    func restoreAll() {
        for id in disabled { try? setEnabled(id, true) }
        disabled.removeAll()
    }

    /// 今見えている画面の名前を控え直す。切り離し中の画面は OS から名前が取れないので上書きしない。
    private func refreshNames() {
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else { continue }
            cachedNames[CGDirectDisplayID(number.uint32Value)] = screen.localizedName
        }
    }

    /// CGGetActiveDisplayList / CGGetOnlineDisplayList の二段階呼び出しをまとめる。
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
