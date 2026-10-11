# Repository Guidelines

## Project Structure & Module Organization
AutoImeSwitcher is a macOS menu bar app built with SwiftUI, AppKit, and Carbon. `Package.swift` defines one Swift Package Manager executable target, with no external dependencies.

- `Sources/AutoImeSwitcherApp.swift`: entry point, menu bar, and window lifecycle.
- `Sources/AppState.swift`: application activation observers, mapping persistence, and runtime logging.
- `Sources/FocusMonitor.swift`: workspace and optional accessibility focus detection.
- `Sources/SwitchCoordinator.swift`: bounded, cancellable switching transactions.
- `Sources/MappingStore.swift`: backward-compatible rule serialization.
- `Sources/InputSourceManager.swift`: Carbon input-source enumeration, resolution, and selection.
- `Sources/SettingsView.swift`: settings, application picker, and log display.
- `Resources/`: app icons and DMG background; `scripts/` contains their Python generators and packaging scripts.
- `README.md` and `README_CN.md`: English and Chinese documentation. Keep usage changes synchronized.

## Build, Test, and Development Commands
Use macOS 12 or later with Swift 5.9 or later. Run commands from the repository root; packaging also requires Python 3 and macOS command-line tools.

- `swift build`: compile a debug executable.
- `swift run`: build and launch locally.
- `swift build -c release --disable-sandbox`: build the release executable used by packaging.
- `bash scripts/package_app.sh`: regenerate icons, build, and ad-hoc sign `dist/MacOS/AutoImeSwitcher.app`.
- `bash scripts/package_dmg.sh`: rebuild the app and create `dist/AutoImeSwitcher.dmg`; requires a graphical Finder session.

## Coding Style & Naming Conventions
Match existing four-space indentation and same-line opening braces. Use `UpperCamelCase` for Swift types and `lowerCamelCase` for properties and functions. Keep filenames aligned with their primary type. Prefer `private` implementation helpers and `guard` for early exits. Keep Carbon calls in `InputSourceManager` and observable UI updates on the main thread. Python helpers use `snake_case`; shell scripts use `set -euo pipefail`. No formatter or linter is configured.

## Testing Guidelines
`swift test --disable-xctest` (Swift 6+) runs cases in `Tests/AutoImeSwitcherTests/` for switching races, retries, and configuration preservation. No coverage threshold is configured. Build and manually verify adding/removing mappings, switching between configured and unconfigured apps, persistence after relaunch, input-source refresh, and menu bar/window behavior. Record macOS version and input methods tested. Name test files `*Tests.swift`; keep OS-dependent focus validation separate from deterministic unit tests.

## Commit & Pull Request Guidelines
History uses short descriptive subjects such as `Update README.md`; no strict commit convention is established. Use concise imperative subjects. PRs should explain the behavior change, link relevant issues, describe validation, and include screenshots for UI changes. Exclude `.build/`, `dist/`, and personal debug logs from commits.

## Configuration & Diagnostics
Mappings reside in `~/Library/Application Support/AutoImeSwitcher/config.json`; preserve existing entries when changing persistence. Logs stay in memory. Enhanced window/text-field detection requires optional Accessibility permission; app-level detection works without it. `debug.md` documents validation and toolchain troubleshooting.
