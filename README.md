# DisplaySnooze

メニューバーから外部ディスプレイをオフ／オンするだけの macOS アプリ。

Lunar や BetterDisplay の「ディスプレイを切る」機能だけが欲しい人向けに、その1機能に絞ってある。

## 使い方

メニューバーのディスプレイアイコンをクリックすると、繋がっている画面が並ぶ。
チェックが付いているのが表示中。クリックで切り替わる。UI の文言は英語。

- **Restore All Displays** — `⌃⌥⌘D`。メニューに手が届かなくなったときの保険
- **Open at Login** — チェックを入れると自動起動が有効になる。初回は macOS が「バックグラウンド項目が追加されました」と通知するので、以後はシステム設定 → 一般 → ログイン項目 からも許可・解除できる
- **Quit DisplaySnooze** — 終了時に切り離した画面をすべて戻す

終了項目にアプリ名を入れているのは、メニューバー常駐アプリには名前を出せる場所がここしかないため。名前は Info.plist の `CFBundleName` から取っているので、変えればメニューも追従する。

## 安全のしくみ

3段構えで「画面が全部消えて操作不能」を防いでいる。

1. 表示中の画面が1枚だけのときは切り離しを拒否する（蓋を閉じて外部だけで使っている場合も含む）
2. `⌃⌥⌘D` でいつでも全部戻せる
3. 設定はセッション限り（`.forSession`）なので、再起動すれば必ず元に戻る

## ビルドとインストール

Xcode は不要。Command Line Tools だけで作れる。

```sh
./scripts/install.sh
```

ビルドして `/Applications/DisplaySnooze.app` に置き、起動するところまでやる。動いているものがあれば入れ替える。

インストールせず手元で試すだけなら次のとおり。

```sh
./scripts/build-app.sh
open build/DisplaySnooze.app
```

## アイコン

`scripts/make-icon.swift` がコードで描いている。lucide の `monitor-off` が下敷きで、色は oklch で定義してある。ビルド時に更新を見て、変わっていれば描き直す。

```sh
ICON_VARIANT=light ./scripts/build-app.sh
```

明るい配色も用意してある。既定は濃い藍。

## しくみ

DDC/CI（ケーブル越しにモニタの電源や輝度を操作する規格）は**使っていない**。

Apple Silicon の DDC は USB-C の DisplayPort Alt Mode 接続でしか通らず、HDMI や DVI に変換して繋いでいると失敗する。代わりに SkyLight の非公開 API `CGSConfigureDisplayEnabled` で画面を macOS のレイアウトから外している。信号が止まったモニタは自分でスタンバイに入るので、結果は同じ。

この方式には利点もあって、**接続方式を問わず効く**。DVI 変換アダプタ経由でも動く。

同じ処理は SkyLight では `SLSConfigureDisplayEnabled` と `CGSConfigureDisplayEnabled` の2つの名前で、CoreGraphics では後者だけで公開されている。将来どれかが消えても動くよう、新しい名前から順に探す。

非公開 API への依存はこれだけで、`Sources/DisplaySnooze/DisplayController.swift` の中に閉じ込めてある。

## 動作を確認した環境

MacBook Air (M5) / macOS 26.6.1 / EIZO CG2420 を変換アダプタ経由で接続。

この構成では DDC/CI が通らない（`m1ddc` は `DDC communication failure` で失敗する）が、本アプリの方式では切り離し・復帰とも問題なく動いた。

確認できたこと:

- **戻したあとのウィンドウ配置が元通りになる。** macOS がディスプレイごとの配置を覚えているため、こちらで記録・復元する必要はなかった
- **スリープから復帰しても切り離した状態が保たれる。** 復帰時に切り直す処理は要らない

## 既知の制限

- 非公開 API を使っているので、将来の macOS で動かなくなる可能性がある。その場合はメニューに「この Mac では使えません」と出る
- 長時間切り離したままにした場合や、その間にケーブルを抜き差しした場合もウィンドウ配置が保たれるかは未検証
- 自動起動には `.app` の置き場所が記録される。`build/` の中のものと `/Applications` のものは別々に扱われるので、常用する側で登録し直す

## 構成

| ファイル | 役割 |
| --- | --- |
| `Sources/DisplaySnooze/main.swift` | 起動とアプリ本体 |
| `Sources/DisplaySnooze/DisplayController.swift` | 切り離し・復帰の中核。非公開 API はここだけ |
| `Sources/DisplaySnooze/StatusMenu.swift` | メニューバーの表示 |
| `Sources/DisplaySnooze/HotKey.swift` | `⌃⌥⌘D` の登録 |
| `Sources/DisplaySnooze/LaunchAtLogin.swift` | 自動起動の登録・解除（`SMAppService`） |
| `scripts/make-icon.swift` | アイコンの描画と `.iconset` の書き出し |
| `scripts/build-app.sh` | `.app` の組み立てと ad-hoc 署名 |
| `scripts/install.sh` | `/Applications` への配置と入れ替え |
