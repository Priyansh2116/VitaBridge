// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "VitaBridge", platforms: [.macOS(.v14)], products: [
    .library(name: "VitaProtocol", targets: ["VitaProtocol"]),
    .executable(name: "VitaBridge", targets: ["VitaBridgeApp"])
], targets: [
    .target(name: "VitaProtocol"),
    .target(name: "ControllerEngine", dependencies: ["VitaProtocol"]),
    .target(name: "VitaTransport", dependencies: ["VitaProtocol"]),
    .target(name: "OutputBackends", dependencies: ["VitaProtocol", "ControllerEngine"]),
    .executableTarget(name: "VitaBridgeApp", dependencies: ["VitaProtocol", "VitaTransport", "ControllerEngine", "OutputBackends"], exclude: ["Assets.xcassets"]),
    .testTarget(name: "VitaBridgeTests", dependencies: ["VitaProtocol", "ControllerEngine", "VitaTransport", "OutputBackends"])
])
