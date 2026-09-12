import Foundation

struct AssistantChatContextPayload: Encodable {
    let selectedGroupId: Int?
    let selectedGroupName: String?
    let selectedDate: String?
}

struct CachedScheduleLessonPayload: Encodable {
    let name: String
    let type: String?
    let startTime: String?
    let endTime: String?
    let date: String?
    let room: String?
    let teacher: String?
    let classUrl: String?
    let isExam: Bool?
}

struct CachedSchedulePayload: Encodable {
    let generatedAt: String
    let source: String?
    let lessons: [CachedScheduleLessonPayload]
}

struct AssistantChatRequestPayload: Encodable {
    let message: String
    let persona: String
    let messages: [AssistantChatMessagePayload]?
    let context: AssistantChatContextPayload?
    let conversationId: String?
    let groupId: Int?
    let groupName: String?
    let targetDate: String?
    let cachedSchedule: CachedSchedulePayload?
}

struct AssistantChatResponsePayload: Decodable {
    let reply: String
    let remaining: Int?
    let plan: String?
}

final class AssistantAPIService {
    static let shared = AssistantAPIService()

    private init() {}

    func sendChatMessage(
        message: String,
        persona: AssistantPersona,
        messages: [AssistantChatMessagePayload]? = nil,
        conversationId: String?,
        groupId: Int?,
        groupName: String? = nil,
        targetDate: String?,
        cachedSchedule: CachedSchedulePayload?
    ) async throws -> AssistantChatResponsePayload {
        let payload = AssistantChatRequestPayload(
            message: message,
            persona: persona.rawValue,
            messages: messages,
            context: AssistantChatContextPayload(
                selectedGroupId: groupId,
                selectedGroupName: groupName,
                selectedDate: targetDate
            ),
            conversationId: conversationId,
            groupId: groupId,
            groupName: groupName,
            targetDate: targetDate,
            cachedSchedule: cachedSchedule
        )
        var request = try APIService.shared.makeAuthorizedMyMPSURequest(path: "/assistant/chat", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw APIServiceError.httpStatusWithBody(httpResponse.statusCode, body)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(AssistantChatResponsePayload.self, from: data)
    }
}
