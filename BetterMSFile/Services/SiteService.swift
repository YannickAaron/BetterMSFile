import Foundation

struct SharePointSite: Identifiable, Hashable {
    let id: String
    let displayName: String
    let drives: [SharePointDrive]
    let groupId: String?  // Non-nil if this site backs a Team
}

struct TeamChannel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let driveId: String
    let folderId: String
    let siteId: String
    let teamName: String
}

struct SharePointDrive: Identifiable, Hashable {
    let id: String
    let name: String
    let siteId: String
    let siteName: String
}

final class SiteService {
    private let client: GraphClient

    init(client: GraphClient) {
        self.client = client
    }

    /// Discover all accessible SharePoint sites: joined Teams + followed sites.
    func fetchAllAccessibleSites() async throws -> [SharePointSite] {
        // Fetch Teams and followed sites in parallel
        async let teamsResult = fetchJoinedTeamSites()
        async let followedResult = fetchFollowedSitesQuietly()

        let teamSites = await teamsResult
        let followedSites = await followedResult

        // Merge, deduplicating by site ID
        var seen = Set<String>()
        var result: [SharePointSite] = []

        for site in teamSites + followedSites {
            if seen.insert(site.id).inserted {
                result.append(site)
            }
        }

        result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return result
    }

    /// Fetch sites from joined Teams (each Team has a SharePoint site).
    private func fetchJoinedTeamSites() async -> [SharePointSite] {
        do {
            let teams: [GraphTeam] = try await client.getAllPages(GraphEndpoints.joinedTeams)
            var sites: [SharePointSite] = []

            for team in teams {
                let teamName = team.displayName ?? "Unknown Team"
                do {
                    // Get the Team's underlying SharePoint site
                    let site: GraphSite = try await client.getSingle(GraphEndpoints.groupSiteRoot(groupId: team.id))
                    // Get drives for that site
                    let drives: [GraphDrive] = try await client.getAllPages(GraphEndpoints.siteDrives(siteId: site.id))
                    let spDrives = drives
                        .filter { $0.driveType == "documentLibrary" }
                        .map { SharePointDrive(id: $0.id, name: $0.name ?? "Documents", siteId: site.id, siteName: teamName) }

                    if !spDrives.isEmpty {
                        sites.append(SharePointSite(id: site.id, displayName: teamName, drives: spDrives, groupId: team.id))
                    }
                } catch {
                    print("Skipping team \(teamName): \(error.localizedDescription)")
                }
            }

            return sites
        } catch {
            print("Failed to fetch joined teams: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch explicitly followed SharePoint sites (non-throwing).
    private func fetchFollowedSitesQuietly() async -> [SharePointSite] {
        do {
            return try await fetchFollowedSites()
        } catch {
            print("Failed to fetch followed sites: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch channels for a Team, returning folder info for each channel.
    func fetchTeamChannels(teamId: String, teamName: String, siteId: String) async throws -> [TeamChannel] {
        let channels: [GraphChannel] = try await client.getAllPages(GraphEndpoints.teamChannels(teamId: teamId))
        var result: [TeamChannel] = []

        for channel in channels {
            let name = channel.displayName ?? "Unknown Channel"
            do {
                let filesFolder: GraphChannelFilesFolder = try await client.getSingle(
                    GraphEndpoints.channelFilesFolder(teamId: teamId, channelId: channel.id)
                )
                let driveId = filesFolder.parentReference?.driveId ?? ""
                result.append(TeamChannel(
                    id: channel.id,
                    displayName: name,
                    driveId: driveId,
                    folderId: filesFolder.id,
                    siteId: siteId,
                    teamName: teamName
                ))
            } catch {
                // Private channels may fail if user lacks access to their files
                print("Skipping channel \(name): \(error.localizedDescription)")
            }
        }

        return result
    }

    /// Discover SharePoint sites the user follows, with their document libraries.
    func fetchFollowedSites() async throws -> [SharePointSite] {
        let sites: [GraphSite] = try await client.getAllPages(GraphEndpoints.followedSites)
        var result: [SharePointSite] = []

        for site in sites {
            let siteName = site.displayName ?? site.name ?? "Unknown Site"
            do {
                let drives: [GraphDrive] = try await client.getAllPages(
                    GraphEndpoints.siteDrives(siteId: site.id)
                )
                let spDrives = drives
                    .filter { $0.driveType == "documentLibrary" }
                    .map { SharePointDrive(id: $0.id, name: $0.name ?? "Documents", siteId: site.id, siteName: siteName) }

                if !spDrives.isEmpty {
                    result.append(SharePointSite(id: site.id, displayName: siteName, drives: spDrives, groupId: nil))
                }
            } catch {
                print("Skipping site \(siteName): \(error.localizedDescription)")
            }
        }

        return result
    }
}
