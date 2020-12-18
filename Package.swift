// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ConfigCat",
    platforms: [
        .iOS(.v10),
        .watchOS(.v3),
        .tvOS(.v10),
        .macOS(.v10_12)
    ],
    products: [
        .library(name: "ConfigCat", type: .dynamic, targets: ["ConfigCat"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Version",
                dependencies: [],
                exclude: ["LICENSE" , "version.txt"],
                linkerSettings: [
                    .linkedFramework("Foundation"),
                ]),
        .target(name: "ConfigCat",
                dependencies: ["Version"],
                exclude: ["Version/LICENSE" , "Version/version.txt"],
                swiftSettings: [
                    .define("DEBUG", .when(configuration: .debug))
                ],
                linkerSettings: [
                    .linkedFramework("Foundation"),
                ]),
        .testTarget(name: "ConfigCatTests",
                    dependencies: ["ConfigCat"],
                    resources: [
                        .process("Resources")]
                    )

    ],
    swiftLanguageVersions: [.v4]
)
