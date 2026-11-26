// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "onion",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "onion", targets: ["onion"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Same pin as the podspec. The xcframework is committed in the tag and
        // Package.resolved records the resolved revision.
        .package(url: "https://github.com/tladesignz/IPtProxy.git", exact: "5.6.0"),
    ],
    targets: [
        .target(
            name: "onion",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "IPtProxy", package: "IPtProxy"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ],
            cSettings: [
                .headerSearchPath("include/onion")
            ],
            linkerSettings: [
                // IPtProxy's Go runtime needs libresolv (res_9_ninit, ...).
                // Its podspec declares `s.libraries = 'resolv'`, but a SwiftPM
                // binaryTarget cannot carry linker settings, so link it here.
                .linkedLibrary("resolv")
            ]
        )
    ]
)
