import Foundation

struct AssistantChatMessagePayload: Codable, Equatable {
    let role: String
    let content: String
}

struct PelikashaPromptMessage: Equatable {
    let id: UUID
    let role: String
    let text: String
}

struct PelikashaPromptDialog: Equatable {
    var messages: [PelikashaPromptMessage]
    var summary: String?
    var summarizedMessageIDs: [UUID]
}

struct PelikashaSummaryResult: Equatable {
    let summary: String
    let summarizedMessageIDs: [UUID]
}

enum ChatIntent: Equatable {
    case smallTalk
    case groupInfo
    case todaySchedule
    case tomorrowSchedule
    case currentLesson
    case exams
    case homework
    case unknown
}

struct UserGroupContext: Codable, Sendable, Equatable {
    let id: Int
    let name: String?
    let facultyName: String?
    let programName: String?

    var displayName: String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct AIScheduleLessonContext: Codable, Sendable, Equatable {
    let startISO: String
    let endISO: String
    let time: String
    let title: String
    let teacher: String
    let lessonType: String
    let address: String
    let subgroup: String?
    let period: String
    let room: String
    let classURL: String?
}

struct AIHomeworkContext: Codable, Sendable, Equatable {
    let lessonDate: String
    let lessonTime: String
    let subject: String
    let teacher: String?
    let room: String?
    let text: String
}

struct AIPlanLimits: Equatable {
    let maxRequestChars: Int

    static let base = AIPlanLimits(maxRequestChars: 2_000)

    var safeMax: Int {
        max(0, maxRequestChars - 200)
    }
}

struct ContextPacket: Equatable {
    let name: String
    let priority: Int
    let maxChars: Int
    let content: String
}

struct ContextBudgetResult: Equatable {
    let prompt: String
    let packets: [ContextPacket]
    let usedEmergencyPrompt: Bool
}

struct ChatOrchestrationContext: Equatable {
    let intent: ChatIntent
    let personaRawValue: String
    let userMessage: String
    let group: UserGroupContext?
    let targetDate: Date
    let scheduleItems: [AIScheduleLessonContext]
    let exams: [AIScheduleLessonContext]
    let homeworks: [AIHomeworkContext]
    let dialog: PelikashaPromptDialog
}

struct AIValidationResult: Equatable {
    let isValid: Bool
    let reason: String?
}

enum ChatIntentDetector {
    nonisolated static func detectIntent(_ text: String) -> ChatIntent {
        let normalized = normalize(text)
        let hasStudyKeyword = containsAny(
            normalized,
            [
                "групп", "пара", "пары", "распис", "занят", "урок",
                "экзам", "сесс", "зачет", "зачёт", "домаш", "дз", "задано"
            ]
        )

        if containsAny(normalized, ["какая у меня группа", "из какой я группы", "название группы", "моя группа", "какую группу"]) {
            return .groupInfo
        }
        if containsAny(normalized, ["какая сейчас пара", "что сейчас", "следующая пара", "текущая пара", "сейчас пара"]) {
            return .currentLesson
        }
        if containsAny(normalized, ["что завтра", "пары завтра", "расписание завтра", "завтра пары", "завтра расписание"]) {
            return .tomorrowSchedule
        }
        if containsAny(normalized, ["что сегодня", "пары сегодня", "расписание сегодня", "сегодня пары", "сегодня расписание"]) {
            return .todaySchedule
        }
        if containsAny(normalized, ["экзамен", "экзамены", "сессия", "сессии", "зачет", "зачёт"]) {
            return .exams
        }
        if containsAny(normalized, ["домашка", "домашнее", "дз", "что задано", "задали"]) {
            return .homework
        }
        if normalized.count <= 80 && !hasStudyKeyword {
            return .smallTalk
        }
        return .unknown
    }

