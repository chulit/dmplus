// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DMPlus",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DMPlusKit", targets: ["DMPlusKit"]),
        .executable(name: "DMPlus", targets: ["DMPlusApp"]),
    ],
    targets: [
        .target(name: "DMPlusKit"),
        .executableTarget(name: "DMPlusApp", dependencies: ["DMPlusKit"]),
        .testTarget(name: "DMPlusKitTests", dependencies: ["DMPlusKit"]),
    ]
)
