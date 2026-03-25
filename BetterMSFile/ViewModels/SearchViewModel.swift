import Foundation

@Observable
final class SearchViewModel {
    private let searchService: SearchService

    var query: String = "" {
        didSet { debouncedSearch() }
    }
    var results: [UnifiedFile] = []
    var isSearching = false
    var errorMessage: String?

    // Filters
    var fileTypeFilter: String?
    var modifiedAfterFilter: Date?
    var authorFilter: String?

    private var searchTask: Task<Void, Never>?
    private let debounceInterval: Duration = .milliseconds(300)

    init(searchService: SearchService) {
        self.searchService = searchService
    }

    func reset() {
        query = ""
        results = []
        errorMessage = nil
        searchTask?.cancel()
    }

    func searchNow() {
        searchTask?.cancel()
        searchTask = Task { await performSearch() }
    }

    func clearFilters() {
        fileTypeFilter = nil
        modifiedAfterFilter = nil
        authorFilter = nil
        if !query.isEmpty { searchNow() }
    }

    private func debouncedSearch() {
        searchTask?.cancel()

        guard !query.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    private func performSearch() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        errorMessage = nil

        let filters = SearchFilters(
            fileType: fileTypeFilter,
            modifiedAfter: modifiedAfterFilter,
            author: authorFilter
        )

        do {
            results = try await searchService.search(query: query, filters: filters)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }

        isSearching = false
    }
}
