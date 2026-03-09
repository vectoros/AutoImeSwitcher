// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AutoImeSwitcher",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "AutoImeSwitcher", targets: ["AutoImeSwitcher"])
    ],
    targets: [
        .executableTarget(
            name: "AutoImeSwitcher",
            path: "Sources"
        )
    ]
)
