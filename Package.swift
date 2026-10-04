// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "MacWhispr", platforms: [.macOS(.v13)], products: [.executable(name: "MacWhispr", targets: ["MacWhispr"])], targets: [.executableTarget(name: "MacWhispr", linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("AVFoundation"), .linkedFramework("Carbon"), .linkedFramework("CoreAudio"), .linkedFramework("ApplicationServices")]), .testTarget(name: "MacWhisprTests", dependencies: ["MacWhispr"])])
