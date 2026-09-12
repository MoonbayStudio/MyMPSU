internal import Combine
import Foundation
import SwiftUI

@MainActor
final class ScheduleViewModel: ObservableObject {
    enum ManualRefreshResult {
        case success
        case failure
        case lastCachedDayExtensionFailed
    }

    private struct DisplayedScheduleContext: Equatable {
        let groupId: String
        let dateString: String?
        let examOnly: Bool
    }

    private struct TimedScheduleItem {
        let item: ScheduleItem
        let start: Date
        let end: Date
    }

    private struct LiveScheduleEvent {
        let activeLesson: ScheduleItem?
        let title: String
        let teacher: String
        let location: String
        let start: Date
        let end: Date
        let nextTitle: String?
        let nextTime: Date?
        let nextSubtitle: String?
    }

    private struct LiveActivityScheduleSnapshot: Codable {
        let groupName: String
        let items: [ScheduleItem]
    }

    struct DebugLesson {
        let title: String
        let teacher: String
        let location: String
        let start: Date
        let end: Date
    }

    private enum OfflineCacheConfig {
        static let enabledKey = "offlineScheduleEnabled"
        static let weeksKey = "offlineScheduleWeeks"
    }

    private enum LiveActivityConfig {
        static let enabledKey = "liveActivityEnabled"
    }

    private let appGroupID = "group.mympsu.shared"
    @Published var items: [ScheduleItem] = []
    @Published var animatedItems: [ScheduleItem] = []
    @Published var isLoading = false
    @Published var activeLesson: ScheduleItem?
    @Published var activeLessonProgress: Double = 0
    @Published var hasConnectionError = false
    @Published var isUsingOfflineCache = false
    @Published var hasOfflineCacheMissForSelectedDay = false
    @Published private var displayedScheduleContext: DisplayedScheduleContext?
    private var cache: [String: [ScheduleItem]] = [:]
    private var sessionCache: [String: [ScheduleItem]] = [:]
    private var offlineScheduleCache: [String: [ScheduleItem]] = [:]
    private var protectVisibleCacheUntil: Date?
    private var liveActivityGroupOverride: String?
    private let sessionCacheFileName = "session_cache.json"
    private let offlineCacheFileName = "offline_schedule_cache.json"
    private let liveActivitySnapshotFileName = "live_activity_schedule_snapshot.json"
    private let offlineCachePrimedPrefix = "offlineCachePrimedV2"
    private var activityTicker: AnyCancellable?
    @Published var savedGroupId: String {
        didSet {
            UserDefaults.standard.set(savedGroupId, forKey: "scheduleGroupId")
            UserDefaults(suiteName: appGroupID)?.set(savedGroupId, forKey: "scheduleGroupId")
        }
    }

    var loadedGroups: Set<String> = []
    
    private static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let fallbackISO8601DateFormatter: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    func loadOnce(groupId: String, date: Date, examOnly: Bool = false) async {
        guard !groupId.isEmpty else {
            displayedScheduleContext = nil
            showCachedSchedule([], usesOfflineCache: false, hasCacheMiss: false, groupId: groupId, date: date, examOnly: examOnly)
            return
        }

        if examOnly {
            loadSessionFromCache(groupId: groupId)
            return
        }

        let key = scheduleCacheKey(groupId: groupId, date: date, examOnly: examOnly)

        if let cachedItems = cache[key] {
            showCachedSchedule(cachedItems, usesOfflineCache: isOfflineCacheEnabled, hasCacheMiss: false, groupId: groupId, date: date, examOnly: examOnly)
            return
        }

        let offlineKey = offlineCacheKey(groupId: groupId, dateString: cacheDateString(from: date), examOnly: examOnly)
        if let offlineCachedItems = offlineScheduleCache[offlineKey] {
            let sortedItems = sortItems(offlineCachedItems, examOnly: examOnly)
            cache[key] = sortedItems
            showCachedSchedule(sortedItems, usesOfflineCache: isOfflineCacheEnabled, hasCacheMiss: false, groupId: groupId, date: date, examOnly: examOnly)
            return
        }

        offlineScheduleCache = Self.readSessionCacheFromDisk(fileName: offlineCacheFileName)
        if let offlineCachedItems = offlineScheduleCache[offlineKey] {
            let sortedItems = sortItems(offlineCachedItems, examOnly: examOnly)
            cache[key] = sortedItems
            showCachedSchedule(sortedItems, usesOfflineCache: isOfflineCacheEnabled, hasCacheMiss: false, groupId: groupId, date: date, examOnly: examOnly)
            return
        }

        if isDateOlderThanRetainedCacheWindow(date) {
            await loadUncachedHistoricalDay(groupId: groupId, date: date, examOnly: examOnly)
            return
        }

        showCachedSchedule([], usesOfflineCache: false, hasCacheMiss: isOfflineCacheEnabled, groupId: groupId, date: date, examOnly: examOnly)
    }

