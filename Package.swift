// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CodexMeter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexMeter", targets: ["CodexMeter"]),
        .executable(name: "CodexMeterClaudeBridge", targets: ["CodexMeterClaudeBridge"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            path: "Sources/CSQLite"
        ),
        .executableTarget(
            name: "CodexMeter",
            dependencies: [
                "ClaudeBridgeCore",
                "CSQLite",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/CodexMeter",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreServices"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "ClaudeBridgeCore",
            path: "Sources/ClaudeBridgeCore"
        ),
        .executableTarget(
            name: "CodexMeterClaudeBridge",
            dependencies: ["ClaudeBridgeCore"],
            path: "Sources/CodexMeterClaudeBridge"
        ),
        .testTarget(
            name: "CodexMeterTests",
            dependencies: ["CodexMeter", "ClaudeBridgeCore"],
            path: "Tests/CodexMeterTests"
        )
    ]
)
