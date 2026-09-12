import Foundation

enum PelikashaIntentRouter {
    static func intent(for message: String) -> PelikashaIntent {
        let normalized = message.mympsuTrimmed.lowercased()
        if normalized.contains("распис") || normalized.contains("пар") {
            return .schedule
        }
        return .chat
    }
}
