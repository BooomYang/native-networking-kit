// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NativeNetKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "NativeNetKit", targets: ["NativeNetKit"])
    ],
    targets: [
        .target(name: "NativeNetKit"),
        .testTarget(name: "NativeNetKitTests", dependencies: ["NativeNetKit"])
    ]
)
