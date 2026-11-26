// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "bull_reporting",
    platforms: [.iOS("15.0")],
    products: [.library(name: "bull-reporting", targets: ["bull_reporting"])],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Match the Cocoa SDK bundled by sentry_flutter.
        .package(url: "https://github.com/getsentry/sentry-apple-binaries", exact: "9.36.0")
    ],
    targets: [
        .target(
            name: "bull_reporting",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "Sentry-Static", package: "sentry-apple-binaries")
            ]
        )
    ]
)
