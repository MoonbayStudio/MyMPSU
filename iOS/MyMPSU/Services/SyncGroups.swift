import Foundation

enum SyncGroups {
    static func refresh() async {
        await APIService.shared.refreshInstitutesWithGroupsCache()
    }
}
