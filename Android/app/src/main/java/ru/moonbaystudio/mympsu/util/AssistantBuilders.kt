package ru.moonbaystudio.mympsu.util

import ru.moonbaystudio.mympsu.data.model.ScheduleItem
import ru.moonbaystudio.mympsu.data.remote.dto.AssistantChatMessagePayload
import ru.moonbaystudio.mympsu.data.remote.dto.CachedScheduleLessonPayload
import ru.moonbaystudio.mympsu.data.remote.dto.CachedSchedulePayload
import ru.moonbaystudio.mympsu.data.remote.dto.Homework
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

data class AssistantPromptMessage(
    val id: String,
    val role: String,
    val text: String
)

data class AssistantPromptDialog(
    val messages: List<AssistantPromptMessage>,
    val summary: String?,
    val summarizedMessageIds: List<String>
)

data class AssistantSummaryResult(
    val summary: String,
    val summarizedMessageIds: List<String>
)

enum class ChatIntent {
    SMALL_TALK,
    GROUP_INFO,
    TODAY_SCHEDULE,
    TOMORROW_SCHEDULE,
    CURRENT_LESSON,
    EXAMS,
    HOMEWORK,
    UNKNOWN
}

data class UserGroupContext(
    val id: Int,
    val name: String?,
    val facultyName: String? = null,
    val programName: String? = null
) {
    val displayName: String?
        get() = name?.trim()?.takeIf { it.isNotEmpty() }
}

data class AIScheduleLessonContext(
    val startIso: String,
    val endIso: String,
    val time: String,
    val title: String,
    val teacher: String,
    val lessonType: String,
    val address: String,
    val subgroup: String?,
    val period: String,
    val room: String,
    val classUrl: String?
)

data class AIHomeworkContext(
    val lessonDate: String,
    val lessonTime: String,
    val subject: String,
    val teacher: String?,
    val room: String?,
    val text: String
)

data class AIPlanLimits(val maxRequestChars: Int) {
    val safeMax: Int get() = (maxRequestChars - 200).coerceAtLeast(0)

    companion object {
        val base = AIPlanLimits(maxRequestChars = 2_000)
    }
}

data class ContextPacket(
    val name: String,
    val priority: Int,
    val maxChars: Int,
    val content: String
)

data class ContextBudgetResult(
    val prompt: String,
    val packets: List<ContextPacket>,
    val usedEmergencyPrompt: Boolean
)

data class ChatOrchestrationContext(
    val intent: ChatIntent,
    val personaRawValue: String,
    val userMessage: String,
    val group: UserGroupContext?,
    val targetDate: Date,
    val scheduleItems: List<AIScheduleLessonContext>,
    val exams: List<AIScheduleLessonContext>,
    val homeworks: List<AIHomeworkContext>,
    val dialog: AssistantPromptDialog
)

data class AIValidationResult(
    val isValid: Boolean,
    val reason: String? = null
)

object ChatIntentDetector {
    fun detectIntent(text: String): ChatIntent {
        val normalized = normalize(text)
        val hasStudyKeyword = containsAny(
            normalized,
            listOf("групп", "пара", "пары", "распис", "занят", "урок", "экзам", "сесс", "зачет", "домаш", "дз", "задано")
        )

        return when {
            containsAny(normalized, listOf("какая у меня группа", "из какой я группы", "название группы", "моя группа", "какую группу")) -> ChatIntent.GROUP_INFO
            containsAny(normalized, listOf("какая сейчас пара", "что сейчас", "следующая пара", "текущая пара", "сейчас пара")) -> ChatIntent.CURRENT_LESSON
            containsAny(normalized, listOf("что завтра", "пары завтра", "расписание завтра", "завтра пары", "завтра расписание")) -> ChatIntent.TOMORROW_SCHEDULE
            containsAny(normalized, listOf("что сегодня", "пары сегодня", "расписание сегодня", "сегодня пары", "сегодня расписание")) -> ChatIntent.TODAY_SCHEDULE
            containsAny(normalized, listOf("экзамен", "экзамены", "сессия", "сессии", "зачет")) -> ChatIntent.EXAMS
            containsAny(normalized, listOf("домашка", "домашнее", "дз", "что задано", "задали")) -> ChatIntent.HOMEWORK
            normalized.length <= 80 && !hasStudyKeyword -> ChatIntent.SMALL_TALK
            else -> ChatIntent.UNKNOWN
        }
    }

