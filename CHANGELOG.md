# Changelog

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
