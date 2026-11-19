// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WrapAround",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "WrapCore"),
        .executableTarget(name: "WrapAround", dependencies: ["WrapCore"]),
        .testTarget(name: "WrapCoreTests", dependencies: ["WrapCore"]),
    ]
)