    private fun normalize(text: String): String {
        return text.lowercase(Locale("ru"))
            .replace("ё", "е")
            .split(Regex("\\s+"))
            .joinToString(" ")
            .trim()
    }

    private fun containsAny(text: String, needles: List<String>): Boolean {
        return needles.any { text.contains(it) }
    }
}

object AssistantScheduleContextBuilder {
    private val isoFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    fun buildCachedSchedule(items: List<ScheduleItem>, source: String = "android-cache"): CachedSchedulePayload {
        return CachedSchedulePayload(
            generatedAt = isoFormatter.format(Date()),
            source = source,
            lessons = items.map {
                CachedScheduleLessonPayload(
                    name = it.title,
                    type = it.lessonType,
                    startTime = it.sortDateIso,
                    endTime = it.endDateIso,
                    date = null,
                    room = it.room,
                    teacher = it.teacher,
                    roomId = null,
                    teacherId = null,
                    classUrl = it.classUrl,
                    note = null,
                    isExam = it.period.trim().isNotEmpty()
                )
            }
        )
    }

    fun buildScheduleText(groupId: Int, groupName: String?, date: Date, items: List<ScheduleItem>): String {
        val readableDate = SimpleDateFormat("d MMMM yyyy", Locale("ru")).format(date)
        val groupText = groupName?.trim()?.takeIf { it.isNotEmpty() } ?: "ID $groupId"
        if (items.isEmpty()) {
            return "Группа: $groupText. Дата: $readableDate. В локальном расписании на эту дату пары не найдены."
        }

        val lines = items.map { item ->
            val parts = mutableListOf("- ${item.time}: ${item.title}")
            if (item.lessonType.trim().isNotBlank()) parts.add("тип: ${item.lessonType}")
            if (item.teacher.trim().isNotBlank()) parts.add("преподаватель: ${item.teacher}")
            if (item.room.trim().isNotBlank()) parts.add("аудитория: ${item.room}")
            else if (item.address.trim().isNotBlank()) parts.add("адрес: ${item.address}")
            if (!item.subgroup.isNullOrBlank()) parts.add("подгруппа: ${item.subgroup.trim()}")
            parts.joinToString("; ")
        }

        return """
            Группа: $groupText. Дата: $readableDate.
            Пары:
            ${lines.joinToString("\n")}
        """.trimIndent()
    }

    fun aiLesson(item: ScheduleItem): AIScheduleLessonContext {
        return AIScheduleLessonContext(
            startIso = item.sortDateIso,
            endIso = item.endDateIso,
            time = item.time,
            title = item.title,
            teacher = item.teacher,
            lessonType = item.lessonType,
            address = item.address,
            subgroup = item.subgroup,
            period = item.period,
            room = item.room,
            classUrl = item.classUrl
        )
    }

    fun aiHomework(homework: Homework): AIHomeworkContext {
        return AIHomeworkContext(
            lessonDate = homework.lessonDate,
            lessonTime = homework.lessonTime,
            subject = homework.subject,
            teacher = homework.teacher,
            room = homework.room,
            text = homework.text
        )
    }
}

object LocalAnswerEngine {
    fun answer(context: ChatOrchestrationContext, now: Date = Date()): String? {
        return when (context.intent) {
            ChatIntent.GROUP_INFO -> groupInfoAnswer(context.group)
            ChatIntent.CURRENT_LESSON -> currentLessonAnswer(context.scheduleItems, now)
            ChatIntent.TODAY_SCHEDULE -> scheduleAnswer(context.scheduleItems, "Сегодня")
            ChatIntent.TOMORROW_SCHEDULE -> scheduleAnswer(context.scheduleItems, "Завтра")
            ChatIntent.EXAMS -> examsAnswer(context.exams, now)
            ChatIntent.HOMEWORK -> homeworkAnswer(context.homeworks)
            ChatIntent.SMALL_TALK, ChatIntent.UNKNOWN -> null
        }
    }

    private fun groupInfoAnswer(group: UserGroupContext?): String {
        if (group == null) return "Группа пока не выбрана."
        group.displayName?.let { return "Ты из группы $it." }
        return "У меня есть только технический ID твоей группы - ${group.id}. Название группы пока не загружено."
    }

