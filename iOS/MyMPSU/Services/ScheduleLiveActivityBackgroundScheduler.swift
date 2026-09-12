import Foundation

#if os(iOS)
import BackgroundTasks

@MainActor
final class ScheduleLiveActivityBackgroundScheduler {
    static let shared = ScheduleLiveActivityBackgroundScheduler()

    static let refreshIdentifier = "ru.mympsu.live-activity.refresh"

    private var didRegister = false

    private init() {}

    func register() {
        guard !didRegister else { return }
        didRegister = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await self.handle(task)
            }
        }
    }

    func scheduleRefresh(at date: Date?) {
        guard let date else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = max(date.addingTimeInterval(1), Date().addingTimeInterval(60))
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[ScheduleLiveActivityBackgroundScheduler] schedule failed: \(error)")
        }
    }

    private func handle(_ task: BGAppRefreshTask) async {
        scheduleRefresh(at: Date().addingTimeInterval(15 * 60))
        let updateTask = Task { @MainActor in
            let viewModel = ScheduleViewModel()
            viewModel.refreshLiveActivityFromCachedSchedule()
        }

        task.expirationHandler = {
            updateTask.cancel()
        }

        await updateTask.value
        task.setTaskCompleted(success: !updateTask.isCancelled)
    }
}
#else
@MainActor
final class ScheduleLiveActivityBackgroundScheduler {
    static let shared = ScheduleLiveActivityBackgroundScheduler()
    private init() {}
    func register() {}
    func scheduleRefresh(at date: Date?) {}
}
#endif
