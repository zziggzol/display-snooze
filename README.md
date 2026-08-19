# DisplaySnooze

A macOS menu bar app that turns external displays off and back on. That is all it does.

日本語版は [README.ja.md](README.ja.md)。

## Why

Apple Silicon Macs only speak DDC/CI over USB-C DisplayPort Alt Mode. Attach a display through an HDMI or DVI adapter and every DDC-based tool — Lunar, BetterDisplay, `m1ddc` — stops being able to reach it.

DisplaySnooze does not use DDC. It removes the display from the macOS display layout; the monitor loses its signal and drops into standby on its own. That works no matter how the display is attached.

## Usage

Click the menu bar icon to list every attached display. A checkmark means the display is on. Click one to toggle it.

- **Restore All Displays** (`⌃⌥⌘D`) — a global hotkey, for when the menu itself is out of reach
- **Open at Login** — registers the app as a login item through `SMAppService`
- **Quit DisplaySnooze** — quitting restores every display the app turned off

## Safety

Three layers guard against turning off every screen and locking yourself out:

1. The last active display cannot be turned off. This covers clamshell mode, where the built-in display is already inactive
2. `⌃⌥⌘D` restores everything from anywhere, without the menu
3. Changes apply to the current session only, so a reboot always brings the original layout back

## Requirements

macOS 14 or later. No permissions are requested — no Accessibility, no Screen Recording.

## Install

Xcode is not required. The Command Line Tools are enough.

```sh
git clone https://github.com/zziggzol/display-snooze.git
cd display-snooze
./scripts/install.sh
```

That builds the app, places it in `/Applications`, and launches it. To try it without installing, run `./scripts/build-app.sh` and open `build/DisplaySnooze.app`.

## How it works

macOS offers no public API for disconnecting a display. DisplaySnooze resolves one private symbol at runtime and calls it inside a standard `CGBeginDisplayConfiguration` / `CGCompleteDisplayConfiguration` pair.

| Library | Symbol |
| --- | --- |
| SkyLight | `SLSConfigureDisplayEnabled` |
| SkyLight | `CGSConfigureDisplayEnabled` |
| CoreGraphics | `CGSConfigureDisplayEnabled` |

All three resolve on macOS 26.6.1. They are tried newest-first, so the app keeps working if any single one is withdrawn. The change is applied with `.forSession`, which is why a reboot always undoes it.

The entire private-API surface lives in [`Sources/DisplaySnooze/DisplayController.swift`](Sources/DisplaySnooze/DisplayController.swift).

## Verified on

MacBook Air (M5), macOS 26.6.1, an EIZO CG2420 attached through an adapter that does not carry DDC. `m1ddc` fails with `DDC communication failure` on this setup; DisplaySnooze works.

Two things turned out not to need any handling:

- **Window positions survive a disconnect and reconnect.** macOS restores them itself
- **The disconnected state survives sleep.** Nothing has to be reapplied on wake

## Limitations

- It relies on a private API, so a future macOS release may break it. The menu then reads "Not available on this Mac" rather than failing silently
- Login item registration records the bundle path, so moving the app means re-enabling the toggle
- Untested: leaving a display disconnected for a long time, or unplugging the cable while it is disconnected

## Icon

The icon is drawn in code ([`scripts/make-icon.swift`](scripts/make-icon.swift)) instead of being checked in as an image, so the design stays editable without Xcode's Icon Composer. It is a [lucide](https://lucide.dev) `monitor-off` glyph over a gradient defined in OKLCh.

## Alternatives

DisplaySnooze deliberately does one thing. If you want more, these are all free and open source:

| Project | Focus |
| --- | --- |
| [Crisp](https://github.com/didriksg/Crisp) | Broad display management, disconnect included |
| [SimpleDisplay](https://simpledisplay.app/) | Display toggling via mirroring, plus virtual displays |
| [Dimly](https://github.com/punshnut/macos-dimly) | Brightness, blackout, and DDC sleep |
| [disdim](https://github.com/makalin/disdim) | Minimal, DDC-based display off |

## License

MIT
