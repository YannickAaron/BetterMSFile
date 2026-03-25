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
        // Must have a valid HTTPS webURL to open
        return !file.webURL.isEmpty && file.webURL.hasPrefix("https://")
    }

    /// Constructs a direct SharePoint/OneDrive file URL from Graph API metadata.
    ///
    /// The `webUrl` from Graph is a viewer URL (`_layouts/15/Doc.aspx?...`) which
    /// Office apps can't open. We need the direct file URL like:
    /// `https://tenant.sharepoint.com/sites/MySite/Shared Documents/file.docx`
    ///
    /// IMPORTANT: Graph API returns already-percent-encoded URLs and paths.
    /// Only the raw `file.name` needs encoding. Never re-encode existing URLs.
    static func directFileURL(file: UnifiedFile) -> String? {
        print("MSAppIcon.directFileURL inputs:")
        print("  webURL: \(file.webURL)")
        print("  parentPath: '\(file.parentPath)'")
        print("  driveWebURL: '\(file.driveWebURL ?? "nil")'")
        print("  fileName: \(file.name)")

        // Encode ONLY the filename (spaces, parens, etc.) — everything else from Graph is pre-encoded
        let encodedName = file.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file.name

        // Strategy 1 (BEST): Use driveWebURL — the drive's document library root URL
        // e.g., "https://tenant.sharepoint.com/sites/MySite/Shared%20Documents"
        // driveWebURL is already a complete, valid URL from Graph API — do NOT re-encode
        if let driveWebURL = file.driveWebURL, !driveWebURL.isEmpty {
            // Extract relative folder path from parentPath (after "root:")
            // This path is already percent-encoded from Graph API
            let relativePath: String
            if let rootRange = file.parentPath.range(of: "root:") {
                relativePath = String(file.parentPath[rootRange.upperBound...])
            } else {
                relativePath = ""
            }

            // Assemble — all parts are already encoded except filename which we encoded above
            let result = "\(driveWebURL)\(relativePath)/\(encodedName)"
            print("  SUCCESS (from driveWebURL): \(result)")
            return result
        }

        // Strategy 2: Parse webURL and parentPath to reconstruct the direct URL
        guard let url = URL(string: file.webURL),
              let host = url.host else {
            print("  FAILED: Could not parse webURL")
            return nil
        }

        if let rootRange = file.parentPath.range(of: "root:") {
            let relativeFolderPath = String(file.parentPath[rootRange.upperBound...])

            let sitePath: String
            if let layoutsRange = url.path.range(of: "/_layouts/") {
                sitePath = String(url.path[..<layoutsRange.lowerBound])
            } else {
                return file.webURL
            }

            // When relativeFolderPath is empty (file at drive root), we need the library name
            let isPersonal = host.contains("-my.sharepoint.com")
            let libraryGuess = isPersonal ? "/Documents" : "/Shared%20Documents"
            let needsLibrary = relativeFolderPath.isEmpty || relativeFolderPath == "/"

            // sitePath and relativeFolderPath are already encoded from Graph
            let result: String
            if needsLibrary {
                result = "https://\(host)\(sitePath)\(libraryGuess)/\(encodedName)"
            } else {
                result = "https://\(host)\(sitePath)\(relativeFolderPath)/\(encodedName)"
            }

            print("  SUCCESS (from parentPath): \(result)")
            return result
        }

        // Strategy 3: Parse file= query param from Doc.aspx URL
        // The file= param is already decoded by URLComponents, so we need to encode it
        if let components = URLComponents(string: file.webURL),
           let fileParam = components.queryItems?.first(where: { $0.name == "file" })?.value {

            let sitePath: String
            if let layoutsRange = url.path.range(of: "/_layouts/") {
                sitePath = String(url.path[..<layoutsRange.lowerBound])
            } else {
                print("  FAILED: No _layouts in path")
                return nil
            }

            let isPersonal = host.contains("-my.sharepoint.com")
            let libraryPath = isPersonal ? "/Documents" : "/Shared%20Documents"
            let encodedFileParam = fileParam.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileParam

            let result = "https://\(host)\(sitePath)\(libraryPath)/\(encodedFileParam)"
            print("  SUCCESS (from file= param): \(result)")
            return result
        }

        print("  FAILED: All strategies exhausted")
        return nil
    }

    /// Open a file in the native Office app on macOS.
    /// Uses NSWorkspace to pass the direct file URL to the specific Office application.
    @discardableResult
    static func openInNativeApp(file: UnifiedFile) -> Bool {
        guard let msIcon = forFile(mimeType: file.mimeType, fileName: file.name) else { return false }

        guard msIcon.isInstalled else {
            print("MSAppIcon: \(msIcon.appName) is not installed")
            return false
        }

        guard !file.webURL.isEmpty, file.webURL.hasPrefix("https://") else {
            print("MSAppIcon: Invalid webURL: \(file.webURL)")
            return false
        }

        // Construct a direct file URL and open with the specific Office app
        if let directURLString = directFileURL(file: file),
           let directURL = URL(string: directURLString),
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: msIcon.bundleIdentifier) {

            print("MSAppIcon: Opening \(directURL) with \(msIcon.appName)")
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([directURL], withApplicationAt: appURL, configuration: config)
            return true
        }

        // Fallback: open in browser
        print("MSAppIcon: Falling back to browser for \(file.name)")
        if let url = URL(string: file.webURL) {
            NSWorkspace.shared.open(url)
        }
        return false
    }
}
