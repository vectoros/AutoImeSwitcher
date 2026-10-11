# Focus Detection Validation

## Automated checks

Run `swift test --disable-xctest` with Swift 6 or later. The injected scheduler exercises rapid focus changes, cancellation, retry limits, delayed source restoration, manual switching after completion, and persistence of unavailable/legacy input sources without changing system input methods.

## Manual checks (macOS 27)

Run only one switcher instance. Use two installed input methods and two configured applications.

1. Switch rapidly between configured apps and an unconfigured app. Only the actual foreground app should receive its rule; unconfigured apps retain the current source.
2. Enable enhanced detection through the settings page. Verify switching windows and standard text fields in the same app. Check permission revocation and reauthorization without restarting.
3. Try Spaces, full-screen windows, sleep/wake, and lock/unlock. A missed activation should recover on the next frontmost-process poll.
4. Pause automatic switching and verify that pending retries stop. Resume and check the current application.
5. Remove an input source in System Settings, refresh, and relaunch. Its rule must remain visible as unavailable. Restore the input source and refresh again.
6. Verify rule search, multi-app selection, duplicate additions, removal, logs, and settings-window reopening in light and dark appearance.

Inspect the in-app log for focus triggers and switch results. Logs contain application/input-source identifiers, never field contents, and are limited to 300 in-memory entries. Unsupported accessibility controls fall back to application-level detection.

## Toolchain troubleshooting

If `Package.swift` fails to link `PackageDescription.Package.__allocating_init` before sources compile, check for mixed Command Line Tools versions. On the development machine, the public PackageDescription interface was Swift 6.4 while the private interface was Swift 5.10. Use a consistent Xcode/Command Line Tools installation. A temporary copy of ManifestAPI excluding stale private interfaces can isolate this for validation; do not modify system toolchain files or commit that copy.
