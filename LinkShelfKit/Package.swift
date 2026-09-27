// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LinkShelfKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "LinkShelfDomain", targets: ["LinkShelfDomain"]),
        .library(name: "LinkShelfPersistence", targets: ["LinkShelfPersistence"])
    ],
    targets: [
        .target(name: "LinkShelfDomain"),
        .target(name: "LinkShelfPersistence", dependencies: ["LinkShelfDomain"]),
        .testTarget(name: "LinkShelfDomainTests", dependencies: ["LinkShelfDomain"]),
        .testTarget(name: "LinkShelfPersistenceTests", dependencies: ["LinkShelfPersistence"])
    ]
)
