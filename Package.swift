// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BirderStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BirderCore", targets: ["BirderCore"]),
        .library(name: "BirderUI", targets: ["BirderUI"]),
        .executable(name: "BirderApp", targets: ["BirderApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "BirderCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/BirderCore"
        ),
        .target(
            name: "BirderUI",
            path: "Sources/BirderUI"
        ),
        .executableTarget(
            name: "BirderApp",
            dependencies: ["BirderCore", "BirderUI"],
            path: "Sources/BirderApp"
        ),
        .testTarget(
            name: "BirderCoreTests",
            dependencies: ["BirderCore"],
            path: "Tests/BirderCoreTests"
        ),
        .testTarget(
            name: "BirderUITests",
            dependencies: ["BirderUI"],
            path: "Tests/BirderUITests"
        )
    ],
    swiftLanguageModes: [.v6]
)
