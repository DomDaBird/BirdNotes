// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BirdNotesTechnicalCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BirdNotesTechnicalCore",
            targets: ["BirdNotesTechnicalCore"]
        )
    ],
    targets: [
        .target(name: "BirdNotesTechnicalCore"),
        .testTarget(
            name: "BirdNotesTechnicalCoreTests",
            dependencies: ["BirdNotesTechnicalCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
