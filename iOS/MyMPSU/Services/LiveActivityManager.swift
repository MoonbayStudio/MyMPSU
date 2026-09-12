import Foundation

#if os(iOS)
import ActivityKit

@available(iOS 16.1, *)
struct ScheduleActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var lessonTitle: String
        var teacher: String
        var location: String
        var startTime: Date
        var endTime: Date
        var progress: Double
        var nextTitle: String?
        var nextTime: Date?
        var nextSubtitle: String?
    }

    var groupName: String
}

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    var isSupported: Bool {
#if os(iOS)
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
#else
        return false
#endif
    }

    func updateOrStart(
        lessonTitle: String,
        teacher: String,
        location: String,
        startTime: Date,
        endTime: Date,
        progress: Double,
        groupName: String,
        nextTitle: String? = nil,
        nextTime: Date? = nil,
        nextSubtitle: String? = nil
    ) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        ScheduleLiveActivityBackgroundScheduler.shared.register()

        let state = ScheduleActivityAttributes.ContentState(
            lessonTitle: lessonTitle,
            teacher: teacher,
            location: location,
            startTime: startTime,
            endTime: endTime,
            progress: min(max(progress, 0), 1),
            nextTitle: nextTitle,
            nextTime: nextTime,
            nextSubtitle: nextSubtitle
        )

        if let activity = Activity<ScheduleActivityAttributes>.activities.first {
            Task {
                await activity.update(using: state)
            }
            ScheduleLiveActivityBackgroundScheduler.shared.scheduleRefresh(at: endTime)
            return
        }

        let attributes = ScheduleActivityAttributes(groupName: groupName)
        do {
            _ = try Activity.request(attributes: attributes, contentState: state)
            ScheduleLiveActivityBackgroundScheduler.shared.scheduleRefresh(at: endTime)
        } catch {
            // Keep silent to avoid noisy logs in production builds.
        }
    }

    func endIfNeeded() {
        guard #available(iOS 16.1, *) else { return }
        Task {
            for activity in Activity<ScheduleActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
#else
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}
    var isSupported: Bool { false }
    func updateOrStart(lessonTitle: String, teacher: String, location: String, startTime: Date, endTime: Date, progress: Double, groupName: String, nextTitle: String? = nil, nextTime: Date? = nil, nextSubtitle: String? = nil) {}
    func endIfNeeded() {}
}
#endif
