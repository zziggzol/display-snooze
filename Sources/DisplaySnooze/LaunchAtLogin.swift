// ログイン時の自動起動の登録と解除。macOS 13 以降の ServiceManagement を使う。
// 登録すると macOS が通知を出し、以後はシステム設定のログイン項目から有効/無効を切り替えられる。

import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    /// 今の登録状態。.app バンドルとして起動していない場合は .notFound になる。
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// 登録済みで、実際に自動起動する状態か。
    static var isEnabled: Bool { status == .enabled }

    /// ユーザーがシステム設定で許可し直す必要がある状態か。
    /// 一度ログイン項目から無効にされると、アプリ側からは戻せずこの状態になる。
    static var needsApproval: Bool { status == .requiresApproval }

    /// 自動起動を有効または無効にする。
    /// 初回の有効化では macOS が「バックグラウンド項目が追加されました」という通知を出す。
    /// - Parameter enabled: true で登録、false で解除。
    /// - Throws: 署名やバンドルの条件を満たさず OS が登録を拒否した場合。
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// システム設定のログイン項目の画面を開く。承認待ちのときの導線。
    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