    func hasInMemoryCache(groupId: String, date: Date, examOnly: Bool = false) -> Bool {
        let key = scheduleCacheKey(groupId: groupId, date: date, examOnly: examOnly)
        return cache[key] != nil
    }

    func isDisplayingSchedule(groupId: String, date: Date, examOnly: Bool = false) -> Bool {
        guard !groupId.isEmpty else { return false }
        return displayedScheduleContext == displayContext(groupId: groupId, date: date, examOnly: examOnly)
    }

    func protectVisibleCacheDuringResume(seconds: TimeInterval = 3) {
        protectVisibleCacheUntil = Date().addingTimeInterval(seconds)
    }

    @discardableResult
    func restoreCachedScheduleForResume(groupId: String, date: Date, examOnly: Bool = false) -> Bool {
        guard !groupId.isEmpty else { return false }
        if examOnly {
            loadSessionFromCache(groupId: groupId)
            return !items.isEmpty
        }

        let key = scheduleCacheKey(groupId: groupId, date: date, examOnly: examOnly)

        if let cachedItems = cache[key] {
            showCachedSchedule(cachedItems, usesOfflineCache: isOfflineCacheEnabled, hasCacheMiss: false, groupId: groupId, date: date, examOnly: examOnly)
            return true
        }

        let offlineKey = offlineCacheKey(groupId: groupId, dateString: cacheDateString(from: date), examOnly: examOnly)
        if offlineScheduleCache[offlineKey] == nil {
            offlineScheduleCache = Self.readSessionCacheFromDisk(fileName: offlineCacheFileName)
        }
        guard let offlineItems = offlineScheduleCache[offlineKey] else { return false }
        let sortedItems = sortItems(offlineItems, examOnly: examOnly)
        cache[key] = sortedItems
        showCachedSchedule(sortedItems, usesOfflineCache: isOfflineCacheEnabled, hasCacheMiss: false, groupId: groupId, date: date, examOnly: examOnly)
        return true
    }

