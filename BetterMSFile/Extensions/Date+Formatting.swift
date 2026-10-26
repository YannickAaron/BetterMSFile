import Foundation

extension Date {
    var relativeFormatted: String {
        // FormatStyle rather than RelativeDateTimeFormatter, which Linux Foundation lacks.
        formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }
}

private let fractionalSecondsFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let wholeSecondsFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

extension Date {
    /// Parses a Microsoft Graph timestamp. Graph sends some with fractional seconds and some
    /// without (SharePoint items come as `2026-09-30T14:29:58Z`), and each formatter rejects the other form.
    init?(graphTimestamp string: String) {
        guard let date = fractionalSecondsFormatter.date(from: string) ?? wholeSecondsFormatter.date(from: string) else { return nil }
        self = date
    }
}

extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