    private fun currentLessonAnswer(items: List<AIScheduleLessonContext>, now: Date): String {
        val timed = items.mapNotNull { TimedScheduleItem.from(it) }.sortedBy { it.start }
        if (timed.isEmpty()) return "На сегодня в локальном расписании пар не нашла."

        val active = timed.firstOrNull { it.start <= now && now <= it.end }
        if (active != null) {
            val next = timed.firstOrNull { it.start > active.end }
            return buildString {
                append("Сейчас идёт: ${lessonLine(active.item)}.")
                if (next != null) append("\nСледующая: ${lessonLine(next.item)}.")
            }
        }

        val next = timed.firstOrNull { it.start > now }
        if (next != null) return "Сейчас пары нет. Следующая: ${lessonLine(next.item)}."
        return "На сегодня пары уже закончились."
    }

    private fun scheduleAnswer(items: List<AIScheduleLessonContext>, title: String): String {
        if (items.isEmpty()) return "$title в локальном расписании пар не нашла."
        val lines = items.take(10).joinToString("\n") { "- ${lessonLine(it)}" }
        return "$title:\n$lines"
    }

    private fun examsAnswer(items: List<AIScheduleLessonContext>, now: Date): String {
        val upcoming = upcomingExamItems(items, now)
        if (upcoming.isEmpty()) return "По локальным данным по сессии больше ничего не осталось."
        val lines = upcoming.take(8).joinToString("\n") { "- ${examLine(it)}" }
        return "По сессии осталось:\n$lines"
    }

    private fun homeworkAnswer(homeworks: List<AIHomeworkContext>): String? {
        if (homeworks.isEmpty()) return null
        val lines = homeworks.take(8).joinToString("\n") {
            "- ${it.lessonDate} ${it.lessonTime}, ${it.subject}: ${it.text}"
        }
        return "Домашка:\n$lines"
    }

    fun lessonLine(item: AIScheduleLessonContext): String {
        val parts = mutableListOf("${item.time} ${item.title}")
        if (item.lessonType.trim().isNotEmpty()) parts.add(item.lessonType)
        if (item.teacher.trim().isNotEmpty()) parts.add(item.teacher)
        if (item.room.trim().isNotEmpty()) parts.add("ауд. ${item.room}")
        else if (item.address.trim().isNotEmpty()) parts.add(item.address)
        return parts.joinToString(", ")
    }

    fun examLine(item: AIScheduleLessonContext): String {
        val parts = mutableListOf(examDateText(item), item.time, item.title)
        if (item.lessonType.trim().isNotEmpty()) parts.add(item.lessonType)
        if (item.teacher.trim().isNotEmpty()) parts.add(item.teacher)
        if (item.room.trim().isNotEmpty()) parts.add("ауд. ${item.room}")
        else if (item.address.trim().isNotEmpty()) parts.add(item.address)
        return parts.map { it.trim() }.filter { it.isNotEmpty() }.joinToString(", ")
    }

    fun upcomingExamItems(items: List<AIScheduleLessonContext>, now: Date): List<AIScheduleLessonContext> {
        return items
            .filter { item ->
                val end = parseIsoDate(item.endIso) ?: parseIsoDate(item.startIso)
                end == null || end >= now
            }
            .sortedBy { parseIsoDate(it.startIso) ?: Date(Long.MAX_VALUE) }
    }

    private fun examDateText(item: AIScheduleLessonContext): String {
        if (item.period.trim().isNotEmpty()) return item.period
        val date = parseIsoDate(item.startIso) ?: return ""
        return SimpleDateFormat("d MMMM", Locale("ru")).format(date)
    }

    private data class TimedScheduleItem(
        val item: AIScheduleLessonContext,
        val start: Date,
        val end: Date
    ) {
        companion object {
            fun from(item: AIScheduleLessonContext): TimedScheduleItem? {
                val start = parseIsoDate(item.startIso) ?: return null
                val end = parseIsoDate(item.endIso) ?: start
                return TimedScheduleItem(item, start, end)
            }
        }
    }

    private val isoFormatters = listOf(
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US),
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US),
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        },
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        },
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
    )

    private fun parseIsoDate(value: String): Date? {
        for (formatter in isoFormatters) {
            try {
                return formatter.parse(value)
            } catch (_: Exception) {
            }
        }
        return null
    }
}

