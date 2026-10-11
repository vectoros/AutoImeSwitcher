# AutoImeSwitcher

A macOS application that automatically switches input methods when you switch between foreground apps.

## Features

- Set default input methods for different applications
- Automatically switch input methods when switching foreground apps
- Menu bar icon for easy access to settings
- Visual configuration interface
- Runtime log viewing functionality

## System Requirements

- macOS 12.0 or later
- Swift 5.9 or later

## Installation

### Build from Source

1. Clone this repository
2. Run the app packaging script in the project root:

```bash
bash scripts/package_app.sh
```

3. The built application will be generated automatically
4. Generate DMG file

```bash
bash scripts/package_dmg.sh
```

### Install from DMG (requires manual build)

1. Download the latest `AutoImeSwitcher.dmg` file
2. Mount the DMG file
3. Drag `AutoImeSwitcher.app` into the `Applications` folder

## Usage

1. Launch the AutoImeSwitcher application
2. Click the keyboard icon in the menu bar
3. In the settings interface, click the "Add Application" button to select applications to configure
4. Select the default input method for each application
5. When switching between applications, the input method will automatically switch

## Project Structure

```
AutoImeSwitcher/
├── Sources/              # Source code
│   ├── AutoImeSwitcherApp.swift  # App entry point
│   ├── AppState.swift             # App state management
│   ├── InputSourceManager.swift   # Input method management
│   └── SettingsView.swift         # Settings interface
├── Resources/            # Resource files
│   ├── AppIcon.icns      # App icon
│   └── dmg-background.png
├── scripts/              # Build scripts
│   ├── package_app.sh    # App packaging script
│   └── package_dmg.sh    # DMG packaging script
└── Package.swift         # Swift Package Manager configuration
```

## Tech Stack

- SwiftUI - User interface
- AppKit - System integration
- Carbon - Input method management
- Swift Package Manager - Dependency management

## License

MIT License

## Focus Detection and macOS 27

The app uses public NSWorkspace, Accessibility, and Carbon APIs and keeps macOS 12 as its deployment target. Application/Space changes trigger detection; a 0.6-second frontmost-process check catches missed activation events. Switching is verified with at most three attempts, and stale requests are discarded when focus changes or switching is paused.

In settings, choose **启用增强检测…** and grant the system-requested Accessibility permission to enable same-app window and text-field focus events. Without permission (or when an app does not expose accessibility events), application-level detection still works. Permission changes are picked up automatically. Custom editors may not expose standard text-field roles. No keyboard input or field contents are collected.

Settings include searchable rules, multi-app selection, a pause switch, live status, and an in-memory log (300 entries). Unconfigured apps keep the current input source. Manual changes remain in effect after a switch transaction completes, until the next supported focus event. Temporarily unavailable input sources retain their rules.

## Development and Validation

```bash
swift build
swift test --disable-xctest
swift run
```

Tests require Swift 6 or later with Swift Testing. Swift Testing covers stale focus requests, cancellation, bounded retries, delayed input-source restoration, and configuration preservation. For manual validation on macOS 27, test rapid app switching, same-app windows/text fields with and without permission, Spaces/full-screen transitions, wake/unlock, unavailable input methods, and pause/resume. Test third-party input methods separately; accessibility support varies by app. Avoid running two copies of the switcher during these checks.

Configuration remains at `~/Library/Application Support/AutoImeSwitcher/config.json`. Invalid configuration is preserved and reported rather than overwritten. Diagnostics stay in memory; no local debug server is required.
