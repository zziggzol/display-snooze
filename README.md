# DisplaySnooze

メニューバーから外部ディスプレイをオフ／オンするだけの macOS アプリ。

Lunar や BetterDisplay の「ディスプレイを切る」機能だけが欲しい人向けに、その1機能に絞ってある。

## 使い方

メニューバーのディスプレイアイコンをクリックすると、繋がっている画面が並ぶ。
チェックが付いているのが表示中。クリックで切り替わる。

- **すべて戻す** — `⌃⌥⌘D`。メニューに手が届かなくなったときの保険
- **終了** — 終了時に切り離した画面をすべて戻す

## 安全のしくみ

3段構えで「画面が全部消えて操作不能」を防いでいる。

1. 表示中の画面が1枚だけのときは切り離しを拒否する（蓋を閉じて外部だけで使っている場合も含む）
2. `⌃⌥⌘D` でいつでも全部戻せる
3. 設定はセッション限り（`.forSession`）なので、再起動すれば必ず元に戻る

## ビルド

Xcode は不要。Command Line Tools だけで作れる。

```sh
./scripts/build-app.sh
open build/DisplaySnooze.app
```

ログイン時に自動で起動させたい場合は、システム設定 → 一般 → ログイン項目 に `build/DisplaySnooze.app` を追加する。

## しくみ

DDC/CI（ケーブル越しにモニタの電源や輝度を操作する規格）は**使っていない**。

Apple Silicon の DDC は USB-C の DisplayPort Alt Mode 接続でしか通らず、HDMI や DVI に変換して繋いでいると失敗する。代わりに SkyLight の非公開 API `CGSConfigureDisplayEnabled` で画面を macOS のレイアウトから外している。信号が止まったモニタは自分でスタンバイに入るので、結果は同じ。

この方式には利点もあって、**接続方式を問わず効く**。DVI 変換アダプタ経由でも動く。

依存はこの1つだけで、`Sources/DisplaySnooze/DisplayController.swift` の中に閉じ込めてある。

## 既知の制限

- **ウィンドウの配置が崩れる。** 切り離すとウィンドウが残った画面へ寄り、戻しても元の位置には帰らない。直すには全ウィンドウの座標を記録・復元する必要があり、Accessibility 権限も要るため入れていない
- 非公開 API を使っているので、将来の macOS で動かなくなる可能性がある。その場合はメニューに「この Mac では使えません」と出る
- スリープからの復帰後にどうなるかは未検証

## 構成

| ファイル | 役割 |
| --- | --- |
| `Sources/DisplaySnooze/main.swift` | 起動とアプリ本体 |
| `Sources/DisplaySnooze/DisplayController.swift` | 切り離し・復帰の中核。非公開 API はここだけ |
| `Sources/DisplaySnooze/StatusMenu.swift` | メニューバーの表示 |
| `Sources/DisplaySnooze/HotKey.swift` | `⌃⌥⌘D` の登録 |
| `scripts/build-app.sh` | `.app` の組み立てと ad-hoc 署名 |
