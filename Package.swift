// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CodexMeter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexMeter", targets: ["CodexMeter"])
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            path: "Sources/CSQLite"
        ),
        .executableTarget(
            name: "CodexMeter",
            dependencies: ["CSQLite"],
            path: "Sources/CodexMeter",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreServices"),
                .linkedFramework("ServiceManagement"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "CodexMeterTests",
            dependencies: ["CodexMeter"],
            path: "Tests/CodexMeterTests"
        )
    ]
)
