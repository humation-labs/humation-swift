// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Humation",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Humation", targets: ["Humation"]),
        .library(name: "HumationEditor", targets: ["HumationEditor"]),
    ],
    targets: [
        .target(
            name: "Humation",
            resources: [
                .copy("Resources/humation-1.json"),
            ]
        ),
        .target(
            name: "HumationEditor",
            dependencies: ["Humation"]
        ),
        .testTarget(
            name: "HumationTests",
            dependencies: ["Humation"]
        ),
        .testTarget(
            name: "HumationEditorTests",
            dependencies: ["Humation", "HumationEditor"]
        ),
    ]
)
