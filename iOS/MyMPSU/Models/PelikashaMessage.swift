import Foundation

enum PelikashaMessageRole: String, Codable {
    case user
    case assistant
    case systemLocal
}

struct PelikashaMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: PelikashaMessageRole
    let text: String
    let persona: AssistantPersona?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: PelikashaMessageRole,
        text: String,
        persona: AssistantPersona? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.persona = persona
        self.createdAt = createdAt
    }
}
