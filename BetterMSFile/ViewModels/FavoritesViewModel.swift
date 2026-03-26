import Foundation
import SwiftData

@MainActor @Observable
final class FavoritesViewModel {
    private var modelContext: ModelContext?

    var favorites: [FavoriteItem] = []

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func loadFavorites() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<FavoriteItem>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        favorites = (try? context.fetch(descriptor)) ?? []
    }

    func toggleFavorite(for file: UnifiedFile) {
        guard let context = modelContext else { return }

        let targetId = file.uniqueId
        let descriptor = FetchDescriptor<FavoriteItem>(predicate: #Predicate { $0.uniqueId == targetId })

        if let existing = (try? context.fetch(descriptor))?.first {
            context.delete(existing)
        } else {
            context.insert(FavoriteItem(from: file))
        }

        try? context.save()
        loadFavorites()
    }

    func isFavorite(_ file: UnifiedFile) -> Bool {
        favorites.contains { $0.uniqueId == file.uniqueId }
    }
}
