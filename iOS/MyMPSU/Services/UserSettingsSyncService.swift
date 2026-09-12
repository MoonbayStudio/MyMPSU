import Foundation

enum SelectedGroupUpdateResult {
    case applied
    case changeRequestCreated
    case authenticationRequired
    case failed
}

enum UserSettingsSyncService {
    static let didUpdateSelectedGroup = Notification.Name("MyMPSUDidUpdateSelectedGroup")
    private static let appGroupID = "group.mympsu.shared"
    private static let selectedGroupIdKey = "selectedGroupId"
    private static let selectedGroupNameKey = "selectedGroupName"
    private static let scheduleGroupIdKey = "scheduleGroupId"
    private static let scheduleGroupNameKey = "scheduleGroupName"
    private static let offlineScheduleEnabledKey = "offlineScheduleEnabled"
    private static let offlineScheduleWeeksKey = "offlineScheduleWeeks"
    private static let liveActivityEnabledKey = "liveActivityEnabled"

    static func apply(_ settings: UserSettings) {
        let cacheWeeks = min(max(settings.scheduleCacheWeeks, 0), 4)
        let offlineEnabled = cacheWeeks > 0
        UserDefaults.standard.set(offlineEnabled, forKey: offlineScheduleEnabledKey)
        UserDefaults.standard.set(max(cacheWeeks, 1), forKey: offlineScheduleWeeksKey)
        UserDefaults.standard.set(settings.liveActivityEnabled, forKey: liveActivityEnabledKey)
        UserDefaults(suiteName: appGroupID)?.set(offlineEnabled, forKey: offlineScheduleEnabledKey)
        UserDefaults(suiteName: appGroupID)?.set(max(cacheWeeks, 1), forKey: offlineScheduleWeeksKey)
        UserDefaults(suiteName: appGroupID)?.set(settings.liveActivityEnabled, forKey: liveActivityEnabledKey)

        guard let groupId = settings.selectedGroupId else { return }
        let groupIdString = String(groupId)
        let groupName = settings.selectedGroupName ?? groupIdString
        UserDefaults.standard.set(groupIdString, forKey: selectedGroupIdKey)
        UserDefaults.standard.set(groupName, forKey: selectedGroupNameKey)
        UserDefaults(suiteName: appGroupID)?.set(groupIdString, forKey: selectedGroupIdKey)
        UserDefaults(suiteName: appGroupID)?.set(groupName, forKey: selectedGroupNameKey)
        if UserDefaults.standard.string(forKey: scheduleGroupIdKey)?.mympsuTrimmed.isEmpty != false {
            UserDefaults.standard.set(groupIdString, forKey: scheduleGroupIdKey)
            UserDefaults.standard.set(groupName, forKey: scheduleGroupNameKey)
            UserDefaults(suiteName: appGroupID)?.set(groupIdString, forKey: scheduleGroupIdKey)
            UserDefaults(suiteName: appGroupID)?.set(groupName, forKey: scheduleGroupNameKey)
        }

        NotificationCenter.default.post(
            name: didUpdateSelectedGroup,
            object: nil,
            userInfo: [
                "groupId": groupIdString,
                "groupName": groupName
            ]
        )
    }

    static func syncRemoteSettingsIfAuthenticated() async {
        guard AuthSessionManager.shared.isAuthenticated else { return }
        do {
            let settings = try await APIService.shared.fetchSettings()
            if settings.selectedGroupId == nil,
               let localGroup = localSelectedGroup {
                let syncedSettings = try await APIService.shared.updateSettings(
                    selectedGroupId: localGroup.id,
                    selectedGroupName: localGroup.name,
                    scheduleCacheWeeks: localScheduleCacheWeeks,
                    liveActivityEnabled: localLiveActivityEnabled
                )
                await MainActor.run {
                    apply(syncedSettings)
                }
                return
            }
            await MainActor.run {
                apply(settings)
            }
        } catch {
            print("[UserSettingsSyncService] settings sync failed: \(error)")
            if case APIServiceError.httpStatus(401) = error {
                await MainActor.run {
                    AuthSessionManager.shared.signOut()
                }
            }
        }
    }

