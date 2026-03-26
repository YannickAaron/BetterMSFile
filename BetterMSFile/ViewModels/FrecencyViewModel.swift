import Foundation
import SwiftData

@Observable
final class FrecencyViewModel {
    private var modelContext: ModelContext?

    var suggestions: [FileAccessRecord] = []

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func recordAccess(for file: UnifiedFile) {
        guard let context = modelContext else { return }

        let targetId = file.uniqueId
        let descriptor = FetchDescriptor<FileAccessRecord>(predicate: #Predicate { $0.uniqueId == targetId })

        if let existing = (try? context.fetch(descriptor))?.first {
            existing.accessCount += 1
            existing.lastAccessedAt = .now
            existing.name = file.name
        } else {
            context.insert(FileAccessRecord(from: file))
        }

        try? context.save()
        loadSuggestions()
    }

    func loadSuggestions() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<FileAccessRecord>()
        guard let records = try? context.fetch(descriptor) else { return }

        suggestions = records
            .map { (record: $0, score: frecencyScore(for: $0)) }
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map(\.record)
    }

    func pruneStaleRecords() {
        guard let context = modelContext else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
        let descriptor = FetchDescriptor<FileAccessRecord>(predicate: #Predicate {
            $0.lastAccessedAt < cutoff
        })

        guard let stale = try? context.fetch(descriptor) else { return }
        for record in stale where record.accessCount < 3 {
            context.delete(record)
        }
        try? context.save()
    }

    private func frecencyScore(for record: FileAccessRecord) -> Double {
        let hoursSinceAccess = Date.now.timeIntervalSince(record.lastAccessedAt) / 3600
        let recencyWeight: Double = switch hoursSinceAccess {
        case ..<4:   100
        case ..<24:  80
        case ..<72:  60
        case ..<168: 40
        case ..<720: 20
        default:     10
        }
        return Double(record.accessCount) * recencyWeight
    }
}
