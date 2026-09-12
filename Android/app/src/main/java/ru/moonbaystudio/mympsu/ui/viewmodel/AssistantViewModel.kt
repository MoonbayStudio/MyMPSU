package ru.moonbaystudio.mympsu.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.data.model.AssistantMessage
import ru.moonbaystudio.mympsu.data.model.AssistantPersona
import ru.moonbaystudio.mympsu.data.model.ScheduleItem
import ru.moonbaystudio.mympsu.data.remote.MyMPSUApiService
import ru.moonbaystudio.mympsu.data.remote.dto.AssistantChatMessagePayload
import ru.moonbaystudio.mympsu.data.remote.dto.AssistantChatRequest
import ru.moonbaystudio.mympsu.data.remote.dto.AssistantChatResponse
import ru.moonbaystudio.mympsu.data.remote.dto.AssistantContext
import ru.moonbaystudio.mympsu.data.remote.dto.CachedSchedulePayload
import ru.moonbaystudio.mympsu.data.remote.dto.Homework
import ru.moonbaystudio.mympsu.data.repository.AuthRepository
import ru.moonbaystudio.mympsu.data.repository.RuntimeConfigRepository
import ru.moonbaystudio.mympsu.data.repository.ScheduleRepository
import ru.moonbaystudio.mympsu.util.AIResponseValidator
import ru.moonbaystudio.mympsu.util.AssistantConversationSummaryService
import ru.moonbaystudio.mympsu.util.AssistantPromptDialog
import ru.moonbaystudio.mympsu.util.AssistantPromptMessage
import ru.moonbaystudio.mympsu.util.AssistantScheduleContextBuilder
import ru.moonbaystudio.mympsu.util.ChatIntent
import ru.moonbaystudio.mympsu.util.ChatIntentDetector
import ru.moonbaystudio.mympsu.util.ChatOrchestrationContext
import ru.moonbaystudio.mympsu.util.ContextBudgeter
import ru.moonbaystudio.mympsu.util.ContextSelector
import ru.moonbaystudio.mympsu.util.LocalAnswerEngine
import ru.moonbaystudio.mympsu.util.UserGroupContext
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class AssistantViewModel @Inject constructor(
    private val apiService: MyMPSUApiService,
    private val scheduleRepository: ScheduleRepository,
    private val userPreferences: UserPreferences,
    private val authRepository: AuthRepository,
    private val runtimeConfigRepository: RuntimeConfigRepository
) : ViewModel() {

    private data class AssistantHistorySnapshot(
        val conversationId: String? = null,
        val messages: List<AssistantMessage> = emptyList(),
        val summary: String? = null,
        val summarizedMessageIds: List<String> = emptyList()
    )

    private data class AssistantLocalContext(
        val scheduleItems: List<ScheduleItem>,
        val exams: List<ScheduleItem>,
        val homeworks: List<Homework>,
        val cachedSchedule: CachedSchedulePayload?
    )

    private class AssistantHttpException(
        val code: Int,
        val responseBody: String?
    ) : Exception("HTTP $code")

    private val gson = Gson()
    private val _messages = MutableStateFlow<List<AssistantMessage>>(emptyList())
    val messages: StateFlow<List<AssistantMessage>> = _messages.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _inputText = MutableStateFlow("")
    val inputText: StateFlow<String> = _inputText.asStateFlow()

    private val _selectedPersona = MutableStateFlow(AssistantPersona.PELIKASHA)
    val selectedPersona: StateFlow<AssistantPersona> = _selectedPersona.asStateFlow()

    val runtimeConfigState = runtimeConfigRepository.state
    private val _remainingRequests = MutableStateFlow<Int?>(null)
    val remainingRequests: StateFlow<Int?> = _remainingRequests.asStateFlow()

    private var conversationId = UUID.randomUUID().toString()
    private var currentRequestJob: Job? = null
    private var lastUserMessage: String? = null
    private var summary: String? = null
    private var summarizedMessageIds: List<String> = emptyList()
    private val requestDateFormatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    init {
        viewModelScope.launch {
            restoreHistory()
        }
    }

    private suspend fun restoreHistory() {
        val historyJson = userPreferences.assistantHistory.first()
        if (historyJson.isNullOrBlank()) return

        try {
            val snapshot = gson.fromJson(historyJson, AssistantHistorySnapshot::class.java)
            if (snapshot != null && (snapshot.messages.isNotEmpty() || snapshot.summary != null)) {
                conversationId = snapshot.conversationId ?: UUID.randomUUID().toString()
                summary = snapshot.summary
                summarizedMessageIds = snapshot.summarizedMessageIds
                _messages.value = snapshot.messages
                lastUserMessage = snapshot.messages.lastOrNull { it.role == AssistantMessage.Role.USER }?.text
                return
            }
        } catch (_: Exception) {
        }

        try {
            val type = object : TypeToken<List<AssistantMessage>>() {}.type
            val history: List<AssistantMessage> = gson.fromJson(historyJson, type)
            _messages.value = history
            lastUserMessage = history.lastOrNull { it.role == AssistantMessage.Role.USER }?.text
        } catch (_: Exception) {
            _messages.value = emptyList()
        }
    }

    private fun saveHistory() {
        viewModelScope.launch {
            val snapshot = AssistantHistorySnapshot(
                conversationId = conversationId,
                messages = _messages.value.takeLast(50),
                summary = summary,
                summarizedMessageIds = summarizedMessageIds
            )
            userPreferences.saveAssistantHistory(gson.toJson(snapshot))
        }
    }

    fun setInputText(text: String) {
        _inputText.value = text
    }

    fun setPersona(persona: AssistantPersona) {
        _selectedPersona.value = persona
        viewModelScope.launch {
            userPreferences.updateDefaultPersona(persona.rawValue)
        }
    }

    fun sendMessage() {
        val text = _inputText.value.trim()
        if (text.isEmpty() || _isLoading.value) return

        val userMessage = AssistantMessage(role = AssistantMessage.Role.USER, text = text, persona = _selectedPersona.value)
        _messages.value += userMessage
        _inputText.value = ""
        lastUserMessage = text
        saveHistory()

        sendPrompt(text)
    }

    fun retryLastMessage() {
        val text = lastUserMessage ?: return
        if (_isLoading.value) return
        _messages.value = _messages.value.filter { it.role != AssistantMessage.Role.SYSTEM_LOCAL }
        sendPrompt(text)
    }

    fun cancelCurrentRequest() {
        currentRequestJob?.cancel()
        currentRequestJob = null
        _isLoading.value = false
    }

    private fun sendPrompt(userMessageText: String) {
        currentRequestJob?.cancel()
        currentRequestJob = viewModelScope.launch {
            runtimeConfigRepository.refresh()
            val runtimeConfig = runtimeConfigRepository.state.value.config
            if (!runtimeConfig.aiEnabled) {
                appendLocalSystemMessage("AI временно отключен администратором.")
                return@launch
            }

            _isLoading.value = true
            val persona = _selectedPersona.value
            try {
                val groupId = userPreferences.selectedGroupId.first()
                val groupName = userPreferences.selectedGroupName.first()
                val targetDateValue = Date()
                val targetDate = requestDateFormatter.format(targetDateValue)
                val intent = ChatIntentDetector.detectIntent(userMessageText)
                val localData = loadLocalContext(intent, groupId, targetDateValue)
                val groupContext = groupId?.let { UserGroupContext(id = it, name = groupName) }
                val dialog = promptDialog()
                val orchestrationContext = ChatOrchestrationContext(
                    intent = intent,
                    personaRawValue = persona.rawValue,
                    userMessage = userMessageText,
                    group = groupContext,
                    targetDate = targetDateValue,
                    scheduleItems = localData.scheduleItems.map(AssistantScheduleContextBuilder::aiLesson),
                    exams = localData.exams.map(AssistantScheduleContextBuilder::aiLesson),
                    homeworks = localData.homeworks.map(AssistantScheduleContextBuilder::aiHomework),
                    dialog = dialog
                )

                val localAnswer = LocalAnswerEngine.answer(orchestrationContext)
                if (localAnswer != null) {
                    appendAssistantMessage(localAnswer, persona)
                    return@launch
                }

                val budget = ContextBudgeter.buildPrompt(
                    packets = ContextSelector.packets(orchestrationContext),
                    emergencyUserMessage = userMessageText,
                    personaRawValue = persona.rawValue
                )

                val response = sendAIRequest(
                    prompt = budget.prompt,
                    persona = persona,
                    conversationId = conversationId,
                    groupId = groupId,
                    groupName = groupName,
                    targetDate = targetDate,
                    cachedSchedule = localData.cachedSchedule
                )
                val validatedReply = validatedReply(
                    reply = response.reply,
                    userMessage = userMessageText,
                    persona = persona,
                    groupId = groupId,
                    groupName = groupName,
                    targetDate = targetDate,
                    groupContext = groupContext
                )
                _remainingRequests.value = response.remaining
                appendAssistantMessage(validatedReply, persona)
            } catch (_: CancellationException) {
            } catch (error: Exception) {
                val retryReply = retryEmergencyAfterError(
                    error = error,
                    userMessage = userMessageText,
                    persona = persona
                )
                if (retryReply != null) {
                    appendAssistantMessage(retryReply, persona)
                } else {
                    appendLocalSystemMessage(errorMessageFor(error))
                }
            } finally {
                _isLoading.value = false
                currentRequestJob = null
            }
        }
    }

    private suspend fun loadLocalContext(intent: ChatIntent, groupId: Int?, date: Date): AssistantLocalContext {
        if (groupId == null) {
            return AssistantLocalContext(emptyList(), emptyList(), emptyList(), null)
        }

        return when (intent) {
            ChatIntent.CURRENT_LESSON,
            ChatIntent.TODAY_SCHEDULE -> {
                val items = loadScheduleItems(groupId, date, examOnly = false)
                AssistantLocalContext(
                    scheduleItems = items,
                    exams = emptyList(),
                    homeworks = emptyList(),
                    cachedSchedule = items.takeIf { it.isNotEmpty() }?.let(AssistantScheduleContextBuilder::buildCachedSchedule)
                )
            }
            ChatIntent.TOMORROW_SCHEDULE -> {
                val tomorrow = Calendar.getInstance().apply {
                    time = date
                    add(Calendar.DAY_OF_YEAR, 1)
                }.time
                val items = loadScheduleItems(groupId, tomorrow, examOnly = false)
                AssistantLocalContext(
                    scheduleItems = items,
                    exams = emptyList(),
                    homeworks = emptyList(),
                    cachedSchedule = items.takeIf { it.isNotEmpty() }?.let(AssistantScheduleContextBuilder::buildCachedSchedule)
                )
            }
            ChatIntent.EXAMS -> {
                val exams = loadScheduleItems(groupId, date, examOnly = true)
                AssistantLocalContext(emptyList(), exams, emptyList(), null)
            }
            ChatIntent.HOMEWORK -> {
                val homeworks = if (authRepository.isLoggedIn.first()) {
                    scheduleRepository.getHomeworks(groupId, date)
                } else {
                    emptyList()
                }
                AssistantLocalContext(emptyList(), emptyList(), homeworks, null)
            }
            ChatIntent.SMALL_TALK,
            ChatIntent.GROUP_INFO,
            ChatIntent.UNKNOWN -> AssistantLocalContext(emptyList(), emptyList(), emptyList(), null)
        }
    }

    private suspend fun loadScheduleItems(groupId: Int, date: Date, examOnly: Boolean): List<ScheduleItem> {
        val remoteItems = try {
            scheduleRepository.fetchSchedule(groupId, date, examOnly)
        } catch (_: Exception) {
            emptyList()
        }
        if (remoteItems.isNotEmpty()) return remoteItems
        if (!examOnly) {
            return scheduleRepository.getScheduleSync(groupId, date)
        }
        return emptyList()
    }

    private suspend fun sendAIRequest(
        prompt: String,
        persona: AssistantPersona,
        conversationId: String,
        groupId: Int?,
        groupName: String?,
        targetDate: String,
        cachedSchedule: CachedSchedulePayload?
    ): AssistantChatResponse {
        val request = AssistantChatRequest(
            message = prompt,
            persona = persona.rawValue,
            messages = listOf(AssistantChatMessagePayload(role = "user", content = prompt)),
            context = AssistantContext(groupId, groupName, targetDate),
            conversationId = conversationId,
            groupId = groupId,
            groupName = groupName,
            targetDate = targetDate,
            cachedSchedule = cachedSchedule
        )
        val response = apiService.assistantChat(request)
        if (response.isSuccessful) {
            return response.body() ?: throw Exception("Пустой ответ AI-сервиса")
        }
        throw AssistantHttpException(response.code(), response.errorBody()?.string())
    }

    private suspend fun validatedReply(
        reply: String,
        userMessage: String,
        persona: AssistantPersona,
        groupId: Int?,
        groupName: String?,
        targetDate: String,
        groupContext: UserGroupContext?
    ): String {
        val validation = AIResponseValidator.validate(reply, userMessage, groupContext)
        if (validation.isValid) return reply

        val emergency = ContextSelector.emergencyPrompt(userMessage, persona.rawValue).take(1_800)
        val retry = sendAIRequest(
            prompt = emergency,
            persona = persona,
            conversationId = conversationId,
            groupId = groupId,
            groupName = groupName,
            targetDate = targetDate,
            cachedSchedule = null
        )
        val retryValidation = AIResponseValidator.validate(retry.reply, userMessage, groupContext)
        return if (retryValidation.isValid) {
            retry.reply
        } else {
            "Я сбилась с ответа. Попробуй спросить ещё раз чуть короче."
        }
    }

    private suspend fun retryEmergencyAfterError(
        error: Exception,
        userMessage: String,
        persona: AssistantPersona
    ): String? {
        if (!isPromptTooLongError(error)) return null
        val groupId = userPreferences.selectedGroupId.first()
        val groupName = userPreferences.selectedGroupName.first()
        val targetDate = requestDateFormatter.format(Date())
        val groupContext = groupId?.let { UserGroupContext(it, groupName) }
        val emergency = ContextSelector.emergencyPrompt(userMessage, persona.rawValue).take(1_800)
        val response = sendAIRequest(
            prompt = emergency,
            persona = persona,
            conversationId = conversationId,
            groupId = groupId,
            groupName = groupName,
            targetDate = targetDate,
            cachedSchedule = null
        )
        val validation = AIResponseValidator.validate(response.reply, userMessage, groupContext)
        return if (validation.isValid) {
            response.reply
        } else {
            "Я сократила контекст, но всё равно сбилась с ответа. Попробуй спросить ещё раз чуть короче."
        }
    }

    private fun isPromptTooLongError(error: Exception): Boolean {
        if (error !is AssistantHttpException) return false
        val body = error.responseBody?.lowercase(Locale("ru")) ?: ""
        return error.code == 400 && (body.contains("слишком длин") || body.contains("too long"))
    }

    private fun errorMessageFor(error: Exception): String {
        return when (error) {
            is AssistantHttpException -> when (error.code) {
                400 -> "Сообщение получилось слишком длинным. Попробуй короче."
                429 -> "Слишком много запросов. Попробуй позже (лимит исчерпан)."
                503 -> "AI временно отключен или недоступен."
                504 -> "AI не успел ответить. Попробуй ещё раз."
                in 500..599 -> "Ошибка на стороне AI-сервиса. Мы уже чиним!"
                else -> "Ошибка сервера: ${error.code}"
            }
            is java.net.SocketTimeoutException -> "Превышено время ожидания. AI сегодня задумчив..."
            else -> "Ошибка сети: ${error.localizedMessage ?: "неизвестно"}"
        }
    }

    private fun promptDialog(): AssistantPromptDialog {
        return AssistantPromptDialog(
            messages = _messages.value.mapNotNull { message ->
                val role = when (message.role) {
                    AssistantMessage.Role.USER -> "user"
                    AssistantMessage.Role.ASSISTANT -> "assistant"
                    AssistantMessage.Role.SYSTEM_LOCAL -> return@mapNotNull null
                }
                AssistantPromptMessage(id = message.id, role = role, text = message.text)
            },
            summary = summary,
            summarizedMessageIds = summarizedMessageIds
        )
    }

    private fun appendAssistantMessage(text: String, persona: AssistantPersona) {
        _messages.value += AssistantMessage(role = AssistantMessage.Role.ASSISTANT, text = text, persona = persona)
        summarizeCurrentDialogIfNeeded()
        saveHistory()
    }

    private fun appendLocalSystemMessage(text: String) {
        _messages.value += AssistantMessage(role = AssistantMessage.Role.SYSTEM_LOCAL, text = text)
        saveHistory()
    }

    private fun summarizeCurrentDialogIfNeeded() {
        val result = AssistantConversationSummaryService.summarizeIfNeeded(promptDialog()) ?: return
        summary = result.summary
        summarizedMessageIds = result.summarizedMessageIds
    }

    fun clearHistory() {
        currentRequestJob?.cancel()
        currentRequestJob = null
        conversationId = UUID.randomUUID().toString()
        summary = null
        summarizedMessageIds = emptyList()
        lastUserMessage = null
        _messages.value = emptyList()
        _isLoading.value = false
        viewModelScope.launch {
            userPreferences.clearAssistantHistory()
        }
    }
}
