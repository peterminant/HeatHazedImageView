// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HeatHazedImageView",
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