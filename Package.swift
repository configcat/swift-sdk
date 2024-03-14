// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ConfigCat",
    platforms: [
        .iOS(.v12),
        .watchOS(.v4),
        .tvOS(.v12),
        .macOS(.v10_13)
    ],
    products: [
        .library(name: "ConfigCat", targets: ["ConfigCat"])
    ],
    targets: [
        .target(name: "Version",
                exclude: ["LICENSE" , "version.txt"]),
        .target(name: "ConfigCat",
                dependencies: ["Version"],
                exclude: ["Resources/ConfigCat.h", "Resources/Info.plist"],
                swiftSettings: [
                    .define("DEBUG", .when(configuration: .debug))
                ]),
        .testTarget(name: "ConfigCatTests",
                    dependencies: ["ConfigCat"],
                    exclude: ["Resources/Info.plist"],
                    resources: [.process("Resources")]
        )
        
    ],
    swiftLanguageVersions: [.v5]
)
