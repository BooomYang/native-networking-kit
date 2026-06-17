// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NativeNetKitExample",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(name: "NativeNetKitExample", targets: ["NativeNetKitExample"])
    ],
    dependencies: [
        .package(name: "NativeNetKit", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "NativeNetKitExample",
            dependencies: [
                .product(name: "NativeNetKit", package: "NativeNetKit")
            ],
            path: "NativeNetKitExample"
        )
    ]
)
