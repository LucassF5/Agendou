// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AgendouCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AgendouCore", targets: ["AgendouCore"])
    ],
    targets: [
        .target(name: "AgendouCore"),
        .testTarget(
            name: "AgendouCoreTests",
            dependencies: ["AgendouCore"],
            resources: [.copy("Fixtures/schedule_cases.json")]
        ),
    ]
)
