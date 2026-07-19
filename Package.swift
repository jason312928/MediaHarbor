// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MediaHarbor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MediaHarbor", targets: ["MediaHarbor"])
    ],
    targets: [
        .executableTarget(
            name: "MediaHarbor",
            path: "Sources/MediaHarbor",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
