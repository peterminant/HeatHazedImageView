// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HeatHazedImageView",
    platforms: [
        .iOS(.v10), .tvOS(.v10)
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
            dependencies: []),
    ]
)