object ContextSelector {
    fun packets(context: ChatOrchestrationContext): List<ContextPacket> {
        val packets = mutableListOf(
            ContextPacket("system rules", 100, 350, systemRules(context.personaRawValue)),
            ContextPacket("user message", 95, 400, "Сообщение пользователя:\n${context.userMessage}")
        )

        if (context.group != null && shouldIncludeGroup(context.intent)) {
            packets.add(ContextPacket("exact user facts", 90, 250, groupContext(context.group)))
        }

        val appData = relevantAppData(context)
        if (!appData.isNullOrBlank()) {
            packets.add(ContextPacket("relevant app data", 70, 450, appData))
        }

        val summary = context.dialog.summary?.trim()
        if (shouldIncludeSummary(context.intent) && !summary.isNullOrEmpty()) {
            packets.add(ContextPacket("summary", 50, 250, "Краткая память:\n$summary"))
        }

        if (shouldIncludeRecentMessages(context.intent)) {
            val recent = recentMessages(context.dialog.messages)
            if (recent.isNotEmpty()) {
                packets.add(ContextPacket("recent messages", 30, 300, recent))
            }
        }

        packets.add(ContextPacket("optional personality", 10, 100, personalityHint(context.personaRawValue)))
        return packets
    }

    fun systemRules(personaRawValue: String): String {
        val name = if (personaRawValue == "stesha") "Стеша" else "Помощник МПГУ"
        return """
            Ты - $name, AI-помощница в приложении MyMPSU.
            Отвечай только на русском языке, если пользователь явно не попросил другой язык.
            Будь дружелюбной, но не выдумывай факты.
            Данные расписания, группы, экзаменов и домашки используй только из переданного контекста.
            Если данных нет - честно скажи, что данных нет.
            Технический ID группы не является названием группы.
        """.trimIndent()
    }

    fun emergencyPrompt(userMessage: String, personaRawValue: String): String {
        val name = if (personaRawValue == "stesha") "Стеша" else "Помощник МПГУ"
        return """
            Ты - $name, помощница MyMPSU. Отвечай только на русском. Кратко. Не выдумывай данные. Если данных нет - скажи честно.
            Сообщение пользователя:
            $userMessage
        """.trimIndent()
    }

    private fun shouldIncludeGroup(intent: ChatIntent): Boolean = intent != ChatIntent.SMALL_TALK

    private fun shouldIncludeSummary(intent: ChatIntent): Boolean {
        return when (intent) {
            ChatIntent.UNKNOWN -> true
            ChatIntent.SMALL_TALK,
            ChatIntent.GROUP_INFO,
            ChatIntent.TODAY_SCHEDULE,
            ChatIntent.TOMORROW_SCHEDULE,
            ChatIntent.CURRENT_LESSON,
            ChatIntent.EXAMS,
            ChatIntent.HOMEWORK -> false
        }
    }

    private fun shouldIncludeRecentMessages(intent: ChatIntent): Boolean {
        return intent == ChatIntent.UNKNOWN || intent == ChatIntent.SMALL_TALK
    }

    private fun groupContext(group: UserGroupContext): String {
        val lines = mutableListOf("Технический ID группы: ${group.id}. Это не название группы.")
        val displayName = group.displayName
        if (displayName != null) lines.add("Название выбранной группы: $displayName.")
        else lines.add("Название группы пока не загружено.")
        group.facultyName?.trim()?.takeIf { it.isNotEmpty() }?.let { lines.add("Факультет/институт: $it.") }
        group.programName?.trim()?.takeIf { it.isNotEmpty() }?.let { lines.add("Программа: $it.") }
        return lines.joinToString("\n")
    }

    private fun relevantAppData(context: ChatOrchestrationContext): String? {
        return when (context.intent) {
            ChatIntent.TODAY_SCHEDULE, ChatIntent.TOMORROW_SCHEDULE -> scheduleData(context.scheduleItems)
            ChatIntent.CURRENT_LESSON -> scheduleData(context.scheduleItems.take(4))
            ChatIntent.EXAMS -> examsData(context.exams)
            ChatIntent.HOMEWORK -> homeworkData(context.homeworks)
            ChatIntent.GROUP_INFO, ChatIntent.SMALL_TALK, ChatIntent.UNKNOWN -> null
        }
    }

