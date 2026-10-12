// swift-tools-version: 6.3
//
//  Package.swift
//  meta-sqlite
//
//  Created by david-swift on 04.10.24.
//

import PackageDescription

/// The dependencies.
var dependencies: [Package.Dependency] = [
    .package(path: "../meta") // vendored (BetterMSFile)
]

#if os(Linux)
dependencies += [
    .package(url: "https://github.com/stephencelis/CSQLite", from: "3.50.4"),
    .package(
        url: "https://github.com/stephencelis/SQLite.swift",
        from: "0.15.3",
        traits: [.defaults, "SQLiteSwiftCSQLite"]
    )
]
#else
dependencies.append(.package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"))
#endif

/// The meta-sqlite package is part of the Aparoksha project.
let package = Package(
    name: "meta-sqlite",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "MetaSQLite",
            targets: ["MetaSQLite"]
        )
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "MetaSQLite",
            dependencies: [
                .product(name: "Meta", package: "meta"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .executableTarget(
            name: "Tests",
            dependencies: ["MetaSQLite"],
            path: "Tests"
        )
    ]
)
