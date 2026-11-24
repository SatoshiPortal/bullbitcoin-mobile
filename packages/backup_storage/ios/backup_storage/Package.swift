// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "backup_storage",
    platforms: [.iOS("15.0")],
    products: [.library(name: "backup-storage", targets: ["backup_storage"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .target(
            name: "backup_storage",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")]
        )
    ]
)
