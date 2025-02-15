// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhisperKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "WhisperKit",
            targets: ["WhisperKit"]),
    ],
    targets: [
        .target(
            name: "WhisperKit",
            dependencies: []),
        .testTarget(
            name: "WhisperKitTests",
            dependencies: ["WhisperKit"]),
    ]
) 