    private fun scheduleData(items: List<AIScheduleLessonContext>): String {
        if (items.isEmpty()) return "Локальных данных расписания для запроса нет."
        return items.take(10).joinToString("\n") { "- ${LocalAnswerEngine.lessonLine(it)}" }
    }

    private fun examsData(items: List<AIScheduleLessonContext>): String {
        val upcoming = LocalAnswerEngine.upcomingExamItems(items, Date())
        if (upcoming.isEmpty()) return "По локальным данным по сессии больше ничего не осталось."
        return upcoming.take(8).joinToString("\n") { "- ${LocalAnswerEngine.examLine(it)}" }
    }

    private fun homeworkData(homeworks: List<AIHomeworkContext>): String {
        if (homeworks.isEmpty()) return "Локальных данных домашки для запроса нет."
        return homeworks.take(8).joinToString("\n") {
            "- ${it.lessonDate} ${it.lessonTime}, ${it.subject}: ${it.text}"
        }
    }

    private fun recentMessages(messages: List<AssistantPromptMessage>): String {
        return messages
            .filter { it.role == "user" || it.role == "assistant" }
            .takeLast(6)
            .joinToString("\n") { "${if (it.role == "user") "Пользователь" else "Ассистент"}: ${it.text}" }
    }

    private fun personalityHint(personaRawValue: String): String {
        return if (personaRawValue == "stesha") {
            "Стиль: спокойно, бережно, без лишних приветствий."
        } else {
            "Стиль: живо, кратко, полезно, без лишних приветствий."
        }
    }
}

object ContextBudgeter {
    fun buildPrompt(
        packets: List<ContextPacket>,
        limits: AIPlanLimits = AIPlanLimits.base,
        emergencyUserMessage: String,
        personaRawValue: String
    ): ContextBudgetResult {
        val safeMax = limits.safeMax
        val selected = mutableListOf<ContextPacket>()
        var used = 0

        packets.sortedWith(compareByDescending<ContextPacket> { it.priority }.thenBy { it.name }).forEach { packet ->
            val content = compact(packet.content, packet.maxChars)
            if (content.isEmpty()) return@forEach
            val section = "${packet.name}:\n$content"
            val separatorLength = if (selected.isEmpty()) 0 else 2
            if (used + separatorLength + section.length <= safeMax) {
                selected.add(packet.copy(content = content))
                used += separatorLength + section.length
            }
        }

        val prompt = selected.joinToString("\n\n") { "${it.name}:\n${it.content}" }
        if (prompt.isNotEmpty() && prompt.length <= safeMax) {
            return ContextBudgetResult(prompt, selected, usedEmergencyPrompt = false)
        }

        val emergency = compact(ContextSelector.emergencyPrompt(emergencyUserMessage, personaRawValue), safeMax)
        return ContextBudgetResult(emergency, emptyList(), usedEmergencyPrompt = true)
    }

    fun compact(value: String, limit: Int): String {
        val normalized = value
            .replace("\n", " ")
            .split(Regex("\\s+"))
            .joinToString(" ")
            .trim()
        if (normalized.length <= limit) return normalized
        val suffix = "..."
        return normalized.take((limit - suffix.length).coerceAtLeast(0)) + suffix
    }
}

object AIResponseValidator {
    fun validate(text: String, userMessage: String, group: UserGroupContext?): AIValidationResult {
        val trimmed = text.trim()
        return when {
            trimmed.isEmpty() -> AIValidationResult(false, "empty")
            containsRawBackendError(trimmed) -> AIValidationResult(false, "raw backend error")
            containsCjk(trimmed) && !userAskedForForeignLanguage(userMessage) -> AIValidationResult(false, "cjk")
            namesGroupIdAsName(trimmed, userMessage, group) -> AIValidationResult(false, "group id as name")
            else -> AIValidationResult(true)
        }
    }

    private fun containsCjk(text: String): Boolean {
        return Regex("[\\u4E00-\\u9FFF\\u3040-\\u30FF\\uAC00-\\uD7AF]").containsMatchIn(text)
    }

    private fun containsRawBackendError(text: String): Boolean {
        val lowered = text.lowercase(Locale.US)
        return lowered.contains("api request failed") ||
            lowered.contains("\"detail\"") ||
            lowered.contains("http 400") ||
            lowered.contains("http 401") ||
            lowered.contains("http 403") ||
            lowered.contains("http 500")
    }

