// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UnduhQu",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "UnduhKit", targets: ["UnduhKit"]),
        .executable(name: "UnduhQu", targets: ["UnduhQuApp"]),
    ],
    targets: [
        .target(name: "UnduhKit"),
        .executableTarget(name: "UnduhQuApp", dependencies: ["UnduhKit"]),
        .testTarget(name: "UnduhKitTests", dependencies: ["UnduhKit"]),
    ]
)