    @discardableResult
    static func pushLocalSettingsIfAuthenticated() async -> Bool {
        guard AuthSessionManager.shared.isAuthenticated, let localGroup = localSelectedGroup else {
            return false
        }

        do {
            let settings = try await APIService.shared.fetchSettings()
            if let remoteGroupId = settings.selectedGroupId, remoteGroupId != localGroup.id {
                await MainActor.run {
                    apply(settings)
                }
                return false
            }

            let syncedSettings = try await APIService.shared.updateSettings(
                selectedGroupId: localGroup.id,
                selectedGroupName: localGroup.name,
                scheduleCacheWeeks: localScheduleCacheWeeks,
                liveActivityEnabled: localLiveActivityEnabled
            )
            await MainActor.run {
                apply(syncedSettings)
            }
            return true
        } catch {
            print("[UserSettingsSyncService] local settings push failed: \(error)")
            if case APIServiceError.httpStatus(401) = error {
                await MainActor.run {
                    AuthSessionManager.shared.signOut()
                }
            }
            return false
        }
    }

    static func updateRemoteSelectedGroupIfAuthenticated(_ group: MyGroup) async -> SelectedGroupUpdateResult {
        guard let groupId = Int(group.id) else { return .failed }

        if !AuthSessionManager.shared.isAuthenticated {
            if let currentGroup = localSelectedGroup, currentGroup.id != groupId {
                return .authenticationRequired
            }
            applyLocalSelectedGroup(group)
            return .applied
        }

        do {
            let settings = try await APIService.shared.fetchSettings()
            if let currentGroupId = settings.selectedGroupId, currentGroupId != groupId {
                _ = try await APIService.shared.createGroupChangeRequest(
                    requestedGroupId: groupId,
                    requestedGroupName: group.name
                )
                return .changeRequestCreated
            }

            let updatedSettings = try await APIService.shared.updateSettings(
                selectedGroupId: groupId,
                selectedGroupName: group.name,
                scheduleCacheWeeks: settings.scheduleCacheWeeks,
                liveActivityEnabled: settings.liveActivityEnabled
            )
            await MainActor.run {
                apply(updatedSettings)
            }
            return .applied
        } catch {
            print("[UserSettingsSyncService] selected group sync failed: \(error)")
            if case APIServiceError.httpStatus(401) = error {
                await MainActor.run {
                    AuthSessionManager.shared.signOut()
                }
            }
            return .failed
        }
    }

    private static var localLiveActivityEnabled: Bool {
        guard UserDefaults.standard.object(forKey: liveActivityEnabledKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: liveActivityEnabledKey)
    }

    private static var localScheduleCacheWeeks: Int {
        guard UserDefaults.standard.object(forKey: offlineScheduleEnabledKey) != nil else { return 1 }
        guard UserDefaults.standard.bool(forKey: offlineScheduleEnabledKey) else { return 0 }
        return min(max(UserDefaults.standard.integer(forKey: offlineScheduleWeeksKey), 1), 4)
    }

    private static var localSelectedGroup: (id: Int, name: String)? {
        let rawGroupId = UserDefaults(suiteName: appGroupID)?.string(forKey: selectedGroupIdKey)
            ?? UserDefaults.standard.string(forKey: selectedGroupIdKey)
            ?? ""
        let trimmedGroupId = rawGroupId.mympsuTrimmed
        guard let groupId = Int(trimmedGroupId) else { return nil }

        let rawGroupName = UserDefaults(suiteName: appGroupID)?.string(forKey: selectedGroupNameKey)
            ?? UserDefaults.standard.string(forKey: selectedGroupNameKey)
            ?? trimmedGroupId
        let trimmedGroupName = rawGroupName.mympsuTrimmed
        return (
            id: groupId,
            name: trimmedGroupName.isEmpty ? trimmedGroupId : trimmedGroupName
        )
    }

    private static func applyLocalSelectedGroup(_ group: MyGroup) {
        UserDefaults.standard.set(group.id, forKey: selectedGroupIdKey)
        UserDefaults.standard.set(group.name, forKey: selectedGroupNameKey)
        UserDefaults(suiteName: appGroupID)?.set(group.id, forKey: selectedGroupIdKey)
        UserDefaults(suiteName: appGroupID)?.set(group.name, forKey: selectedGroupNameKey)
        UserDefaults.standard.set(group.id, forKey: scheduleGroupIdKey)
        UserDefaults.standard.set(group.name, forKey: scheduleGroupNameKey)
        UserDefaults(suiteName: appGroupID)?.set(group.id, forKey: scheduleGroupIdKey)
        UserDefaults(suiteName: appGroupID)?.set(group.name, forKey: scheduleGroupNameKey)

        NotificationCenter.default.post(
            name: didUpdateSelectedGroup,
            object: nil,
            userInfo: [
                "groupId": group.id,
                "groupName": group.name
            ]
        )
    }
}
