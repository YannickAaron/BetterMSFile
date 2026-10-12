// swift-tools-version: 6.2
//
//  Package.swift
//  Meta
//
//  Created by david-swift on 26.05.24.
//

import PackageDescription

/// The Meta package is the foundation of the Aparoksha project.
let package = Package(
    name: "Meta",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Meta",
            targets: ["Meta"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "Meta",
            path: "Sources"
        ),
        .target(
            name: "SampleBackends",
            dependencies: ["Meta"],
            path: "Tests/SampleBackends",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .executableTarget(
            name: "DemoApp",
            dependencies: ["SampleBackends"],
            path: "Tests/DemoApp",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        )
    ]
)
