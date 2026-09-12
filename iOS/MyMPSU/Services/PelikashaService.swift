import Foundation

final class PelikashaService {
    static let shared = PelikashaService()
    private init() {}

    func send(_ text: String, conversationId: UUID) async throws -> String {
        let response = try await AssistantAPIService.shared.sendChatMessage(
            message: text,
            persona: .pelikasha,
            conversationId: conversationId.uuidString,
            groupId: nil,
            targetDate: nil,
            cachedSchedule: nil
        )
        return response.reply
    }
}
