// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NativeNetKitNetworkHarness",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(name: "NativeNetKit", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "NativeNetKitNetworkHarness",
            dependencies: [
                .product(name: "NativeNetKit", package: "NativeNetKit")
            ]
        )
    ]
)
