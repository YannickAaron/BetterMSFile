import Foundation

@Observable
final class SidebarViewModel {
    private let siteService: SiteService

    var sites: [SharePointSite] = []
    var isLoadingSites = false

    init(siteService: SiteService) {
        self.siteService = siteService
    }

    func loadSites() async {
        isLoadingSites = true
        do {
            sites = try await siteService.fetchAllAccessibleSites()
        } catch {
            print("Failed to load sites: \(error.localizedDescription)")
        }
        isLoadingSites = false
    }
}
