# Third-Party Notices

DisplaySnooze itself is MIT licensed; see [LICENSE](LICENSE). This file lists the third-party work it builds on.

## lucide

The app icon in [`scripts/make-icon.swift`](scripts/make-icon.swift) redraws the `monitor-off` glyph from lucide. `monitor-off` is original lucide work — it is not among the icons lucide derives from Feather.

<https://lucide.dev>

```
ISC License

Copyright (c) 2026 Lucide Icons and Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
```

## SF Symbols

The menu bar icon uses Apple's SF Symbols (`display`, `display.slash`) through `NSImage(systemSymbolName:)`.

Apple permits SF Symbols in the user interface of software running on Apple platforms, but not in app icons, logos, or trademarks. The app icon shipped here is drawn from scratch and contains no SF Symbol.

## Oklab

The OKLCh-to-sRGB conversion in [`scripts/make-icon.swift`](scripts/make-icon.swift) uses the matrices published by Björn Ottosson, released into the public domain (and additionally available under MIT).

<https://bottosson.github.io/posts/oklab/>

## Apple private frameworks

DisplaySnooze resolves `SLSConfigureDisplayEnabled` and `CGSConfigureDisplayEnabled` at runtime with `dlsym`. No Apple code is copied, disassembled, or redistributed.

Because these are not public API, an app using them cannot ship on the Mac App Store. Distribution outside the store is unaffected.
