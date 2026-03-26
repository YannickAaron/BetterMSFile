import Foundation

@MainActor @Observable
final class SidebarViewModel {
    private let siteService: SiteService

    var sites: [SharePointSite] = []
    var isLoadingSites = false
    var sitesErrorMessage: String?

    init(siteService: SiteService) {
        self.siteService = siteService
    }

    func loadSites() async {
        isLoadingSites = true
        sitesErrorMessage = nil
        do {
            sites = try await siteService.fetchAllAccessibleSites()
        } catch {
            sitesErrorMessage = error.localizedDescription
            print("Failed to load sites: \(error.localizedDescription)")
        }
        isLoadingSites = false
    }
}
