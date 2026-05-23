// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Midnight",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Midnight",
            path: "Sources"
        )
    ]
)
