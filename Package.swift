// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Autoclick",
    platforms: [.macOS(.v14)],
    targets: [
        // Image matching, geometry and the click loop. No AppKit, so it is easy to test.
        .target(name: "AutoclickCore"),
        // The macOS app: windows, screen capture, permissions and mouse events.
        .executableTarget(name: "Autoclick", dependencies: ["AutoclickCore"]),
        .testTarget(name: "AutoclickCoreTests", dependencies: ["AutoclickCore"]),
    ]
)
