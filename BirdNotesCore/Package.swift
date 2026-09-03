// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BirdNotesCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BirdNotesCore", targets: ["BirdNotesCore"])
    ],
    targets: [
        .target(
            name: "BirdNotesCore",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "BirdNotesCoreTests",
            dependencies: ["BirdNotesCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
