import SwiftUI
import AppKit

/// Provides real Microsoft Office app icons from locally installed apps,
/// with SF Symbol fallbacks when apps aren't installed.
enum MSAppIcon {
    case word
    case excel
    case powerPoint
    case oneDrive
    case teams
    case outlook
    case microsoft

    /// Bundle identifiers for Microsoft apps
    var bundleIdentifier: String {
        switch self {
        case .word: "com.microsoft.Word"
        case .excel: "com.microsoft.Excel"
        case .powerPoint: "com.microsoft.Powerpoint"
        case .oneDrive: "com.microsoft.OneDrive"
        case .teams: "com.microsoft.teams2"
        case .outlook: "com.microsoft.Outlook"
        case .microsoft: "com.microsoft.edgemac" // Edge as generic MS icon fallback
        }
    }

    /// SF Symbol fallback when the app isn't installed
    private var fallbackSymbol: String {
        switch self {
        case .word: "doc.text.fill"
        case .excel: "tablecells.fill"
        case .powerPoint: "rectangle.stack.fill"
        case .oneDrive: "cloud.fill"
        case .teams: "person.3.fill"
        case .outlook: "envelope.fill"
        case .microsoft: "circle.grid.2x2.fill"
        }
    }

    /// Brand color for the fallback symbol
    private var fallbackColor: Color {
        switch self {
        case .word: Color(red: 0.16, green: 0.31, blue: 0.71)   // Word blue
        case .excel: Color(red: 0.13, green: 0.47, blue: 0.26)   // Excel green
        case .powerPoint: Color(red: 0.78, green: 0.25, blue: 0.15) // PowerPoint orange-red
        case .oneDrive: Color(red: 0.0, green: 0.47, blue: 0.84)  // OneDrive blue
        case .teams: Color(red: 0.29, green: 0.21, blue: 0.56)    // Teams purple
        case .outlook: Color(red: 0.0, green: 0.47, blue: 0.84)   // Outlook blue
        case .microsoft: Color(red: 0.95, green: 0.52, blue: 0.0) // Microsoft orange
        }
    }

    /// Get the NSImage for this app (real icon or nil)
    var nsImage: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// SwiftUI view that shows the real app icon or a styled fallback
    func icon(size: CGFloat = 16) -> some View {
        Group {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.75))
                    .foregroundStyle(fallbackColor)
                    .frame(width: size, height: size)
            }
        }
    }

    /// The Office URI scheme for this app type (e.g., "ms-word")
    var uriScheme: String? {
        switch self {
        case .word: "ms-word"
        case .excel: "ms-excel"
        case .powerPoint: "ms-powerpoint"
        default: nil
        }
    }

    /// Whether the native Office app is installed on this Mac
    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    /// Display name for the app
    var appName: String {
        switch self {
        case .word: "Word"
        case .excel: "Excel"
        case .powerPoint: "PowerPoint"
        case .oneDrive: "OneDrive"
        case .teams: "Teams"
        case .outlook: "Outlook"
        case .microsoft: "Microsoft"
        }
    }

    /// Detect the right icon for a file based on mime type and extension.
    /// Extension is checked first (most reliable), then MIME type.
    /// MIME matching uses specific substrings to avoid false positives
    /// (e.g., "officedocument" appears in all Office MIME types).
    static func forFile(mimeType: String?, fileName: String) -> MSAppIcon? {
        let name = fileName.lowercased()

        // 1. Check file extension first — most reliable
        if name.hasSuffix(".pptx") || name.hasSuffix(".ppt") || name.hasSuffix(".ppsx") || name.hasSuffix(".potx") {
            return .powerPoint
        } else if name.hasSuffix(".xlsx") || name.hasSuffix(".xls") || name.hasSuffix(".xlsm") || name.hasSuffix(".csv") {
            return .excel
        } else if name.hasSuffix(".docx") || name.hasSuffix(".doc") || name.hasSuffix(".dotx") {
            return .word
        }

        // 2. Fall back to MIME type with specific substrings
        // All Office MIME types contain "officedocument", so we must check
        // for "presentationml", "spreadsheetml", "wordprocessingml" specifically.
        let mime = mimeType ?? ""
        if mime.contains("presentationml") || mime.contains("powerpoint") {
            return .powerPoint
        } else if mime.contains("spreadsheetml") || mime.contains("excel") || mime.contains("spreadsheet") {
            return .excel
        } else if mime.contains("wordprocessingml") || mime.contains("msword") || mime.contains("ms-word") {
            return .word
        }
        return nil
    }

    /// Whether the native Office app is installed and available for this file
    static func isNativeAppAvailable(for file: UnifiedFile) -> Bool {
        guard let msIcon = forFile(mimeType: file.mimeType, fileName: file.name) else { return false }
        guard msIcon.isInstalled else { return false }
        // Must have a valid HTTPS URL to open (webDavURL or webURL)
        let url = file.webDavURL ?? file.webURL
        return !url.isEmpty && url.hasPrefix("https://")
    }

    /// Open a file in the native Office app on macOS.
    ///
    /// Uses `NSWorkspace` to directly open the `webDavUrl` (from Graph API) with the
    /// specific Office application. No URI scheme pipes needed — just a direct HTTPS URL
    /// passed to the correct app via its bundle identifier.
    @discardableResult
    static func openInNativeApp(file: UnifiedFile) -> Bool {
        guard let msIcon = forFile(mimeType: file.mimeType, fileName: file.name) else { return false }

        guard msIcon.isInstalled else {
            print("MSAppIcon: \(msIcon.appName) is not installed")
            return false
        }

        // Use webDavUrl (direct file URL from Graph API) — this is the reliable path
        let fileURLString = file.webDavURL ?? file.webURL

        guard !fileURLString.isEmpty, fileURLString.hasPrefix("https://"),
              let fileURL = URL(string: fileURLString),
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: msIcon.bundleIdentifier) else {
            print("MSAppIcon: No valid URL for \(file.name)")
            return false
        }

        print("MSAppIcon: Opening \(file.name) in \(msIcon.appName)")
        print("  URL: \(fileURLString)")

        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: config)
        return true
    }
}
