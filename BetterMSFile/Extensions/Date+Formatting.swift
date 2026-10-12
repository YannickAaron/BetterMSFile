import Foundation

extension Date {
    var relativeFormatted: String {
        // FormatStyle rather than RelativeDateTimeFormatter, which Linux Foundation lacks.
        formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }
}

extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
