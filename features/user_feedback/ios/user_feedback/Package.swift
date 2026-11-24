// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "user_feedback",
    platforms: [.iOS("15.0")],
    products: [.library(name: "user-feedback", targets: ["user_feedback"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .target(
            name: "user_feedback",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")]
        )
    ]
)
