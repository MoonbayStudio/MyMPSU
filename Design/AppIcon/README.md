# MyMPSU Apple app icon

The app icon is built from the user-approved transparent MPGU building artwork in
`Source/mpgu-building-approved.png`.

`scripts/export-apple-app-icons.swift` performs only deterministic operations:

- fits the approved blue PNG onto a square 1024 px canvas without cropping, at
  82% of the edge-to-edge fit so the detailed building has comfortable padding;
- derives uniform `#1F77B4` and white layers by replacing RGB while preserving
  every alpha value;
- writes light, dark, and tinted iOS asset-catalog fallbacks;
- updates the two-layer Icon Composer packages for iOS and Tauri macOS;
- generates the static macOS `.icns` fallback for systems before macOS 26.

Run it from the repository root:

```sh
./scripts/export-apple-app-icons.swift
```

## Appearance support

| Platform | Default | Dark | Tinted / mono | Older-system fallback |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | Blue building on the system light surface | White building on the system dark surface | White mask, recolored by the system | `AppIcon.appiconset` PNG renditions |
| macOS 26+ desktop | Blue layered building | White layered building | Icon Composer clear/tinted rendering | — |
| macOS 10.15–15 desktop | Static blue light icon | No dynamic Dock-icon switch | No dynamic tint | `icon.icns` |

The Xcode app uses `iOS/MyMPSU/AppIcon.icon`. The Tauri bundle uses
`Desktop/src-tauri/icons/AppIcon.icon`; the export script precompiles it into
`Assets.car` for the current Tauri bundler and keeps `icon.icns` as a compatibility
fallback. Do not place secrets or release signing material in either icon package.

Official references:

- <https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer>
- <https://developer.apple.com/documentation/xcode/configuring-your-app-icon>
