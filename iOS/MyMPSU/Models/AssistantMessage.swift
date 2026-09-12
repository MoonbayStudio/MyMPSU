import Foundation

enum AssistantPersona: String, Codable, CaseIterable, Identifiable {
    case pelikasha
    case stesha

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pelikasha: return "Помощник МПГУ"
        case .stesha: return "Стеша"
        }
    }

    var icon: String {
        switch self {
        case .pelikasha: return "bird.fill"
        case .stesha: return "heart.text.square.fill"
        }
    }

    var promptHint: String {
        switch self {
        case .pelikasha: return "Быстрые ответы про учебу и расписание."
        case .stesha: return "Спокойные подсказки и поддержка."
        }
    }
}

enum AssistantMessageRole: String, Codable {
    case user
    case assistant
    case systemLocal
}

struct AssistantMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: AssistantMessageRole
    let text: String
    let persona: AssistantPersona?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: AssistantMessageRole,
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
