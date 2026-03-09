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
./scripts/package_app.sh
```

3. The built application will be generated automatically
4. Generate DMG file

```bash
./scripts/package_dmg.sh
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
