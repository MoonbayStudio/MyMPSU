import Foundation

struct PelikashaScheduleProvider {
    func scheduleSummary(groupId: String, date: Date) async -> String? {
        let items = await APIService.shared.fetchSchedule(for: groupId, date: date)
        guard !items.isEmpty else { return nil }
        return items.map { "\($0.time) \($0.title)" }.joined(separator: "\n")
    }
}
