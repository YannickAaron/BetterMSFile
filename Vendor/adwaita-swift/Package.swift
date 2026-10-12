// swift-tools-version: 6.3;(experimentalCGen)
//
//  Package.swift
//  Adwaita
//
//  Created by david-swift on 08.06.23.
//

import PackageDescription

/// The dependencies.
var dependencies: [Package.Dependency] = [
    .package(path: "../meta"), // vendored (BetterMSFile)
    .package(path: "../meta-sqlite"), // vendored (BetterMSFile)
    .package(path: "../levenshtein-transformations"), // vendored (BetterMSFile)
    .package(url: "https://github.com/CoreOffice/XMLCoder", from: "0.17.1")
]

#if os(Linux)
dependencies.append(.package(url: "https://github.com/stephencelis/CSQLite", from: "3.50.4"))
#endif

/// The Adwaita package.
let package = Package(
    name: "Adwaita",
    platforms: [.macOS(.v13), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "Adwaita",
            targets: ["Adwaita"]
        ),
        .library(
            name: "CAdw",
            targets: ["CAdw"]
        )
    ],
    traits: [.trait(name: "exposeGeneratedAppearUpdateFunctions")],
    dependencies: dependencies,
    targets: [
        .systemLibrary(
            name: "CAdwLib",
            pkgConfig: "libadwaita-1"
        ),
        .executableTarget(
            name: "WidgetGeneration",
            dependencies: [
                .product(name: "XMLCoder", package: "XMLCoder")
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .plugin(
            name: "GenerateAPINotes",
            capability: .buildTool(),
            dependencies: ["WidgetGeneration"],
            path: "Sources/PluginNotes"
        ),
        .target(
            name: "CAdw",
            dependencies: ["CAdwLib"],
            resources: [
                .process("include/apinotes.txt"),
                .process("include/module.txt"),
                .process("include/adwshim.h")
            ],
            plugins: ["GenerateAPINotes"]
        ),
        .plugin(
            name: "GenerateWidgets",
            capability: .buildTool(),
            dependencies: ["WidgetGeneration"],
            path: "Sources/Plugin"
        ),
        .target(
            name: "Adwaita",
            dependencies: [
                "CAdw",
                .product(name: "LevenshteinTransformations", package: "levenshtein-transformations"),
                .product(name: "Meta", package: "meta"),
                .product(name: "MetaSQLite", package: "meta-sqlite")
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)],
            plugins: ["GenerateWidgets"],
        ),
        .executableTarget(
            name: "Demo",
            dependencies: ["Adwaita"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        )
    ]
)