    private fun userAskedForForeignLanguage(text: String): Boolean {
        val lowered = text.lowercase(Locale("ru"))
        return lowered.contains("на английском") ||
            lowered.contains("на китайском") ||
            lowered.contains("переведи") ||
            lowered.contains("translate")
    }

    private fun namesGroupIdAsName(text: String, userMessage: String, group: UserGroupContext?): Boolean {
        if (group == null || group.displayName != null) return false
        val id = group.id.toString()
        val lowered = text.lowercase(Locale("ru"))
        val asksGroup = userMessage.lowercase(Locale("ru")).contains("групп")
        return asksGroup && lowered.contains(id) &&
            (lowered.contains("называ") || lowered.contains("твоя группа") || lowered.contains("ты из группы"))
    }
}

object AssistantConversationSummaryService {
    private const val RECENT_MESSAGE_LIMIT = 6
    private const val MINIMUM_UNSUMMARIZED_MESSAGES = 10

    fun summarizeIfNeeded(dialog: AssistantPromptDialog): AssistantSummaryResult? {
        val conversationalMessages = dialog.messages.filter { it.role == "user" || it.role == "assistant" }
        val summarizedIds = dialog.summarizedMessageIds.toSet()
        val unsummarized = conversationalMessages.filter { it.id !in summarizedIds }
        if (unsummarized.size <= MINIMUM_UNSUMMARIZED_MESSAGES) return null

        val messagesToSummarize = unsummarized.dropLast(RECENT_MESSAGE_LIMIT)
        if (messagesToSummarize.isEmpty()) return null

        val summary = mergedSummary(dialog.summary, messagesToSummarize)
        if (summary.isBlank()) return null
        return AssistantSummaryResult(
            summary = summary,
            summarizedMessageIds = (summarizedIds + messagesToSummarize.map { it.id }).toList()
        )
    }

    private fun mergedSummary(existing: String?, messages: List<AssistantPromptMessage>): String {
        val sections = mutableListOf<String>()
        existing?.trim()?.takeIf { it.isNotEmpty() }?.let { sections.add(it) }

        val compactLines = messages.mapNotNull(::summaryFactLine).take(8)
        if (compactLines.isNotEmpty()) {
            sections.add("Обновление памяти:\n${compactLines.joinToString("\n")}")
        }

        return sections
            .joinToString("\n\n")
            .lineSequence()
            .take(20)
            .joinToString("\n")
            .take(500)
    }

    private fun summaryFactLine(message: AssistantPromptMessage): String? {
        val text = message.text
            .replace("\n", " ")
            .split(Regex("\\s+"))
            .joinToString(" ")
            .trim()
        if (text.isEmpty()) return null

        return when (message.role) {
            "user" -> {
                val lowered = text.lowercase(Locale("ru"))
                when {
                    lowered.contains("групп") -> "- Тема: пользователь спрашивал о группе."
                    ChatIntentDetector.detectIntent(text) != ChatIntent.SMALL_TALK -> "- Текущая тема: ${text.take(140)}"
                    else -> null
                }
            }
            "assistant" -> {
                if (text.lowercase(Locale("ru")).contains("технический id")) {
                    "- Важно: технический ID группы нельзя называть названием группы."
                } else {
                    null
                }
            }
            else -> null
        }
    }
}

object AssistantPromptBuilder {
    fun buildMessages(
        persona: String,
        history: List<AssistantChatMessagePayload>,
        scheduleContext: String? = null
    ): List<AssistantChatMessagePayload> {
        val packets = mutableListOf(
            AssistantChatMessagePayload("system", ContextSelector.systemRules(persona))
        )
        if (!scheduleContext.isNullOrBlank()) {
            packets.add(AssistantChatMessagePayload("system", scheduleContext))
        }
        packets.addAll(history.takeLast(12))
        return packets
    }

    fun buildLegacyMessage(messages: List<AssistantChatMessagePayload>): String {
        return messages.joinToString("\n\n") {
            val label = when (it.role) {
                "system" -> "SYSTEM"
                "assistant" -> "ASSISTANT"
                "user" -> "USER"
                else -> it.role.uppercase(Locale.US)
            }
            "[$label]\n${it.content}"
        }
    }
}
