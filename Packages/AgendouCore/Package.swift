// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AgendouCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AgendouCore", targets: ["AgendouCore"]),
        .library(name: "AgendouStore", targets: ["AgendouStore"]),
    ],
    targets: [
        .target(name: "AgendouCore"),
        .testTarget(
            name: "AgendouCoreTests",
            dependencies: ["AgendouCore"],
            resources: [.copy("Fixtures/schedule_cases.json")]
        ),
        // SwiftData models and the domain service: the only way the app writes data.
        .target(
            name: "AgendouStore",
            dependencies: ["AgendouCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "AgendouStoreTests",
            dependencies: ["AgendouStore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
