// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WWMachineLearning_MNIST",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "WWMachineLearning_MNIST", targets: ["WWMachineLearning_MNIST"]),
    ],
    dependencies: [
        .package(url: "https://github.com/William-Weng/WWMachineLearning_Resnet50", from: "1.1.3")
    ],
    targets: [
        .target(name: "WWMachineLearning_MNIST", dependencies: ["WWMachineLearning_Resnet50"], resources: [.copy("Privacy")]),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
