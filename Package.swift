// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DMPlus",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DMPlusKit", targets: ["DMPlusKit"]),
        .executable(name: "DMPlus", targets: ["DMPlusApp"]),
        .executable(name: "DMPlusMsgHost", targets: ["DMPlusMsgHost"]),
    ],
    targets: [
        .target(name: "DMPlusKit"),
        .executableTarget(name: "DMPlusApp", dependencies: ["DMPlusKit"]),
        .executableTarget(name: "DMPlusMsgHost"),
        .testTarget(name: "DMPlusKitTests", dependencies: ["DMPlusKit"]),
    ]
)
