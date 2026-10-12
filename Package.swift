// swift-tools-version: 6.3
// Linux build of BetterMSFile. The macOS app is built with BetterMSFile.xcodeproj.
// Shared code is compiled in place from BetterMSFile/; Linux-only replacements and the GNOME UI live in Linux/Sources.
// (SwiftPM warns about the Mac-only files under BetterMSFile/ it doesn't compile; that's expected.)
import PackageDescription

let package = Package(
    name: "BetterMSFile",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "bettermsfile", targets: ["bettermsfile"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0"),
        // GNOME UI with a SwiftUI-like API. Needs GTK >= 4.20 / libadwaita >= 1.8 (Ubuntu 26.04, Fedora 43, Flatpak GNOME 49+).
        // Vendored (see Vendor/README.md): upstream lives on Codeberg, whose outages broke builds.
        .package(path: "Vendor/adwaita-swift"),
    ],
    targets: [
        .executableTarget(
            name: "bettermsfile",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Adwaita", package: "adwaita-swift"),
            ],
            path: ".",
            sources: [
                "BetterMSFile/Config.swift",
                "BetterMSFile/Networking",
                "BetterMSFile/Services/FileService.swift",
                "BetterMSFile/Services/SearchService.swift",
                "BetterMSFile/Services/SiteService.swift",
                "BetterMSFile/Models/FileSource.swift",
                "BetterMSFile/Models/SearchScope.swift",
                "BetterMSFile/Extensions/URL+Unique.swift",
                "BetterMSFile/MCP/MCPServer.swift",
                "BetterMSFile/App/AppState.swift",
                "BetterMSFile/ViewModels/SidebarViewModel.swift",
                "BetterMSFile/ViewModels/SearchViewModel.swift",
                "BetterMSFile/Services/UpdateService.swift",
                "BetterMSFile/Extensions/Date+Formatting.swift",
                "Linux/Sources",
            ],
            // Match the Xcode target's settings so shared files compile the same way.
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
