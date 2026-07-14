// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "IvansMenu",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "IvansMenuKit"),
        .executableTarget(
            name: "IvansMenu",
            dependencies: ["IvansMenuKit"],
            exclude: ["Info.plist"],
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "IvansMenuKitTests", dependencies: ["IvansMenuKit"]),
    ]
)
