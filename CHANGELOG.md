# Changelog

## 1.2.0 - 2026-07-05

- Add random avatars: `HumationProfile.random(in:using:)` / `random(in:)` and the
  `Humation.randomProfile()` facade (pass a `RandomNumberGenerator` for
  reproducible results).
- Add `HumationAvatarView(seed:size:)` and `HumationAvatarView(profile:seed:size:)`
  convenience initialisers that resolve against the bundled manifest.
- Add slot metadata: `displayName` on `HumationSelectionSlot` / `HumationColorSlot`
  and `defaultSwatches` on `HumationColorSlot` for building pickers.
- Add avatar sharing: `ResolvedHumation` conforms to `Transferable` (iOS 16 /
  macOS 13+) so avatars work with `ShareLink`, drag-and-drop, and paste as a PNG,
  plus a `ResolvedHumation.pngData(pixels:shape:)` convenience that renders
  against the bundled manifest.

## 1.1.0 - 2026-07-05

- Add `HumationProfile`: a serialisable avatar wire format with profile healing
  (stale / slot-mismatched part ids are repaired on resolve) plus `Humation`
  facade overloads (`resolved` / `cgImage` / `image` / `nsImage` from a profile).
- Add circular avatar rendering via `HumationRenderer` `shape: .square | .circle`
  (defaults to `.square`, so existing output is unchanged) and a `pngData(...)`
  convenience for notification-extension image payloads.
- Add `HumationEditor`: an optional, themeable avatar-builder UI shipped as a
  separate library product.

## 1.0.0 - 2026-06-24

- Initial Swift Package release.
- Includes the bundled `humation-1` asset set.
- Renders deterministic Humation avatars with Core Graphics, without WebView or network access.
- Supports iOS 15+, macOS 12+, tvOS 15+, and visionOS 1+.
