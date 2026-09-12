import Foundation
internal import Combine

@MainActor
final class RuntimeConfigService: ObservableObject {
    static let shared = RuntimeConfigService()

    @Published private(set) var settings: RuntimeSettings = .default
    @Published private(set) var visibleNotice: SystemNotice?

    private var lastRefresh: Date?
    private var dismissedNoticeIDs: Set<Int> = []
    private let minimumRefreshInterval: TimeInterval = 120

    private init() {}

    func refresh(force: Bool = false) async {
        if !force,
           let lastRefresh,
           Date().timeIntervalSince(lastRefresh) < minimumRefreshInterval {
            return
        }

        lastRefresh = Date()

        do {
            let config = try await APIService.shared.fetchPublicConfig()
            settings = config.settings
        } catch {
            print("[RuntimeConfigService] config refresh failed: \(error)")
        }

        do {
            let response = try await APIService.shared.fetchSystemNotice()
            if response.isActive,
               let notice = response.notice,
               !dismissedNoticeIDs.contains(notice.id) {
                visibleNotice = notice
            } else if visibleNotice?.dismissible != false {
                visibleNotice = nil
            }
        } catch {
            print("[RuntimeConfigService] notice refresh failed: \(error)")
        }
    }

    func dismiss(_ notice: SystemNotice) {
        guard notice.dismissible else { return }
        dismissedNoticeIDs.insert(notice.id)
        if visibleNotice?.id == notice.id {
            visibleNotice = nil
        }
    }
}
