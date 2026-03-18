// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MoriTerminal",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "MoriTerminal", targets: ["MoriTerminal"]),
    ],
    targets: [
        .target(
            name: "MoriTerminal",
            path: "Sources/MoriTerminal"
        ),
    ]
)
