// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetroidvaniaKit",
    platforms: [.macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MetroidvaniaKit",
            type: .dynamic,
            targets: ["MetroidvaniaKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", branch: "main"),
//        .package(url: "../../SwiftGodot", branch: "fix-callable-with-collections"),
//        .package(path: "../../SwiftGodot"),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
    ],
    targets: [
//        .binaryTarget(
//            name: "SwiftGodot",
//            url: "https://github.com/migueldeicaza/SwiftGodot/releases/download/0.41.0/SwiftGodot.xcframework.zip",
//            checksum: "c4f23d38903784a8e449cbf6e1baf62588ee9e8d8ed1b63bc8ce6f200f9a8018"
//        ),
//        .binaryTarget(
//            name: "SwiftGodot",
//            path: "SwiftGodot.xcframework"
//        ),
        .target(
            name: "MetroidvaniaKit",
            dependencies: [
                "SwiftGodot",
                .product(name: "Numerics", package: "swift-numerics"),
            ],
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        ), 
        .testTarget(
            name: "MetroidvaniaKitTests",
            dependencies: ["MetroidvaniaKit"]),
    ]
)
