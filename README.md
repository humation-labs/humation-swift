<p align="center">
  <img src="Assets/editor.png" alt="Humation avatar editor" width="300">
</p>

# Humation

[![CI](https://github.com/humation-labs/humation-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/humation-labs/humation-swift/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138.svg?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20visionOS-blue.svg)](#)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

A native Swift port of [Humation](https://github.com/humation-labs/humation) — a
deterministic, hand-drawn SVG avatar engine. Same seed → same avatar, rendered
**entirely with Core Graphics** (no `WKWebView`), pixel-faithful to the
reference renderer.

- **Deterministic**: a seed (e.g. a user id) maps to a fixed set of parts via
  FNV-1a, byte-identical to the TypeScript engine.
- **Native rendering**: an SVG subset is parsed to `CGPath` and composited to a
  `CGImage` / `UIImage`. No web view, no network.
- **Recolourable**: six colour slots (`background`, `stroke`, `hair`, `skin`,
  `clothes`, `bottom`) bound through `var(--hm-*)` references.
- **Bundled assets**: the full `humation-1` set (86 parts) ships as a package
  resource — nothing to download.
- **Platforms**: iOS 15+, macOS 12+, tvOS 15+, visionOS 1+. Swift 6, strict
  concurrency clean.

## How it works

Seed → FNV-1a hash → pick one part per slot (head / body / bottom / item /
glasses) → stack each part's SVG layers in `order` → bind the six colour slots →
crop and rasterise. Selection and hashing are byte-identical to the reference
engine, so the same seed yields the same avatar on web and native.

## Demo

<p align="center">
  <img src="Assets/demo.gif" alt="Humation avatar editor demo" width="280">
</p>

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/humation-labs/humation-swift.git", from: "1.0.0")
```

## Usage

The `Humation` facade covers the common cases:

```swift
import Humation

// Optional: decode the bundled manifest off the main thread at launch.
Humation.prewarm()

// Seed → image, one line (UIImage on iOS/tvOS, NSImage on macOS, CGImage anywhere)
let image  = Humation.image(seed: user.id, pixels: 256)     // UIImage?
let cg     = Humation.cgImage(seed: user.id, pixels: 256)   // CGImage?

// SwiftUI — resolves against the bundled manifest for you
HumationAvatarView(seed: user.id, size: 96)
HumationAvatarView(profile: profile, seed: user.id, size: 96)

// "Surprise me" — a random avatar
if let random = Humation.randomProfile() {
    let image = Humation.image(profile: random, pixels: 256)
}
```

Full control via the lower-level types:

```swift
let manifest = Humation.manifest!                 // bundled humation-1
var traits = HumationTraits()
traits.selections[.head] = manifest.parts(in: .head).first!.id
traits.colors[.hair] = "5B3A1E"
let resolved = traits.resolved(against: manifest)
let cg = HumationRenderer.render(resolved: resolved, manifest: manifest, pixels: 256)
```

### Custom / served asset packs

Load and validate a manifest authored outside the bundled set:

```swift
let pack = try Humation.manifest(contentsOf: url)        // or .manifest(from: data)
let issues = HumationValidator.validate(pack)            // [] = renderable
guard issues.isEmpty else { print(issues); return }
```

### Persistable profiles

`HumationProfile` is a `Codable` / `Sendable` wire format for storing or syncing
an avatar — the chosen part per slot plus colour overrides — independent of the
asset pack. Round-trip it through your own storage, then render:

```swift
// Capture the current design as a serialisable profile.
let profile = HumationProfile(resolved: resolved)
let json = try JSONEncoder().encode(profile)

// …later: decode and render (UIImage / CGImage / NSImage).
let restored = try JSONDecoder().decode(HumationProfile.self, from: json)
let image = Humation.image(profile: restored, seed: user.id, pixels: 256)
```

Profiles *heal* on resolve: part ids that are stale or no longer valid for their
slot (e.g. after an asset-pack update) fall back to `seed`, then to manifest
defaults — so a persisted profile always renders something valid.

### Rendering options

`HumationRenderer.render` / `pngData` take a `shape` (`.square` default, or
`.circle` for a pre-clipped round avatar). `pngData` returns raw `Data` when you
need bytes rather than an image — e.g. a notification-service extension payload:

```swift
let png = HumationRenderer.pngData(
    resolved: resolved, manifest: manifest, pixels: 128, shape: .circle
)
```

### Sharing

`ResolvedHumation` conforms to `Transferable` (iOS 16 / macOS 13+), so avatars
drop straight into a share sheet, drag session, or pasteboard as a PNG. There's
also a `pngData()` convenience that renders against the bundled manifest:

```swift
ShareLink(item: resolved, preview: .init("My avatar"))   // exports a 512px PNG

let png = resolved.pngData(pixels: 256, shape: .circle)  // Data?
```

## Built-in editor

`HumationEditor` is an optional product with a ready-made avatar builder. Add it
next to `Humation` in your target's dependencies, then bind a profile:

```swift
import HumationEditor

@State private var profile = HumationProfile()   // empty → healed from seed / defaults

HumationEditorView(profile: $profile, seed: user.id)   // parts grid + colour swatches + randomise
// theme it:
HumationEditorView(profile: $profile, configuration: .init(accent: .pink))
```

`HumationEditorConfiguration` controls the tabs, per-slot colour palettes,
accent, cell background, corner radius, font, and whether background colours are
offered. The core `Humation` product has no SwiftUI editor dependency — you only
pull in `HumationEditor` if you use it.

## API at a glance

| Type | Role |
|---|---|
| `Humation` | Facade: `prewarm()`, `manifest`, `randomProfile()`, seed **or profile** → `image` / `cgImage` / `nsImage` / `resolved` |
| `HumationProfile` | `Codable` / `Sendable` avatar wire format (selections + colours) with healing on resolve; `random(in:using:)` |
| `HumationManifest` / `HumationManifestStore` | Asset manifest model + bundled `humation-1` loader |
| `HumationTraits` → `ResolvedHumation` | Input design resolved to concrete parts + colours; `Transferable` + `pngData()` for sharing |
| `HumationRenderer` | `render` / `pngData` → `CGImage` / `Data` (`shape: .square` \| `.circle`), `image` / `nsImage`, `contentBounds(of:in:)` |
| `HumationAvatarView` | SwiftUI view — cached bitmap, cross-platform; `init(seed:…)` / `init(profile:…)` convenience |
| `HumationEditorView` | Avatar builder UI (in the optional `HumationEditor` product) |
| `HumationValidator` | Lint a custom pack against the supported SVG subset |
| `HumationSelectionSlot` / `HumationColorSlot` | The 5 part slots / 6 colour slots; `displayName`, and `defaultSwatches` for colours |

## SVG subset

The bundled assets only use what the renderer implements, so authoring new parts
must stay within it:

- Path commands `M L H V C S Z` (absolute + relative). **No arcs `A`, no
  quadratics `Q`/`T`.**
- Primitives `circle` / `ellipse` / `rect` / `line` / `polygon` / `polyline`.
- Transforms `translate` / `scale` / `rotate` / `matrix` (stroke width is scaled
  with the coordinate system).
- `<style>` class rules, `fill-rule` / `clip-rule`, `clipPath`.
- Colours: `#hex`, `none`, named (`ivory`), and `var(--hm-SLOT, #fallback)` for
  recolourable regions.

## Credits

Engine, asset design, and the `humation-1` set are from
[humation-labs/humation](https://github.com/humation-labs/humation) (MIT). This is an
independent Swift/Core Graphics port. See `LICENSE`.
