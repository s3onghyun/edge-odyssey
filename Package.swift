// swift-tools-version:5.9
// Only for the tests (`swift test`): the app itself is built by build.sh.
import PackageDescription

let package = Package(
    name: "EdgeOdyssey",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "EdgeMotion", path: "Sources", sources: ["Journey.swift", "Motion.swift", "Episodes.swift"]),
        .testTarget(name: "MotionTests", dependencies: ["EdgeMotion"], path: "Tests/MotionTests"),
    ]
)
