# README and app artwork

## Logo

- `vitabridge-logo.svg`: editable original vector artwork, a handheld controller with a bridge emblem on a graphite tile.
- `vitabridge-logo.png`: 512×512 raster version used by the README.
- `Sources/VitaBridgeApp/Assets.xcassets/AppIcon.appiconset`: ten native macOS icon-size/scale variants, including 1024×1024, generated from the same drawing.

The icon is authored as deterministic vector geometry in `scripts/generate-brand-assets.swift`; no AI image tool, console artwork or third-party logo was used. The SVG expresses the same design for editing; keep its geometry/colors and the Swift renderer synchronized when changing it. Original artwork is covered by the repository's MIT license.

Regenerate PNGs and app-icon metadata from the repository root:

```sh
xcrun swift -module-cache-path /private/tmp/vitabridge-brand-module-cache \
  scripts/generate-brand-assets.swift
```

The Xcode asset catalog's app icon is set to `AppIcon`. The asset catalog is excluded from the SwiftPM executable target because the proper packaged app/icon is built by Xcode. Runtime SwiftPM modules/tests remain available.

## Screenshots

- `dashboard.png`: Dashboard with the real loopback simulator connected, injection paused.
- `controller-test.png`: Controller Test with actual decoded simulated buttons/sticks/touch/motion.

These are captures of the production SwiftUI views in a native app window, using the same AppModel, transport, decoder and mapping modules. They are not generated mockups. The **SIMULATED** labels remain visible. Packet values vary on each capture and do not measure physical Vita performance. Native USB inventory may show actual devices connected during capture; that is not a game-compatibility result.

To regenerate in a logged-in graphical macOS session:

```sh
./scripts/capture-readme-screenshots.sh
```

The script builds Release, compiles a small harness with the production view sources, opens its own temporary window, starts loopback input, and captures only its rendered view hierarchy. It does not take a desktop screenshot or require Screen Recording permission. It uses public default profiles in memory and a volatile empty manual-IP preference; it does not save profiles or expose a saved personal IP. Keyboard/mouse output stays paused, and the harness stops its connection and exits afterwards. Stop other demo/test instances using loopback ports 15000/15001 first. Do not run network tests concurrently with the capture.

Inspect both PNGs before committing. Regenerate the images whenever interface changes make them stale. `build/` holds the disposable capture executable and remains ignored by Git; final documentation PNGs and icon assets belong in the repository.