    init() {
        let sharedScheduleGroupValue = UserDefaults(suiteName: appGroupID)?.string(forKey: "scheduleGroupId")
        let localScheduleGroupValue = UserDefaults.standard.string(forKey: "scheduleGroupId")
        let sharedDefaultGroupValue = UserDefaults(suiteName: appGroupID)?.string(forKey: "selectedGroupId")
        let localDefaultGroupValue = UserDefaults.standard.string(forKey: "selectedGroupId")
        self.savedGroupId = sharedScheduleGroupValue
            ?? localScheduleGroupValue
            ?? sharedDefaultGroupValue
            ?? localDefaultGroupValue
            ?? ""
        if !savedGroupId.isEmpty {
            UserDefaults.standard.set(savedGroupId, forKey: "scheduleGroupId")
            UserDefaults(suiteName: appGroupID)?.set(savedGroupId, forKey: "scheduleGroupId")
        }
        self.sessionCache = Self.readSessionCacheFromDisk(fileName: sessionCacheFileName)
        self.offlineScheduleCache = Self.readSessionCacheFromDisk(fileName: offlineCacheFileName)
        self.activityTicker = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshActiveLessonState()
            }
    }

    @discardableResult
    func load(for groupId: String, date: Date, examOnly: Bool = false) async -> Bool {
        let key = scheduleCacheKey(groupId: groupId, date: date, examOnly: examOnly)

        isLoading = true
        hasConnectionError = false
        hasOfflineCacheMissForSelectedDay = false

        let data = await APIService.shared.fetchSchedule(for: groupId, date: date, examOnly: examOnly)
        let connectionFailed = data.isEmpty && APIService.shared.lastScheduleConnectionError
        hasConnectionError = connectionFailed
        if data.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            print("[ScheduleViewModel] Empty schedule. groupId=\(groupId), date=\(f.string(from: date)), examOnly=\(examOnly)")
        } else {
            print("[ScheduleViewModel] Loaded \(data.count) items. groupId=\(groupId), examOnly=\(examOnly)")
        }
        var sorted = sortItems(data, examOnly: examOnly)

        if !connectionFailed {
            isUsingOfflineCache = false
            cache[key] = sorted
            saveOfflineSnapshot(items: sorted, groupId: groupId, date: date, examOnly: examOnly)
            if examOnly {
                sessionCache[groupId] = sorted
                Self.writeSessionCacheToDisk(sessionCache, fileName: sessionCacheFileName)
            }
        }

        if sorted.isEmpty, connectionFailed, isOfflineCacheEnabled {
            let cachedKey = offlineCacheKey(groupId: groupId, dateString: cacheDateString(from: date), examOnly: examOnly)
            if let cached = offlineScheduleCache[cachedKey] {
                sorted = sortItems(cached, examOnly: examOnly)
                cache[key] = sorted
                hasConnectionError = false
                isUsingOfflineCache = true
                print("[ScheduleViewModel] Loaded \(sorted.count) items from offline cache. groupId=\(groupId), examOnly=\(examOnly)")
            } else if !examOnly {
                hasOfflineCacheMissForSelectedDay = true
            }
        }

        displayedScheduleContext = displayContext(groupId: groupId, date: date, examOnly: examOnly)
        items = sorted
        await MainActor.run {
            liveActivityGroupOverride = nil
            animatedItems = sorted
            refreshActiveLessonState()
        }
        isLoading = false
        return !connectionFailed
    }

    func manualRefresh(groupId: String, date: Date, examOnly: Bool = false) async -> ManualRefreshResult {
        guard !groupId.isEmpty else { return .failure }
        if examOnly {
            let success = await load(for: groupId, date: date, examOnly: true)
            return success ? .success : .failure
        }

        if isOfflineCacheEnabled, isLastCachedScheduleDay(groupId: groupId, date: date) {
            let success = await refreshForwardCacheRange(groupId: groupId, startDate: date, weeks: offlineCacheWeeks)
            return success ? .success : .lastCachedDayExtensionFailed
        }

        let success = await load(for: groupId, date: date, examOnly: false)
        return success ? .success : .failure
    }

    private var isOfflineCacheEnabled: Bool {
        UserDefaults.standard.bool(forKey: OfflineCacheConfig.enabledKey)
    }

    private var offlineCacheWeeks: Int {
        let value = UserDefaults.standard.integer(forKey: OfflineCacheConfig.weeksKey)
        if (1...4).contains(value) { return value }
        return 1
    }

    func ensureScheduleCachesIfNeeded(groupId: String, anchorDate: Date = Date()) async {
        guard !groupId.isEmpty else { return }
        if isOfflineCacheEnabled {
            await warmOfflineCacheIfNeeded(groupId: groupId, anchorDate: anchorDate)
        }
        if sessionCache[groupId] == nil {
            await refreshSessionCache(groupId: groupId)
        }
    }

    private func showCachedSchedule(_ cachedItems: [ScheduleItem], usesOfflineCache: Bool, hasCacheMiss: Bool, groupId: String, date: Date, examOnly: Bool) {
        let context = displayContext(groupId: groupId, date: date, examOnly: examOnly)
        if cachedItems.isEmpty, hasCacheMiss, shouldKeepVisibleCacheOnMiss {
            isLoading = false
            hasConnectionError = false
            hasOfflineCacheMissForSelectedDay = false
            isUsingOfflineCache = isOfflineCacheEnabled
            refreshActiveLessonState()
            return
        }
        liveActivityGroupOverride = nil
        displayedScheduleContext = context
        items = cachedItems
        animatedItems = cachedItems
        isLoading = false
        hasConnectionError = false
        hasOfflineCacheMissForSelectedDay = hasCacheMiss
        isUsingOfflineCache = usesOfflineCache && !hasCacheMiss
        refreshActiveLessonState()
    }

    private var shouldKeepVisibleCacheOnMiss: Bool {
        guard let protectVisibleCacheUntil, Date() < protectVisibleCacheUntil else {
            return false
        }
        return !items.isEmpty || !animatedItems.isEmpty
    }

    private func prefetchOfflineRange(groupId: String, from startDate: Date, weeks: Int) async {
        guard !groupId.isEmpty else { return }
        let normalizedWeeks = min(max(weeks, 1), 4)
        let calendar = Calendar(identifier: .gregorian)
        let rangeStartDate = calendar.date(byAdding: .day, value: -7, to: startDate) ?? startDate
        let days = normalizedWeeks * 7 - 1
        let endDate = calendar.date(byAdding: .day, value: days, to: startDate) ?? startDate

        let rangeItems = await APIService.shared.fetchScheduleRange(
            for: groupId,
            startDate: rangeStartDate,
            endDate: endDate,
            examOnly: false
        )
        guard !APIService.shared.lastScheduleConnectionError else {
            return
        }

        let groupedByDay = Dictionary(grouping: rangeItems) { item in
            cacheDateString(from: parseISODate(item.sortDateISO) ?? startDate)
        }

        var day = rangeStartDate
        while day <= endDate {
            let dayString = cacheDateString(from: day)
            let key = offlineCacheKey(groupId: groupId, dateString: dayString, examOnly: false)
            offlineScheduleCache[key] = sortItems(groupedByDay[dayString] ?? [], examOnly: false)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? endDate.addingTimeInterval(1)
        }
        Self.writeSessionCacheToDisk(offlineScheduleCache, fileName: offlineCacheFileName)
        print("[ScheduleViewModel] Offline cache prefetch saved for \(normalizedWeeks) week(s), groupId=\(groupId)")
    }

    private func refreshForwardCacheRange(groupId: String, startDate: Date, weeks: Int) async -> Bool {
        guard !groupId.isEmpty else { return false }
        let normalizedWeeks = min(max(weeks, 1), 4)
        let calendar = Calendar(identifier: .gregorian)
        let days = normalizedWeeks * 7 - 1
        let endDate = calendar.date(byAdding: .day, value: days, to: startDate) ?? startDate

        let rangeItems = await APIService.shared.fetchScheduleRange(
            for: groupId,
            startDate: startDate,
            endDate: endDate,
            examOnly: false
        )
        guard !APIService.shared.lastScheduleConnectionError else {
            return false
        }

        let groupedByDay = Dictionary(grouping: rangeItems) { item in
            cacheDateString(from: parseISODate(item.sortDateISO) ?? startDate)
        }

        var day = startDate
        while day <= endDate {
            let dayString = cacheDateString(from: day)
            let sortedItems = sortItems(groupedByDay[dayString] ?? [], examOnly: false)
            let diskKey = offlineCacheKey(groupId: groupId, dateString: dayString, examOnly: false)
            let memoryKey = scheduleCacheKey(groupId: groupId, date: day, examOnly: false)
            offlineScheduleCache[diskKey] = sortedItems
            cache[memoryKey] = sortedItems
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? endDate.addingTimeInterval(1)
        }

        removeScheduleCacheOlderThanPreviousWeek()
        Self.writeSessionCacheToDisk(offlineScheduleCache, fileName: offlineCacheFileName)
        _ = restoreCachedScheduleForResume(groupId: groupId, date: startDate, examOnly: false)
        return true
    }

    private func syncOfflineCacheRange(groupId: String, anchorDate: Date, weeks: Int) async {
        guard !groupId.isEmpty else { return }

        let normalizedWeeks = min(max(weeks, 1), 4)
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(byAdding: .day, value: -7, to: anchorDate) ?? anchorDate
        let days = normalizedWeeks * 7 - 1
        let endDate = calendar.date(byAdding: .day, value: days, to: anchorDate) ?? anchorDate

        let rangeItems = await APIService.shared.fetchScheduleRange(
            for: groupId,
            startDate: startDate,
            endDate: endDate,
            examOnly: false
        )
        guard !rangeItems.isEmpty || !APIService.shared.lastScheduleConnectionError else {
            return
        }

        let groupedByDay = Dictionary(grouping: rangeItems) { item in
            cacheDateString(from: parseISODate(item.sortDateISO) ?? anchorDate)
        }

        var changed = false
        var day = startDate
        while day <= endDate {
            let dayString = cacheDateString(from: day)
            let key = offlineCacheKey(groupId: groupId, dateString: dayString, examOnly: false)
            let newItems = sortItems(groupedByDay[dayString] ?? [], examOnly: false)
            let oldItems = offlineScheduleCache[key] ?? []
            if oldItems != newItems {
                offlineScheduleCache[key] = newItems
                changed = true
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? endDate.addingTimeInterval(1)
        }

        if changed {
            Self.writeSessionCacheToDisk(offlineScheduleCache, fileName: offlineCacheFileName)
            print("[ScheduleViewModel] Offline cache synchronized for \(normalizedWeeks) week(s), groupId=\(groupId)")
        }
    }

    private func saveOfflineSnapshot(items: [ScheduleItem], groupId: String, date: Date, examOnly: Bool) {
        let key = offlineCacheKey(groupId: groupId, dateString: cacheDateString(from: date), examOnly: examOnly)
        offlineScheduleCache[key] = items
        Self.writeSessionCacheToDisk(offlineScheduleCache, fileName: offlineCacheFileName)
    }

    private func loadOfflineSnapshot(groupId: String, date: Date, examOnly: Bool) -> [ScheduleItem] {
        let key = offlineCacheKey(groupId: groupId, dateString: cacheDateString(from: date), examOnly: examOnly)
        return offlineScheduleCache[key] ?? []
    }

    private func loadOfflineSnapshotWithFallback(groupId: String, date: Date, examOnly: Bool) -> [ScheduleItem] {
        let direct = loadOfflineSnapshot(groupId: groupId, date: date, examOnly: examOnly)
        if !direct.isEmpty { return direct }

        let target = cacheDateString(from: date)
        let suffix = "|\(examOnly)"
        let prefix = "\(groupId)|"

        // 1) Try exact match by key parsing (defensive against key construction mismatches).
        for (key, value) in offlineScheduleCache where key.hasPrefix(prefix) && key.hasSuffix(suffix) {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false)
            if parts.count == 3, String(parts[1]) == target, !value.isEmpty {
                return value
            }
        }

        // 2) If exact day cache is absent, return nearest cached day for this group.
        let targetDate = parseDayString(target) ?? date
        var nearest: (distance: TimeInterval, items: [ScheduleItem])?
        for (key, value) in offlineScheduleCache where key.hasPrefix(prefix) && key.hasSuffix(suffix) {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 3,
                  let day = parseDayString(String(parts[1])),
                  !value.isEmpty else { continue }
            let distance = abs(day.timeIntervalSince(targetDate))
            if nearest == nil || distance < nearest!.distance {
                nearest = (distance, value)
            }
        }
        return nearest?.items ?? []
    }

    private func parseDayString(_ value: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: value)
    }

    @discardableResult
    private func removePastOfflineCacheDays() -> Bool {
        let todayString = cacheDateString(from: Date())
        var changed = false
        offlineScheduleCache = offlineScheduleCache.filter { key, _ in
            let parts = key.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 3 else { return true }
            let day = String(parts[1])
            let keep = day >= todayString
            if !keep { changed = true }
            return keep
        }
        return changed
    }

    private func removeScheduleCacheOlderThanPreviousWeek() {
        let calendar = Calendar(identifier: .gregorian)
        let startOfToday = calendar.startOfDay(for: Date())
        let oldestKeptDate = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        let oldestKeptDay = cacheDateString(from: oldestKeptDate)

        offlineScheduleCache = offlineScheduleCache.filter { key, _ in
            let parts = key.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 3 else { return true }
            guard String(parts[2]) == "false" else { return true }
            return String(parts[1]) >= oldestKeptDay
        }
        cache = cache.filter { key, _ in
            let parts = key.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 3 else { return true }
            guard String(parts[2]) == "false" else { return true }
            return String(parts[1]) >= oldestKeptDay
        }
    }

    private func isLastCachedScheduleDay(groupId: String, date: Date) -> Bool {
        offlineScheduleCache = Self.readSessionCacheFromDisk(fileName: offlineCacheFileName)
        let selectedDay = cacheDateString(from: date)
        let prefix = "\(groupId)|"
        let lastDay = offlineScheduleCache.keys.compactMap { key -> String? in
            guard key.hasPrefix(prefix), key.hasSuffix("|false") else { return nil }
            let parts = key.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 3 else { return nil }
            return String(parts[1])
        }.max()
        return lastDay == selectedDay
    }

    private func isDateOlderThanRetainedCacheWindow(_ date: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let startOfToday = calendar.startOfDay(for: Date())
        let oldestKeptDate = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        return calendar.startOfDay(for: date) < oldestKeptDate
    }

    private func loadUncachedHistoricalDay(groupId: String, date: Date, examOnly: Bool) async {
        let data = await APIService.shared.fetchSchedule(for: groupId, date: date, examOnly: examOnly)
        guard !APIService.shared.lastScheduleConnectionError else {
            showCachedSchedule([], usesOfflineCache: false, hasCacheMiss: true, groupId: groupId, date: date, examOnly: examOnly)
            return
        }
        showCachedSchedule(sortItems(data, examOnly: examOnly), usesOfflineCache: false, hasCacheMiss: false, groupId: groupId, date: date, examOnly: examOnly)
    }

    private func offlineCacheKey(groupId: String, dateString: String, examOnly: Bool) -> String {
        "\(groupId)|\(dateString)|\(examOnly)"
    }

    private func scheduleCacheKey(groupId: String, date: Date, examOnly: Bool) -> String {
        "\(groupId)|\(cacheDateString(from: date))|\(examOnly)"
    }

    private func cacheDateString(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func displayContext(groupId: String, date: Date, examOnly: Bool) -> DisplayedScheduleContext {
        DisplayedScheduleContext(
            groupId: groupId,
            dateString: examOnly ? nil : cacheDateString(from: date),
            examOnly: examOnly
        )
    }
    
    func loadSessionFromCache(groupId: String) {
        guard !groupId.isEmpty else { return }
        let cached = sessionCache[groupId] ?? []
        let prepared = sortItems(cached, examOnly: true)
        liveActivityGroupOverride = nil
        hasConnectionError = false
        hasOfflineCacheMissForSelectedDay = false
        displayedScheduleContext = displayContext(groupId: groupId, date: Date(), examOnly: true)
        items = prepared
        animatedItems = prepared
        isLoading = false
        refreshActiveLessonState()
    }
    
    func preloadSessionCacheIfNeeded(groupId: String) async {
        guard !groupId.isEmpty else { return }
        guard sessionCache[groupId] == nil else { return }
        await refreshSessionCache(groupId: groupId)
    }

    func refreshLiveActivityFromCachedSchedule(date: Date = Date()) {
        if let snapshot = Self.readLiveActivitySnapshotFromDisk(fileName: liveActivitySnapshotFileName) {
            let sortedItems = sortItems(snapshot.items, examOnly: false)
            liveActivityGroupOverride = snapshot.groupName
            items = sortedItems
            animatedItems = sortedItems
            refreshActiveLessonState()
            return
        }

        guard !savedGroupId.isEmpty else {
            endLiveActivityAndClearSnapshot()
            return
        }

        offlineScheduleCache = Self.readSessionCacheFromDisk(fileName: offlineCacheFileName)
        let key = offlineCacheKey(groupId: savedGroupId, dateString: cacheDateString(from: date), examOnly: false)
        guard let cachedItems = offlineScheduleCache[key] else {
            endLiveActivityAndClearSnapshot()
            return
        }

        let sortedItems = sortItems(cachedItems, examOnly: false)
        cache[scheduleCacheKey(groupId: savedGroupId, date: date, examOnly: false)] = sortedItems
        liveActivityGroupOverride = nil
        items = sortedItems
        animatedItems = sortedItems
        refreshActiveLessonState()
    }

    func applyDebugScheduleForLiveActivity(groupName: String, lessons: [DebugLesson]) {
        let preparedLessons = lessons
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }
        guard !preparedLessons.isEmpty else { return }

        let debugGroupName = groupName.mympsuTrimmed.isEmpty ? "Debug group" : groupName.mympsuTrimmed
        let debugItems = preparedLessons.map { lesson in
            ScheduleItem(
                sortDateISO: Self.iso8601DateFormatter.string(from: lesson.start),
                endDateISO: Self.iso8601DateFormatter.string(from: lesson.end),
                time: Self.shortTimeFormatter.string(from: lesson.start),
                title: lesson.title.mympsuTrimmed.isEmpty ? "Тестовая пара" : lesson.title.mympsuTrimmed,
                teacher: lesson.teacher.mympsuTrimmed,
                lessonType: "debug",
                address: "",
                subgroup: nil,
                period: "\(Self.shortTimeFormatter.string(from: lesson.start))-\(Self.shortTimeFormatter.string(from: lesson.end))",
                room: lesson.location.mympsuTrimmed,
                classURL: nil
            )
        }

        liveActivityGroupOverride = debugGroupName
        displayedScheduleContext = displayContext(groupId: debugGroupName, date: Date(), examOnly: false)
        items = debugItems
        animatedItems = debugItems
        isLoading = false
        hasConnectionError = false
        hasOfflineCacheMissForSelectedDay = false
        isUsingOfflineCache = false
        refreshActiveLessonState()
    }

    func refreshSessionCache(groupId: String) async {
        guard !groupId.isEmpty else { return }
        let data = await APIService.shared.fetchSchedule(for: groupId, date: Date(), examOnly: true)
        sessionCache[groupId] = sortItems(data, examOnly: true)
        Self.writeSessionCacheToDisk(sessionCache, fileName: sessionCacheFileName)
    }

    func warmOfflineCacheIfNeeded(groupId: String, anchorDate: Date = Date()) async {
        guard isOfflineCacheEnabled, !groupId.isEmpty else { return }
        let weeks = offlineCacheWeeks
        if hasFullOfflineCacheRange(groupId: groupId, anchorDate: anchorDate, weeks: weeks) {
            return
        }
        await prefetchOfflineRange(groupId: groupId, from: anchorDate, weeks: weeks)
    }

    private func hasFullOfflineCacheRange(groupId: String, anchorDate: Date, weeks: Int) -> Bool {
        let normalizedWeeks = min(max(weeks, 1), 4)
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(byAdding: .day, value: -7, to: anchorDate) ?? anchorDate
        let days = normalizedWeeks * 7 - 1
        let endDate = calendar.date(byAdding: .day, value: days, to: anchorDate) ?? anchorDate
        var day = startDate
        while day <= endDate {
            let key = offlineCacheKey(groupId: groupId, dateString: cacheDateString(from: day), examOnly: false)
            if offlineScheduleCache[key] == nil {
                return false
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? endDate.addingTimeInterval(1)
        }
        return true
    }
    
    private func sortItems(_ items: [ScheduleItem], examOnly: Bool) -> [ScheduleItem] {
        if examOnly {
            let filtered = filterCurrentSessionItems(items)
            return filtered.sorted {
                (parseISODate($0.sortDateISO) ?? .distantFuture) < (parseISODate($1.sortDateISO) ?? .distantFuture)
            }
        }
        return items.sorted(by: { $0.time < $1.time })
    }
    
    private func filterCurrentSessionItems(_ items: [ScheduleItem]) -> [ScheduleItem] {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        
        // Hide passed exams.
        let futureItems = items.filter { item in
            guard let date = parseISODate(item.sortDateISO) else { return false }
            return date >= now
        }
        
        guard !futureItems.isEmpty else { return [] }
        
        // Choose session season from device month:
        // Aug-Dec -> winter (Dec-Feb), Jan-Jul -> summer (May-Jul).
        let month = calendar.component(.month, from: now)
        let winterMonths: Set<Int> = [12, 1, 2]
        let summerMonths: Set<Int> = [5, 6, 7]
        let targetMonths = (month >= 8 || month == 12) ? winterMonths : summerMonths
        
        return futureItems.filter { item in
            guard let date = parseISODate(item.sortDateISO) else { return false }
            return targetMonths.contains(calendar.component(.month, from: date))
        }
    }
    
    private func parseISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return Self.iso8601DateFormatter.date(from: value) ?? Self.fallbackISO8601DateFormatter.date(from: value)
    }
    
    private func refreshActiveLessonState() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else {
            activeLesson = nil
            activeLessonProgress = 0
            endLiveActivityAndClearSnapshot()
            return
        }

        guard let event = currentLiveScheduleEvent(at: Date()) else {
            activeLesson = nil
            activeLessonProgress = 0
            endLiveActivityAndClearSnapshot()
            return
        }

        let total = event.end.timeIntervalSince(event.start)
        let elapsed = Date().timeIntervalSince(event.start)
        activeLesson = event.activeLesson
        activeLessonProgress = min(max(elapsed / total, 0), 1)
        guard isLiveActivityEnabled else {
            endLiveActivityAndClearSnapshot()
            return
        }

        persistLiveActivitySnapshot(groupName: liveActivityGroupOverride ?? savedGroupId)
        LiveActivityManager.shared.updateOrStart(
            lessonTitle: event.title,
            teacher: event.teacher,
            location: event.location,
            startTime: event.start,
            endTime: event.end,
            progress: activeLessonProgress,
            groupName: liveActivityGroupOverride ?? savedGroupId,
            nextTitle: event.nextTitle,
            nextTime: event.nextTime,
            nextSubtitle: event.nextSubtitle
        )
    }

    private func persistLiveActivitySnapshot(groupName: String) {
        let snapshot = LiveActivityScheduleSnapshot(
            groupName: groupName.mympsuTrimmed.isEmpty ? savedGroupId : groupName,
            items: timedScheduleItems().map(\.item)
        )
        Self.writeLiveActivitySnapshotToDisk(snapshot, fileName: liveActivitySnapshotFileName)
    }

    private func endLiveActivityAndClearSnapshot() {
        Self.removeLiveActivitySnapshotFromDisk(fileName: liveActivitySnapshotFileName)
        LiveActivityManager.shared.endIfNeeded()
    }

    private func currentLiveScheduleEvent(at now: Date) -> LiveScheduleEvent? {
        let timedItems = timedScheduleItems()
        guard !timedItems.isEmpty else { return nil }

        for index in timedItems.indices {
            let lesson = timedItems[index]
            if lesson.start <= now && now < lesson.end {
                return lessonEvent(for: lesson, next: nextTimedItem(in: timedItems, after: index))
            }

            guard index > 0 else { continue }
            let previous = timedItems[index - 1]
            if previous.end <= now && now < lesson.start && lesson.start.timeIntervalSince(previous.end) > 60 {
                return breakEvent(from: previous.end, to: lesson.start, next: lesson)
            }
        }

        return nil
    }

    private func timedScheduleItems() -> [TimedScheduleItem] {
        items.compactMap { item in
            guard let start = parseISODate(item.sortDateISO),
                  let end = parseISODate(item.endDateISO),
                  end > start else { return nil }
            return TimedScheduleItem(item: item, start: start, end: end)
        }
        .sorted { $0.start < $1.start }
    }

    private func nextTimedItem(in items: [TimedScheduleItem], after index: Int) -> TimedScheduleItem? {
        let nextIndex = index + 1
        return items.indices.contains(nextIndex) ? items[nextIndex] : nil
    }

    private func lessonEvent(for lesson: TimedScheduleItem, next: TimedScheduleItem?) -> LiveScheduleEvent {
        let nextEvent = nextEventSummary(afterLessonEndingAt: lesson.end, next: next)
        return LiveScheduleEvent(
            activeLesson: lesson.item,
            title: lesson.item.title,
            teacher: lesson.item.teacher.isEmpty ? "Преподаватель не указан" : lesson.item.teacher,
            location: lessonLocation(for: lesson.item),
            start: lesson.start,
            end: lesson.end,
            nextTitle: nextEvent?.title,
            nextTime: nextEvent?.time,
            nextSubtitle: nextEvent?.subtitle
        )
    }

    private func breakEvent(from start: Date, to end: Date, next: TimedScheduleItem) -> LiveScheduleEvent {
        LiveScheduleEvent(
            activeLesson: nil,
            title: "Перерыв",
            teacher: "Следующая пара",
            location: next.item.title,
            start: start,
            end: end,
            nextTitle: next.item.title,
            nextTime: end,
            nextSubtitle: nextLessonSubtitle(for: next.item)
        )
    }

    private func nextEventSummary(afterLessonEndingAt end: Date, next: TimedScheduleItem?) -> (title: String, time: Date, subtitle: String?)? {
        guard let next else { return nil }
        return (next.item.title, next.start, nextLessonSubtitle(for: next.item))
    }

    private func nextLessonSubtitle(for item: ScheduleItem) -> String {
        let teacher = item.teacher.mympsuTrimmed
        let location = lessonLocation(for: item)

        switch (teacher.isEmpty, location.isEmpty) {
        case (false, false):
            return "\(teacher), ауд. \(location)"
        case (false, true):
            return teacher
        case (true, false):
            return "ауд. \(location)"
        case (true, true):
            return ""
        }
    }

    private func lessonLocation(for item: ScheduleItem) -> String {
        [item.address, item.room]
            .map { $0.mympsuTrimmed }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private var isLiveActivityEnabled: Bool {
        guard UserDefaults.standard.object(forKey: LiveActivityConfig.enabledKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: LiveActivityConfig.enabledKey)
    }
    
    private static func sessionCacheURL(fileName: String) -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return dir.appendingPathComponent(fileName)
    }
    
    private static func readSessionCacheFromDisk(fileName: String) -> [String: [ScheduleItem]] {
        guard let url = sessionCacheURL(fileName: fileName),
              let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode([String: [ScheduleItem]].self, from: data) else {
            return [:]
        }
        return cache
    }
    
    private static func writeSessionCacheToDisk(_ cache: [String: [ScheduleItem]], fileName: String) {
        guard let url = sessionCacheURL(fileName: fileName),
              let data = try? JSONEncoder().encode(cache) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private static func readLiveActivitySnapshotFromDisk(fileName: String) -> LiveActivityScheduleSnapshot? {
        guard let url = sessionCacheURL(fileName: fileName),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(LiveActivityScheduleSnapshot.self, from: data)
    }

    private static func writeLiveActivitySnapshotToDisk(_ snapshot: LiveActivityScheduleSnapshot, fileName: String) {
        guard let url = sessionCacheURL(fileName: fileName),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private static func removeLiveActivitySnapshotFromDisk(fileName: String) {
        guard let url = sessionCacheURL(fileName: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
