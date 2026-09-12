import Foundation
internal import Combine

@MainActor
final class PelikashaChatViewModel: ObservableObject {
    struct DialogRecord: Identifiable, Codable, Equatable {
        let id: UUID
        var title: String
        var messages: [PelikashaMessage]
        var updatedAt: Date
        var summary: String?
        var summarizedMessageIDs: [UUID]?
    }

    private struct ScheduleContext {
        let text: String?
        let cachedPayload: CachedSchedulePayload?
    }

    private struct LocalContextData {
        let scheduleItems: [ScheduleItem]
        let exams: [ScheduleItem]
        let homeworks: [Homework]
        let cachedSchedule: CachedSchedulePayload?
    }

    @Published var messages: [PelikashaMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var isCancelling = false
    @Published var selectedPersona: AssistantPersona {
        didSet {
            UserDefaults.standard.set(selectedPersona.rawValue, forKey: "assistantDefaultPersona")
        }
    }
    @Published var remaining: Int?
    @Published private(set) var history: [DialogRecord] = []
    @Published private(set) var currentDialogID: UUID = UUID()

    private let selectedDateProvider: () -> Date?
    private var currentTask: Task<Void, Never>?
    private var lastUserMessage: String?
    private let historyKey = "pelikashaChatHistory"
    private let activeDialogIDKey = "pelikashaActiveDialogID"

    init(selectedDateProvider: @escaping () -> Date? = { nil }) {
        self.selectedDateProvider = selectedDateProvider
        let rawPersona = UserDefaults.standard.string(forKey: "assistantDefaultPersona")
        self.selectedPersona = AssistantPersona(rawValue: rawPersona ?? "") ?? .pelikasha
        history = Self.loadHistory(key: historyKey)
        if let activeID = Self.loadActiveDialogID(key: activeDialogIDKey),
           let activeDialog = history.first(where: { $0.id == activeID }) {
            applyActiveDialog(activeDialog)
        } else if let first = history.first {
            applyActiveDialog(first)
        } else {
            persistCurrentDialog(title: "Новый диалог")
        }
    }

    func sendMessage() {
        let text = inputText.mympsuTrimmed
        guard !text.isEmpty, !isLoading else { return }
        inputText = ""
        ensureActiveConversation()
        messages.append(PelikashaMessage(role: .user, text: text))
        lastUserMessage = text
        let dialog = persistCurrentDialog()
        send(promptDialog: promptDialog(from: dialog))
    }

    func retryLastMessage() {
        guard !isLoading, lastUserMessage != nil else { return }
        messages.removeAll { $0.role == .systemLocal }
        let dialog = persistCurrentDialog()
        send(promptDialog: promptDialog(from: dialog))
    }

    func appendLocalSystemMessage(_ text: String) {
        messages.append(PelikashaMessage(role: .systemLocal, text: text))
        persistCurrentDialog()
    }

    func cancelCurrentRequest() {
        isCancelling = true
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        isCancelling = false
    }

    func startNewDialog() {
        cancelCurrentRequest()
        currentDialogID = UUID()
        saveActiveDialogID()
        messages = []
        lastUserMessage = nil
        persistCurrentDialog(title: "Новый диалог")
    }

    func openDialog(id: UUID) {
        guard let dialog = history.first(where: { $0.id == id }) else { return }
        cancelCurrentRequest()
        applyActiveDialog(dialog)
    }

    func deleteDialog(id: UUID) {
        history.removeAll { $0.id == id }
        if currentDialogID == id {
            if let latest = history.first {
                applyActiveDialog(latest)
            } else {
                currentDialogID = UUID()
                saveActiveDialogID()
                messages = []
                lastUserMessage = nil
                persistCurrentDialog(title: "Новый диалог")
            }
        }
        saveHistory()
    }

    func clearHistory() {
        history = []
        currentDialogID = UUID()
        saveActiveDialogID()
        messages = []
        lastUserMessage = nil
        saveHistory()
        persistCurrentDialog(title: "Новый диалог")
    }

    private func send(promptDialog: PelikashaPromptDialog) {
        currentTask?.cancel()
        isLoading = true
        let persona = selectedPersona
        let targetDateValue = selectedDateProvider() ?? Date()
        let targetDate = Self.dateString(targetDateValue)
        let groupId = Self.selectedGroupId
        let groupName = Self.selectedGroupName
        let groupContext = Self.selectedGroupContext(id: groupId, name: groupName)
        let userMessage = promptDialog.messages.last(where: { $0.role == "user" })?.text ?? ""
        let intent = ChatIntentDetector.detectIntent(userMessage)
        currentTask = Task { [weak self] in
            do {
                let localData = await Self.loadLocalContext(
                    intent: intent,
                    groupId: groupId,
                    date: targetDateValue
                )
                let orchestrationContext = ChatOrchestrationContext(
                    intent: intent,
                    personaRawValue: persona.rawValue,
                    userMessage: userMessage,
                    group: groupContext,
                    targetDate: targetDateValue,
                    scheduleItems: localData.scheduleItems.map(Self.aiScheduleLesson),
                    exams: localData.exams.map(Self.aiScheduleLesson),
                    homeworks: localData.homeworks.map(Self.aiHomework),
                    dialog: promptDialog
                )

                Self.debugLog("intent=\(intent), localSchedule=\(localData.scheduleItems.count), exams=\(localData.exams.count), homeworks=\(localData.homeworks.count)")

                if let localAnswer = LocalAnswerEngine.answer(for: orchestrationContext) {
                    guard !Task.isCancelled else { return }
                    Self.debugLog("localAnswer=true")
                    self?.messages.append(PelikashaMessage(role: .assistant, text: localAnswer, persona: persona))
                    self?.persistCurrentDialog()
                    self?.summarizeCurrentDialogIfNeeded()
                    self?.isLoading = false
                    self?.currentTask = nil
                    return
                }

                let packets = ContextSelector.packets(for: orchestrationContext)
                let budget = ContextBudgeter.buildPrompt(
                    packets: packets,
                    emergencyUserMessage: userMessage,
                    personaRawValue: persona.rawValue
                )
                Self.debugLog(
                    "localAnswer=false, packets=\(budget.packets.map(\.name)), promptChars=\(budget.prompt.count), emergency=\(budget.usedEmergencyPrompt)"
                )

                let response = try await Self.sendAIRequest(
                    prompt: budget.prompt,
                    persona: persona,
                    conversationId: self?.currentDialogID.uuidString,
                    groupId: groupId,
                    groupName: groupName,
                    targetDate: targetDate,
                    cachedSchedule: localData.cachedSchedule
                )
                let validatedReply = try await Self.validatedReply(
                    response.reply,
                    userMessage: userMessage,
                    persona: persona,
                    conversationId: self?.currentDialogID.uuidString,
                    groupId: groupId,
                    groupName: groupName,
                    targetDate: targetDate,
                    groupContext: groupContext
                )

                guard !Task.isCancelled else { return }
                self?.remaining = response.remaining
                self?.messages.append(PelikashaMessage(role: .assistant, text: validatedReply, persona: persona))
                self?.persistCurrentDialog()
                self?.summarizeCurrentDialogIfNeeded()
            } catch {
                guard !Task.isCancelled else { return }
                Self.debugLog("error=\(String(describing: error))")
                if let retryReply = try? await Self.retryEmergencyAfterError(
                    error,
                    userMessage: userMessage,
                    persona: persona,
                    conversationId: self?.currentDialogID.uuidString,
                    groupId: groupId,
                    groupName: groupName,
                    targetDate: targetDate,
                    groupContext: groupContext
                ) {
                    self?.messages.append(PelikashaMessage(role: .assistant, text: retryReply, persona: persona))
                    self?.persistCurrentDialog()
                    self?.summarizeCurrentDialogIfNeeded()
                } else {
                    self?.appendLocalSystemMessage(Self.errorMessage(for: error))
                }
            }
            self?.isLoading = false
            self?.currentTask = nil
        }
    }

    private static func sendAIRequest(
        prompt: String,
        persona: AssistantPersona,
        conversationId: String?,
        groupId: Int?,
        groupName: String?,
        targetDate: String,
        cachedSchedule: CachedSchedulePayload?
    ) async throws -> AssistantChatResponsePayload {
        try await AssistantAPIService.shared.sendChatMessage(
            message: prompt,
            persona: persona,
            messages: [AssistantChatMessagePayload(role: "user", content: prompt)],
            conversationId: conversationId,
            groupId: groupId,
            groupName: groupName,
            targetDate: targetDate,
            cachedSchedule: cachedSchedule
        )
    }

    private static func validatedReply(
        _ reply: String,
        userMessage: String,
        persona: AssistantPersona,
        conversationId: String?,
        groupId: Int?,
        groupName: String?,
        targetDate: String,
        groupContext: UserGroupContext?
    ) async throws -> String {
        let validation = AIResponseValidator.validate(reply, userMessage: userMessage, group: groupContext)
        debugLog("responseValidation=\(validation.isValid), reason=\(validation.reason ?? "ok")")
        guard !validation.isValid else { return reply }

        let emergency = ContextSelector.emergencyPrompt(userMessage: userMessage, personaRawValue: persona.rawValue)
        let retry = try await sendAIRequest(
            prompt: String(emergency.prefix(1_800)),
            persona: persona,
            conversationId: conversationId,
            groupId: groupId,
            groupName: groupName,
            targetDate: targetDate,
            cachedSchedule: nil
        )
        let retryValidation = AIResponseValidator.validate(retry.reply, userMessage: userMessage, group: groupContext)
        debugLog("responseValidationRetry=\(retryValidation.isValid), reason=\(retryValidation.reason ?? "ok")")
        return retryValidation.isValid ? retry.reply : "Я сбилась с ответа. Попробуй спросить ещё раз чуть короче."
    }

    private static func retryEmergencyAfterError(
        _ error: Error,
        userMessage: String,
        persona: AssistantPersona,
        conversationId: String?,
        groupId: Int?,
        groupName: String?,
        targetDate: String,
        groupContext: UserGroupContext?
    ) async throws -> String? {
        guard isPromptTooLongError(error) else { return nil }
        let emergency = String(ContextSelector.emergencyPrompt(userMessage: userMessage, personaRawValue: persona.rawValue).prefix(1_800))
        debugLog("promptTooLong=true, retryEmergency=true, promptChars=\(emergency.count)")
        let response = try await sendAIRequest(
            prompt: emergency,
            persona: persona,
            conversationId: conversationId,
            groupId: groupId,
            groupName: groupName,
            targetDate: targetDate,
            cachedSchedule: nil
        )
        let validation = AIResponseValidator.validate(response.reply, userMessage: userMessage, group: groupContext)
        return validation.isValid ? response.reply : "Я сократила контекст, но всё равно сбилась с ответа. Попробуй спросить ещё раз чуть короче."
    }

    private static func loadLocalContext(intent: ChatIntent, groupId: Int?, date: Date) async -> LocalContextData {
        guard let groupId else {
            return LocalContextData(scheduleItems: [], exams: [], homeworks: [], cachedSchedule: nil)
        }

        let groupIdString = String(groupId)
        switch intent {
        case .currentLesson, .todaySchedule:
            let items = await APIService.shared.fetchSchedule(for: groupIdString, date: date)
            return LocalContextData(
                scheduleItems: items,
                exams: [],
                homeworks: [],
                cachedSchedule: items.isEmpty ? nil : PelikashaScheduleContextBuilder.cachedSchedule(from: items, date: date)
            )
        case .tomorrowSchedule:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            let items = await APIService.shared.fetchSchedule(for: groupIdString, date: tomorrow)
            return LocalContextData(
                scheduleItems: items,
                exams: [],
                homeworks: [],
                cachedSchedule: items.isEmpty ? nil : PelikashaScheduleContextBuilder.cachedSchedule(from: items, date: tomorrow)
            )
        case .exams:
            let exams = await APIService.shared.fetchSchedule(for: groupIdString, date: date, examOnly: true)
            return LocalContextData(scheduleItems: [], exams: exams, homeworks: [], cachedSchedule: nil)
        case .homework:
            let homeworks = (try? await APIService.shared.fetchGroupHomeworks(groupId: groupId, date: dateString(date))) ?? []
            return LocalContextData(scheduleItems: [], exams: [], homeworks: homeworks, cachedSchedule: nil)
        case .smallTalk, .groupInfo, .unknown:
            return LocalContextData(scheduleItems: [], exams: [], homeworks: [], cachedSchedule: nil)
        }
    }

    private static func selectedGroupContext(id: Int?, name: String?) -> UserGroupContext? {
        guard let id else { return nil }
        return UserGroupContext(id: id, name: name, facultyName: nil, programName: nil)
    }

    private static func aiScheduleLesson(from item: ScheduleItem) -> AIScheduleLessonContext {
        AIScheduleLessonContext(
            startISO: item.sortDateISO,
            endISO: item.endDateISO,
            time: item.time,
            title: item.title,
            teacher: item.teacher,
            lessonType: item.lessonType,
            address: item.address,
            subgroup: item.subgroup,
            period: item.period,
            room: item.room,
            classURL: item.classURL
        )
    }

    private static func aiHomework(from homework: Homework) -> AIHomeworkContext {
        AIHomeworkContext(
            lessonDate: homework.lessonDate,
            lessonTime: homework.lessonTime,
            subject: homework.subject,
            teacher: homework.teacher,
            room: homework.room,
            text: homework.text
        )
    }

    private static func isPromptTooLongError(_ error: Error) -> Bool {
        if case APIServiceError.httpStatusWithBody(let statusCode, let body) = error {
            let body = body?.lowercased() ?? ""
            return statusCode == 400 && (body.contains("слишком длин") || body.contains("too long"))
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            return statusCode == 400
        }
        return false
    }

    private static func debugLog(_ message: String) {
#if DEBUG
        print("[PelikashaOrchestrator] \(message)")
#endif
    }

    @discardableResult
    private func persistCurrentDialog(title explicitTitle: String? = nil) -> DialogRecord {
        let title = explicitTitle ?? messages.first(where: { $0.role == .user })?.text ?? "Новый диалог"
        let trimmedTitle = Self.normalizedDialogTitle(title)
        let existing = history.first { $0.id == currentDialogID }
        let record = DialogRecord(
            id: currentDialogID,
            title: trimmedTitle,
            messages: messages,
            updatedAt: Date(),
            summary: existing?.summary,
            summarizedMessageIDs: existing?.summarizedMessageIDs
        )
        history.removeAll { $0.id == currentDialogID }
        history.insert(record, at: 0)
        history = Array(history.prefix(25))
        saveActiveDialogID()
        saveHistory()
        return record
    }

    private func summarizeCurrentDialogIfNeeded() {
        guard let current = history.first(where: { $0.id == currentDialogID }) else { return }
        guard let summaryResult = PelikashaConversationSummaryService.summarizeIfNeeded(promptDialog(from: current)) else { return }
        var updated = current
        updated.summary = summaryResult.summary
        updated.summarizedMessageIDs = summaryResult.summarizedMessageIDs
        history.removeAll { $0.id == currentDialogID }
        history.insert(updated, at: 0)
        saveHistory()
    }

    private func promptDialog(from dialog: DialogRecord) -> PelikashaPromptDialog {
        PelikashaPromptDialog(
            messages: dialog.messages.map { message in
                PelikashaPromptMessage(id: message.id, role: message.role.rawValue, text: message.text)
            },
            summary: dialog.summary,
            summarizedMessageIDs: dialog.summarizedMessageIDs ?? []
        )
    }

    private func saveHistory() {
        if let data = try? MyMPSUBackendSystem.jsonEncoder.encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func saveActiveDialogID() {
        UserDefaults.standard.set(currentDialogID.uuidString, forKey: activeDialogIDKey)
    }

    @discardableResult
    private func ensureActiveConversation() -> UUID {
        if history.contains(where: { $0.id == currentDialogID }) {
            saveActiveDialogID()
            return currentDialogID
        }

        if !messages.isEmpty {
            persistCurrentDialog()
            return currentDialogID
        }

        if let latest = history.first {
            applyActiveDialog(latest)
        } else {
            currentDialogID = UUID()
            saveActiveDialogID()
            persistCurrentDialog(title: "Новый диалог")
        }

        return currentDialogID
    }

    private func applyActiveDialog(_ dialog: DialogRecord) {
        currentDialogID = dialog.id
        saveActiveDialogID()
        messages = dialog.messages
        lastUserMessage = dialog.messages.last(where: { $0.role == .user })?.text
    }

    private static func loadHistory(key: String) -> [DialogRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? MyMPSUBackendSystem.jsonDecoder.decode([DialogRecord].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private static func loadActiveDialogID(key: String) -> UUID? {
        guard let rawValue = UserDefaults.standard.string(forKey: key) else { return nil }
        return UUID(uuidString: rawValue)
    }

    private static func normalizedDialogTitle(_ title: String) -> String {
        let oneLine = title
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
        return oneLine.isEmpty ? "Новый диалог" : String(oneLine.prefix(120))
    }

    private static var selectedGroupId: Int? {
        let sharedValue = UserDefaults(suiteName: "group.mympsu.shared")?.string(forKey: "selectedGroupId")
        let value = sharedValue ?? UserDefaults.standard.string(forKey: "selectedGroupId") ?? ""
        return Int(value)
    }

    private static var selectedGroupName: String? {
        let sharedValue = UserDefaults(suiteName: "group.mympsu.shared")?.string(forKey: "selectedGroupName")
        let value = sharedValue ?? UserDefaults.standard.string(forKey: "selectedGroupName")
        let trimmed = value?.mympsuTrimmed ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func scheduleContext(groupId: Int?, groupName: String?, date: Date) async -> ScheduleContext {
        let groupDescription: String
        if let groupName, !groupName.mympsuTrimmed.isEmpty {
            groupDescription = groupName
        } else if let groupId {
            groupDescription = "группа с внутренним ID \(groupId)"
        } else {
            groupDescription = "не выбрана"
        }

        guard let groupId else {
            return ScheduleContext(
                text: "Выбранная группа пользователя: \(groupDescription). Точное расписание пар недоступно, потому что группа не выбрана.",
                cachedPayload: nil
            )
        }

        let groupIdString = String(groupId)
        let items = await APIService.shared.fetchSchedule(for: groupIdString, date: date)
        let readableDate = readableDateString(date)

        guard !items.isEmpty else {
            return ScheduleContext(
                text: """
                Выбранная группа пользователя: \(groupDescription).
                Внутренний ID группы: \(groupIdString). Не называй его пользователю как название группы, если пользователь прямо не просит ID.
                Дата: \(readableDate). В локальном расписании на эту дату пары не найдены.
                """,
                cachedPayload: nil
            )
        }

        let lines = items.map { item in
            var parts = ["- \(item.time): \(item.title)"]
            if !item.lessonType.mympsuTrimmed.isEmpty {
                parts.append("тип: \(item.lessonType)")
            }
            if !item.teacher.mympsuTrimmed.isEmpty {
                parts.append("преподаватель: \(item.teacher)")
            }
            if !item.room.mympsuTrimmed.isEmpty {
                parts.append("аудитория: \(item.room)")
            } else if !item.address.mympsuTrimmed.isEmpty {
                parts.append("адрес: \(item.address)")
            }
            if let subgroup = item.subgroup?.mympsuTrimmed, !subgroup.isEmpty {
                parts.append("подгруппа: \(subgroup)")
            }
            return parts.joined(separator: "; ")
        }

        return ScheduleContext(
            text: """
            Выбранная группа пользователя: \(groupDescription).
            Внутренний ID группы: \(groupIdString). Не называй его пользователю как название группы, если пользователь прямо не просит ID.
            Дата: \(readableDate).
            Пары:
            \(lines.joined(separator: "\n"))
            """,
            cachedPayload: PelikashaScheduleContextBuilder.cachedSchedule(from: items, date: date)
        )
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func readableDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    private static func errorMessage(for error: Error) -> String {
        if isPromptTooLongError(error) {
            return "Сообщение получилось слишком длинным для текущего тарифа. Я сократила контекст - попробуй ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            return errorMessage(forHTTPStatus: statusCode)
        }
        if case APIServiceError.httpStatusWithBody(let statusCode, _) = error {
            return errorMessage(forHTTPStatus: statusCode)
        }
        if let urlError = error as? URLError, urlError.code != .cancelled {
            if urlError.code == .timedOut {
                return "Сервер долго не отвечает. Попробуй ещё раз."
            }
            return "Не удалось подключиться к AI-сервису. Проверь сеть и попробуй ещё раз."
        }
        return "Не удалось получить ответ. Попробуй ещё раз."
    }

    private static func errorMessage(forHTTPStatus statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "Не получилось обработать запрос. Я сократила контекст - попробуй ещё раз."
        case 401, 403:
            return "Похоже, есть проблема с доступом к AI."
        case 500...599:
            return "AI-сервис временно недоступен."
        default:
            return "Не удалось получить ответ. Попробуй ещё раз."
        }
    }
}
