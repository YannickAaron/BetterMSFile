import Foundation

@MainActor @Observable
final class SearchViewModel {
    private let searchService: SearchService

    var query: String = "" {
        didSet { debouncedSearch() }
    }
    var results: [UnifiedFile] = []
    var isSearching = false
    var isLoadingMore = false
    var hasMoreResults = false
    var totalResults: Int?
    var errorMessage: String?

    // Filters
    var fileTypeFilter: String?
    var modifiedAfterFilter: Date?
    var authorFilter: String?
    var scope: SearchScope = .all {
        didSet {
            if query.count >= minQueryLength { searchNow() }
        }
    }

    /// Date filter presets for the UI
    var dateFilterPreset: DateFilterPreset = .anyTime {
        didSet {
            modifiedAfterFilter = dateFilterPreset.date
            if query.count >= minQueryLength { searchNow() }
        }
    }

    private var searchTask: Task<Void, Never>?
    private var currentOffset = 0
    private let pageSize = 25
    private let debounceInterval: Duration = .milliseconds(500)
    private let minQueryLength = 2

    init(searchService: SearchService) {
        self.searchService = searchService
    }

    func reset() {
        query = ""
        results = []
        errorMessage = nil
        hasMoreResults = false
        totalResults = nil
        currentOffset = 0
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
        dateFilterPreset = .anyTime
        scope = .all
        if query.count >= minQueryLength { searchNow() }
    }

    func loadMore() async {
        guard hasMoreResults, !isLoadingMore else { return }

        isLoadingMore = true
        let nextOffset = currentOffset + pageSize

        let filters = SearchFilters(
            fileType: fileTypeFilter,
            modifiedAfter: modifiedAfterFilter,
            author: authorFilter
        )

        do {
            let result = try await searchService.search(
                query: query.trimmingCharacters(in: .whitespaces),
                filters: filters,
                scope: scope,
                from: nextOffset
            )
            results.append(contentsOf: result.files)
            hasMoreResults = result.moreAvailable
            currentOffset = nextOffset
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    private func debouncedSearch() {
        searchTask?.cancel()

        guard query.count >= minQueryLength else {
            results = []
            errorMessage = nil
            hasMoreResults = false
            totalResults = nil
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    private func performSearch() async {
        let currentQuery = query.trimmingCharacters(in: .whitespaces)
        guard currentQuery.count >= minQueryLength else { return }

        isSearching = true
        errorMessage = nil
        currentOffset = 0

        let filters = SearchFilters(
            fileType: fileTypeFilter,
            modifiedAfter: modifiedAfterFilter,
            author: authorFilter
        )

        do {
            let result = try await searchService.search(query: currentQuery, filters: filters, scope: scope)
            guard !Task.isCancelled else { return }
            results = result.files
            hasMoreResults = result.moreAvailable
            totalResults = result.total
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }
}

// MARK: - Date Filter Presets

enum DateFilterPreset: String, CaseIterable {
    case anyTime = "Any Time"
    case pastWeek = "Past Week"
    case pastMonth = "Past Month"
    case past3Months = "Past 3 Months"
    case pastYear = "Past Year"

    var date: Date? {
        let calendar = Calendar.current
        switch self {
        case .anyTime: return nil
        case .pastWeek: return calendar.date(byAdding: .day, value: -7, to: .now)
        case .pastMonth: return calendar.date(byAdding: .month, value: -1, to: .now)
        case .past3Months: return calendar.date(byAdding: .month, value: -3, to: .now)
        case .pastYear: return calendar.date(byAdding: .year, value: -1, to: .now)
        }
    }
}
