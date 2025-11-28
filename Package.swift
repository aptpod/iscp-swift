// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iSCP",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "iSCP",
            targets: ["iSCP"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "iSCP",
            path: "iSCP.xcframework"
        )
    ]
)
