// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Violet", platforms: [.macOS(.v14)], products: [.executable(name: "Violet", targets: ["Violet"])], targets: [.target(name: "VioletCore"), .executableTarget(name: "Violet", dependencies: ["VioletCore"]), .testTarget(name: "VioletCoreTests", dependencies: ["VioletCore"])], swiftLanguageModes: [.v5])