    nonisolated private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}

enum LocalAnswerEngine {
    nonisolated static func answer(for context: ChatOrchestrationContext, now: Date = Date()) -> String? {
        switch context.intent {
        case .groupInfo:
            return groupInfoAnswer(context.group)
        case .currentLesson:
            return currentLessonAnswer(context.scheduleItems, now: now)
        case .todaySchedule:
            return scheduleAnswer(context.scheduleItems, title: "Сегодня")
        case .tomorrowSchedule:
            return scheduleAnswer(context.scheduleItems, title: "Завтра")
        case .exams:
            return examsAnswer(context.exams, now: now)
        case .homework:
            return homeworkAnswer(context.homeworks)
        case .smallTalk, .unknown:
            return nil
        }
    }

    nonisolated private static func groupInfoAnswer(_ group: UserGroupContext?) -> String {
        guard let group else {
            return "Группа пока не выбрана."
        }
        if let name = group.displayName {
            return "Ты из группы \(name)."
        }
        return "У меня есть только технический ID твоей группы - \(group.id). Название группы пока не загружено."
    }

    nonisolated private static func currentLessonAnswer(_ items: [AIScheduleLessonContext], now: Date) -> String {
        let timed = items.compactMap { TimedScheduleItem(item: $0) }.sorted { $0.start < $1.start }
        if timed.isEmpty {
            return "На сегодня в локальном расписании пар не нашла."
        }
        if let active = timed.first(where: { $0.start <= now && now <= $0.end }) {
            let next = timed.first(where: { $0.start > active.end })
            var answer = "Сейчас идёт: \(lessonLine(active.item))."
            if let next {
                answer += "\nСледующая: \(lessonLine(next.item))."
            }
            return answer
        }
        if let next = timed.first(where: { $0.start > now }) {
            return "Сейчас пары нет. Следующая: \(lessonLine(next.item))."
        }
        return "На сегодня пары уже закончились."
    }

    nonisolated private static func scheduleAnswer(_ items: [AIScheduleLessonContext], title: String) -> String {
        guard !items.isEmpty else {
            return "\(title) в локальном расписании пар не нашла."
        }
        let lines = items.prefix(10).map { "- \(lessonLine($0))" }
        return "\(title):\n\(lines.joined(separator: "\n"))"
    }

    nonisolated private static func examsAnswer(_ items: [AIScheduleLessonContext], now: Date) -> String? {
        let upcoming = upcomingExamItems(from: items, now: now)
        guard !upcoming.isEmpty else {
            return "По локальным данным по сессии больше ничего не осталось."
        }
        let lines = upcoming.prefix(8).map { "- \(examLine($0))" }
        return "По сессии осталось:\n\(lines.joined(separator: "\n"))"
    }

    nonisolated private static func homeworkAnswer(_ homeworks: [AIHomeworkContext]) -> String? {
        guard !homeworks.isEmpty else { return nil }
        let lines = homeworks.prefix(8).map { homework in
            "- \(homework.lessonDate) \(homework.lessonTime), \(homework.subject): \(homework.text)"
        }
        return "Домашка:\n\(lines.joined(separator: "\n"))"
    }

    nonisolated static func lessonLine(_ item: AIScheduleLessonContext) -> String {
        var parts = ["\(item.time) \(item.title)"]
        if !trimmed(item.lessonType).isEmpty {
            parts.append(item.lessonType)
        }
        if !trimmed(item.teacher).isEmpty {
            parts.append(item.teacher)
        }
        if !trimmed(item.room).isEmpty {
            parts.append("ауд. \(item.room)")
        } else if !trimmed(item.address).isEmpty {
            parts.append(item.address)
        }
        return parts.joined(separator: ", ")
    }

