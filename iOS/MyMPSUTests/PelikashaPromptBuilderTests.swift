import Foundation
import Testing
@testable import MyMPSU

@MainActor
struct PelikashaPromptBuilderTests {
    @Test
    func promptBuilderIncludesSummaryAndRecentMessagesOnly() {
        let messages = (0..<30).flatMap { index in
            [
                PelikashaPromptMessage(id: UUID(), role: "user", text: "Вопрос \(index)"),
                PelikashaPromptMessage(id: UUID(), role: "assistant", text: "Ответ \(index)")
            ]
        }
        let dialog = PelikashaPromptDialog(
            messages: messages,
            summary: "Пользователь готовится к сессии.",
            summarizedMessageIDs: []
        )

        let prompt = PelikashaPromptBuilder.buildMessages(personaRawValue: "pelikasha", dialog: dialog)

        #expect(prompt.first?.role == "system")
        #expect(prompt.contains { $0.content.contains("Пользователь готовится к сессии") })
        #expect(prompt.contains { $0.content == "Вопрос 29" })
        #expect(prompt.contains { $0.content == "Ответ 29" })
        #expect(!prompt.contains { $0.content == "Вопрос 0" })
        #expect(prompt.contains { $0.content.contains("Это уже начатый диалог") })
        #expect(prompt.count == 15)
    }

    @Test
    func summaryServiceMarksOnlyOldMessagesAsSummarized() {
        let messages = (0..<26).map { index in
            PelikashaPromptMessage(
                id: UUID(),
                role: index.isMultiple(of: 2) ? "user" : "assistant",
                text: index.isMultiple(of: 2) ? "Из какой я группы? \(index)" : "Технический ID группы нельзя называть названием. \(index)"
            )
        }
        let dialog = PelikashaPromptDialog(
            messages: messages,
            summary: nil,
            summarizedMessageIDs: []
        )

        let summarized = PelikashaConversationSummaryService.summarizeIfNeeded(dialog)

        #expect(summarized?.summary.isEmpty == false)
        #expect((summarized?.summary.count ?? 0) <= 500)
        #expect(summarized?.summarizedMessageIDs.count == 20)
    }

    @Test
    func intentDetectorFindsGroupInfo() {
        #expect(ChatIntentDetector.detectIntent("Из какой я группы?") == .groupInfo)
    }

    @Test
    func contextBudgeterKeepsPromptUnderSafeLimit() {
        let packets = [
            ContextPacket(name: "system rules", priority: 100, maxChars: 350, content: String(repeating: "a", count: 2_000)),
            ContextPacket(name: "user message", priority: 95, maxChars: 400, content: String(repeating: "b", count: 2_000)),
            ContextPacket(name: "recent messages", priority: 30, maxChars: 300, content: String(repeating: "c", count: 2_000))
        ]

        let result = ContextBudgeter.buildPrompt(
            packets: packets,
            emergencyUserMessage: "Привет",
            personaRawValue: "stesha"
        )

        #expect(result.prompt.count <= AIPlanLimits.base.safeMax)
    }
}
