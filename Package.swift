// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HeatHazedImageView",
    platforms: [
        .iOS(.v11), .tvOS(.v11)
    ],
    products: [
        .library(
            name: "HeatHazedImageView",
            targets: ["HeatHazedImageView"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "HeatHazedImageView",
            resources: [.process("Resources/heathaze.metal"),
                        .process("Resources/noise.png")]),
    ]
)