    nonisolated static func examLine(_ item: AIScheduleLessonContext) -> String {
        var parts = [examDateText(for: item), item.time, item.title]
        if !trimmed(item.lessonType).isEmpty {
            parts.append(item.lessonType)
        }
        if !trimmed(item.teacher).isEmpty {
            parts.append(item.teacher)
        }
        if !trimmed(item.room).isEmpty {
            parts.append("ауд. \(item.room)")
        } else if !trimmed(item.address).isEmpty {
            parts.append(item.address)
        }
        return parts
            .map(trimmed)
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    nonisolated static func upcomingExamItems(from items: [AIScheduleLessonContext], now: Date) -> [AIScheduleLessonContext] {
        items
            .filter { item in
                guard let end = date(from: item.endISO) ?? date(from: item.startISO) else {
                    return true
                }
                return end >= now
            }
            .sorted { first, second in
                let firstDate = date(from: first.startISO) ?? .distantFuture
                let secondDate = date(from: second.startISO) ?? .distantFuture
                return firstDate < secondDate
            }
    }

    private struct TimedScheduleItem {
        let item: AIScheduleLessonContext
        let start: Date
        let end: Date

        init?(item: AIScheduleLessonContext) {
            guard let start = LocalAnswerEngine.isoFormatter.date(from: item.startISO) ?? LocalAnswerEngine.fallbackFormatter.date(from: item.startISO) else {
                return nil
            }
            self.item = item
            self.start = start
            self.end = LocalAnswerEngine.isoFormatter.date(from: item.endISO) ?? LocalAnswerEngine.fallbackFormatter.date(from: item.endISO) ?? start
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackFormatter = ISO8601DateFormatter()

    nonisolated private static func examDateText(for item: AIScheduleLessonContext) -> String {
        if !trimmed(item.period).isEmpty {
            return item.period
        }
        guard let date = date(from: item.startISO) else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    nonisolated private static func date(from value: String) -> Date? {
        isoFormatter.date(from: value) ?? fallbackFormatter.date(from: value)
    }

    nonisolated private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ContextSelector {
    nonisolated static func packets(for context: ChatOrchestrationContext) -> [ContextPacket] {
        var packets: [ContextPacket] = [
            ContextPacket(name: "system rules", priority: 100, maxChars: 350, content: systemRules(for: context.personaRawValue)),
            ContextPacket(name: "user message", priority: 95, maxChars: 400, content: "Сообщение пользователя:\n\(context.userMessage)")
        ]

        if let group = context.group, shouldIncludeGroup(for: context.intent) {
            packets.append(ContextPacket(name: "exact user facts", priority: 90, maxChars: 250, content: groupContext(group)))
        }

        if let appData = relevantAppData(for: context), !appData.isEmpty {
            packets.append(ContextPacket(name: "relevant app data", priority: 70, maxChars: 450, content: appData))
        }

        if shouldIncludeSummary(for: context.intent),
           let summary = context.dialog.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty {
            packets.append(ContextPacket(name: "summary", priority: 50, maxChars: 250, content: "Краткая память:\n\(summary)"))
        }

        if shouldIncludeRecentMessages(for: context.intent) {
            let recent = recentMessages(context.dialog.messages)
            if !recent.isEmpty {
                packets.append(ContextPacket(name: "recent messages", priority: 30, maxChars: 300, content: recent))
            }
        }

        packets.append(ContextPacket(name: "optional personality", priority: 10, maxChars: 100, content: personalityHint(for: context.personaRawValue)))
        return packets
    }

    nonisolated static func systemRules(for personaRawValue: String) -> String {
        let name = personaRawValue == "stesha" ? "Стеша" : "Помощник МПГУ"
        return """
        Ты - \(name), AI-помощница в приложении MyMPSU.
        Отвечай только на русском языке, если пользователь явно не попросил другой язык.
        Будь дружелюбной, но не выдумывай факты.
        Данные расписания, группы, экзаменов и домашки используй только из переданного контекста.
        Если данных нет - честно скажи, что данных нет.
        Технический ID группы не является названием группы.
        """
    }

    nonisolated static func emergencyPrompt(userMessage: String, personaRawValue: String) -> String {
        let name = personaRawValue == "stesha" ? "Стеша" : "Помощник МПГУ"
        return """
        Ты - \(name), помощница MyMPSU. Отвечай только на русском. Кратко. Не выдумывай данные. Если данных нет - скажи честно.
        Сообщение пользователя:
        \(userMessage)
        """
    }

    nonisolated private static func shouldIncludeGroup(for intent: ChatIntent) -> Bool {
        switch intent {
        case .smallTalk:
            return false
        default:
            return true
        }
    }

    nonisolated private static func shouldIncludeSummary(for intent: ChatIntent) -> Bool {
        switch intent {
        case .smallTalk, .groupInfo, .todaySchedule, .tomorrowSchedule, .currentLesson, .exams, .homework:
            return false
        case .unknown:
            return true
        }
    }

    nonisolated private static func shouldIncludeRecentMessages(for intent: ChatIntent) -> Bool {
        switch intent {
        case .unknown, .smallTalk:
            return true
        default:
            return false
        }
    }

    nonisolated private static func groupContext(_ group: UserGroupContext) -> String {
        var lines = ["Технический ID группы: \(group.id). Это не название группы."]
        if let name = group.displayName {
            lines.append("Название выбранной группы: \(name).")
        } else {
            lines.append("Название группы пока не загружено.")
        }
        if let faculty = group.facultyName?.trimmingCharacters(in: .whitespacesAndNewlines), !faculty.isEmpty {
            lines.append("Факультет/институт: \(faculty).")
        }
        if let program = group.programName?.trimmingCharacters(in: .whitespacesAndNewlines), !program.isEmpty {
            lines.append("Программа: \(program).")
        }
        return lines.joined(separator: "\n")
    }

    nonisolated private static func relevantAppData(for context: ChatOrchestrationContext) -> String? {
        switch context.intent {
        case .todaySchedule, .tomorrowSchedule:
            return scheduleData(context.scheduleItems)
        case .currentLesson:
            return scheduleData(Array(context.scheduleItems.prefix(4)))
        case .exams:
            return examsData(context.exams)
        case .homework:
            return homeworkData(context.homeworks)
        case .groupInfo, .smallTalk, .unknown:
            return nil
        }
    }

    nonisolated private static func scheduleData(_ items: [AIScheduleLessonContext]) -> String? {
        guard !items.isEmpty else { return "Локальных данных расписания для запроса нет." }
        return items.prefix(10).map { "- \(LocalAnswerEngine.lessonLine($0))" }.joined(separator: "\n")
    }

    nonisolated private static func examsData(_ items: [AIScheduleLessonContext]) -> String? {
        let upcoming = LocalAnswerEngine.upcomingExamItems(from: items, now: Date())
        guard !upcoming.isEmpty else { return "По локальным данным по сессии больше ничего не осталось." }
        return upcoming.prefix(8).map { "- \(LocalAnswerEngine.examLine($0))" }.joined(separator: "\n")
    }

    nonisolated private static func homeworkData(_ homeworks: [AIHomeworkContext]) -> String? {
        guard !homeworks.isEmpty else { return "Локальных данных домашки для запроса нет." }
        return homeworks.prefix(8).map { homework in
            "- \(homework.lessonDate) \(homework.lessonTime), \(homework.subject): \(homework.text)"
        }.joined(separator: "\n")
    }

    nonisolated private static func recentMessages(_ messages: [PelikashaPromptMessage]) -> String {
        messages
            .filter { $0.role == "user" || $0.role == "assistant" }
            .suffix(6)
            .map { "\($0.role == "user" ? "Пользователь" : "Ассистент"): \($0.text)" }
            .joined(separator: "\n")
    }

    nonisolated private static func personalityHint(for personaRawValue: String) -> String {
        personaRawValue == "stesha" ? "Стиль: спокойно, бережно, без лишних приветствий." : "Стиль: живо, кратко, полезно, без лишних приветствий."
    }
}

enum ContextBudgeter {
    nonisolated static func buildPrompt(
        packets: [ContextPacket],
        limits: AIPlanLimits = .base,
        emergencyUserMessage: String,
        personaRawValue: String
    ) -> ContextBudgetResult {
        let safeMax = limits.safeMax
        let sorted = packets.sorted {
            if $0.priority == $1.priority { return $0.name < $1.name }
            return $0.priority > $1.priority
        }

        var selected: [ContextPacket] = []
        var used = 0

        for packet in sorted {
            let content = compact(packet.content, limit: packet.maxChars)
            guard !content.isEmpty else { continue }
            let section = "\(packet.name):\n\(content)"
            let sectionLength = section.count + (selected.isEmpty ? 0 : 2)
            if used + sectionLength <= safeMax {
                selected.append(ContextPacket(name: packet.name, priority: packet.priority, maxChars: packet.maxChars, content: content))
                used += sectionLength
            }
        }

        let prompt = selected
            .map { "\($0.name):\n\($0.content)" }
            .joined(separator: "\n\n")

        if !prompt.isEmpty && prompt.count <= safeMax {
            return ContextBudgetResult(prompt: prompt, packets: selected, usedEmergencyPrompt: false)
        }

        let emergency = compact(ContextSelector.emergencyPrompt(userMessage: emergencyUserMessage, personaRawValue: personaRawValue), limit: safeMax)
        return ContextBudgetResult(prompt: emergency, packets: [], usedEmergencyPrompt: true)
    }

    nonisolated private static func compact(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let suffix = "..."
        return String(normalized.prefix(max(0, limit - suffix.count))) + suffix
    }
}

enum AIResponseValidator {
    nonisolated static func validate(
        _ text: String,
        userMessage: String,
        group: UserGroupContext?
    ) -> AIValidationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AIValidationResult(isValid: false, reason: "empty")
        }
        if containsRawBackendError(trimmed) {
            return AIValidationResult(isValid: false, reason: "raw backend error")
        }
        if containsCJK(trimmed), !userAskedForForeignLanguage(userMessage) {
            return AIValidationResult(isValid: false, reason: "cjk")
        }
        if namesGroupIdAsName(trimmed, userMessage: userMessage, group: group) {
            return AIValidationResult(isValid: false, reason: "group id as name")
        }
        return AIValidationResult(isValid: true, reason: nil)
    }

    nonisolated static func containsCJK(_ text: String) -> Bool {
        text.range(
            of: #"[\u{4E00}-\u{9FFF}\u{3040}-\u{30FF}\u{AC00}-\u{D7AF}]"#,
            options: .regularExpression
        ) != nil
    }

    nonisolated private static func containsRawBackendError(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("api request failed")
            || lowered.contains("\"detail\"")
            || lowered.contains("http 400")
            || lowered.contains("http 401")
            || lowered.contains("http 403")
            || lowered.contains("http 500")
    }

    nonisolated private static func userAskedForForeignLanguage(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("на английском")
            || lowered.contains("на китайском")
            || lowered.contains("переведи")
            || lowered.contains("translate")
    }

    nonisolated private static func namesGroupIdAsName(_ text: String, userMessage: String, group: UserGroupContext?) -> Bool {
        guard let group, group.displayName == nil else { return false }
        let id = String(group.id)
        let lowered = text.lowercased()
        let asksGroup = userMessage.lowercased().contains("групп")
        return asksGroup && lowered.contains(id) && (lowered.contains("называ") || lowered.contains("твоя группа") || lowered.contains("ты из группы"))
    }
}

enum PelikashaPromptBuilder {
    nonisolated static let recentMessageLimit = 12

    nonisolated static func buildMessages(
        personaRawValue: String,
        dialog: PelikashaPromptDialog,
        scheduleContext: String? = nil
    ) -> [AssistantChatMessagePayload] {
        var result: [AssistantChatMessagePayload] = [
            AssistantChatMessagePayload(role: "system", content: systemPrompt(for: personaRawValue))
        ]

        if dialog.messages.contains(where: { $0.role == "assistant" }) {
            result.append(
                AssistantChatMessagePayload(
                    role: "system",
                    content: "Это уже начатый диалог. Не пиши приветствие, не представляйся заново и не начинай разговор сначала. Ответь сразу по сути последнего сообщения пользователя."
                )
            )
        }

        if let summary = trimmed(dialog.summary), !summary.isEmpty {
            result.append(
                AssistantChatMessagePayload(
                    role: "system",
                    content: """
                    Краткая память предыдущей части диалога. Используй её как контекст, но не пересказывай пользователю без необходимости:
                    \(summary)
                    """
                )
            )
        }

        if let scheduleContext = trimmed(scheduleContext), !scheduleContext.isEmpty {
            result.append(
                AssistantChatMessagePayload(
                    role: "system",
                    content: """
                    Контекст расписания из приложения MyMPSU. Используй его для вопросов о парах, занятиях, аудиториях, преподавателях и плане на день. Если в контексте сказано, что данных нет, не выдумывай пары.
                    \(scheduleContext)
                    """
                )
            )
        }

        let recentMessages = dialog.messages
            .filter { $0.role == "user" || $0.role == "assistant" }
            .suffix(recentMessageLimit)

        result.append(contentsOf: recentMessages.map { message in
            AssistantChatMessagePayload(role: message.role, content: message.text)
        })

        return result
    }

    nonisolated static func legacyMessage(
        from messages: [AssistantChatMessagePayload],
        maxCharacters: Int = 1_800
    ) -> String {
        let systemMessages = messages
            .filter { $0.role == "system" }
            .map(\.content)
        let systemContent = compactSystemContent(systemMessages, limit: min(850, maxCharacters / 2))
        let conversationMessages = messages.filter { $0.role != "system" }

        let systemSection = """
        [SYSTEM]
        \(systemContent)
        """

        var sections = [systemSection]
        var usedCharacters = systemSection.count

        for message in conversationMessages.reversed() {
            let section = formattedSection(for: message)
            let separatorLength = sections.isEmpty ? 0 : 2
            if usedCharacters + separatorLength + section.count <= maxCharacters {
                sections.insert(section, at: 1)
                usedCharacters += separatorLength + section.count
            } else if sections.count == 1, let compacted = compactSection(for: message, limit: maxCharacters - usedCharacters - separatorLength) {
                sections.append(compacted)
                usedCharacters += separatorLength + compacted.count
            }
        }

        let result = sections.joined(separator: "\n\n")
        guard result.count > maxCharacters else { return result }
        return compact(result, limit: maxCharacters)
    }

    nonisolated private static func systemPrompt(for personaRawValue: String) -> String {
        let personaPrompt: String
        switch personaRawValue {
        case "stesha":
            personaPrompt = """
            Ты Стеша, спокойный и поддерживающий AI-помощник студентов МПГУ. Отвечай по-русски мягко, ясно и бережно. Помогай структурировать задачи, понимать расписание и снижать тревожность.
            """
        default:
            personaPrompt = """
            Ты Помощник МПГУ, живой и дружелюбный AI-помощник студентов МПГУ. Отвечай по-русски, кратко и полезно. Помогай с расписанием, учебными вопросами и навигацией по приложению.
            """
        }

        return """
        \(personaPrompt)

        Если это не первое сообщение в диалоге, не начинай разговор заново и не повторяй приветствие. Продолжай контекст естественно.
        Не здоровайся в каждом ответе. Не выдумывай расписание или факты; если данных не хватает, честно скажи об этом и предложи, что проверить.
        Если пользователь спрашивает, из какой он группы, называй человекочитаемое название выбранной группы из контекста. Не отвечай внутренним ID группы, если пользователь прямо не просит ID.
        Отвечай только на русском языке. Не переходи на китайский, английский или другой язык, если пользователь прямо не попросил перевод или ответ на другом языке.
        Не вставляй иностранный текст, служебные фразы, рассуждения о внутренних функциях или технический мусор.
        """
    }

    nonisolated private static func trimmed(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func formattedSection(for message: AssistantChatMessagePayload) -> String {
        let label: String
        switch message.role {
        case "assistant":
            label = "ASSISTANT"
        case "user":
            label = "USER"
        default:
            label = message.role.uppercased()
        }
        return "[\(label)]\n\(message.content)"
    }

    nonisolated private static func compactSection(for message: AssistantChatMessagePayload, limit: Int) -> String? {
        guard limit > 32 else { return nil }
        let role = message.role == "assistant" ? "ASSISTANT" : "USER"
        let labelLength = "[\(role)]\n".count
        let contentLimit = max(0, limit - labelLength)
        return "[\(role)]\n\(compact(message.content, limit: contentLimit))"
    }

    nonisolated private static func compactSystemContent(_ messages: [String], limit: Int) -> String {
        guard !messages.isEmpty else { return "" }
        guard messages.count > 1 else { return compact(messages[0], limit: limit) }

        let primaryLimit = max(240, limit / 3)
        let contextLimit = max(240, limit - primaryLimit - 1)
        let primary = compact(messages[0], limit: primaryLimit)
        let context = compact(messages.dropFirst().joined(separator: " "), limit: contextLimit)
        return [primary, context]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    nonisolated private static func compact(_ value: String, limit: Int) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > limit else { return normalized }
        let suffix = "..."
        return String(normalized.prefix(max(0, limit - suffix.count))) + suffix
    }
}

enum PelikashaConversationSummaryService {
    nonisolated static let recentMessageLimit = 6
    nonisolated static let minimumUnsummarizedMessages = 10

    nonisolated static func summarizeIfNeeded(_ dialog: PelikashaPromptDialog) -> PelikashaSummaryResult? {
        let conversationalMessages = dialog.messages.filter { $0.role == "user" || $0.role == "assistant" }
        let summarizedIDs = Set(dialog.summarizedMessageIDs)
        let unsummarized = conversationalMessages.filter { !summarizedIDs.contains($0.id) }

        guard unsummarized.count > minimumUnsummarizedMessages else {
            return nil
        }

        let messagesToSummarize = Array(unsummarized.dropLast(recentMessageLimit))
        guard !messagesToSummarize.isEmpty else {
            return nil
        }

        let summary = mergedSummary(existing: dialog.summary, messages: messagesToSummarize)
        guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return PelikashaSummaryResult(
            summary: summary,
            summarizedMessageIDs: Array(summarizedIDs.union(messagesToSummarize.map(\.id)))
        )
    }

    nonisolated private static func mergedSummary(existing: String?, messages: [PelikashaPromptMessage]) -> String {
        var sections: [String] = []
        if let existing = existing?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            sections.append(existing)
        }

        let compactLines = messages
            .compactMap(summaryFactLine(for:))
            .prefix(8)

        if !compactLines.isEmpty {
            sections.append(
                """
                Обновление памяти:
                \(compactLines.joined(separator: "\n"))
                """
            )
        }

        let summary = sections
            .joined(separator: "\n\n")
            .split(separator: "\n")
            .prefix(20)
            .joined(separator: "\n")
        return String(summary.prefix(500))
    }

    nonisolated private static func summaryFactLine(for message: PelikashaPromptMessage) -> String? {
        let text = message.text
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return nil }

        switch message.role {
        case "user":
            if text.lowercased().contains("групп") {
                return "- Тема: пользователь спрашивал о группе."
            }
            if ChatIntentDetector.detectIntent(text) != .smallTalk {
                return "- Текущая тема: \(String(text.prefix(140)))"
            }
            return nil
        case "assistant":
            if text.lowercased().contains("технический id") {
                return "- Важно: технический ID группы нельзя называть названием группы."
            }
            return nil
        default:
            return nil
        }
    }
}
