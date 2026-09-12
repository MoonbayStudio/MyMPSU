package ru.moonbaystudio.mympsu.data.repository

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.data.remote.MyMPSUApiService
import ru.moonbaystudio.mympsu.data.remote.dto.SystemNotice
import ru.moonbaystudio.mympsu.util.NetworkResult
import ru.moonbaystudio.mympsu.util.safeApiCall
import javax.inject.Inject
import javax.inject.Singleton

data class RuntimeConfig(
    val aiEnabled: Boolean = true,
    val aiDailyLimit: Int? = null,
    val personaTheme: String? = null,
    val maintenanceMode: Boolean = false,
    val scheduleCacheTtlSeconds: Int? = null
)

data class RuntimeConfigState(
    val config: RuntimeConfig = RuntimeConfig(),
    val notice: SystemNotice? = null,
    val isRefreshing: Boolean = false,
    val errorMessage: String? = null
)

@Singleton
class RuntimeConfigRepository @Inject constructor(
    private val apiService: MyMPSUApiService,
    private val userPreferences: UserPreferences
) {
    private val _state = MutableStateFlow(RuntimeConfigState())
    val state: StateFlow<RuntimeConfigState> = _state.asStateFlow()

    suspend fun refresh() {
        _state.value = _state.value.copy(isRefreshing = true, errorMessage = null)

        val configResult = safeApiCall { apiService.getPublicConfig() }
        val noticeResult = safeApiCall { apiService.getActiveSystemNotice() }

        val config = when (configResult) {
            is NetworkResult.Success -> configResult.data.settings.toRuntimeConfig()
            is NetworkResult.Error -> _state.value.config
            is NetworkResult.Exception -> _state.value.config
        }

        val dismissedNoticeId = userPreferences.dismissedSystemNoticeId.first()
        val notice = when (noticeResult) {
            is NetworkResult.Success -> {
                val activeNotice = noticeResult.data.notice
                if (noticeResult.data.isActive && activeNotice?.id != dismissedNoticeId) activeNotice else null
            }
            is NetworkResult.Error -> _state.value.notice
            is NetworkResult.Exception -> _state.value.notice
        }

        val error = listOf(configResult, noticeResult)
            .firstOrNull { it !is NetworkResult.Success }
            ?.let { "Не удалось обновить runtime config" }

        _state.value = RuntimeConfigState(
            config = config,
            notice = notice,
            isRefreshing = false,
            errorMessage = error
        )
    }

    suspend fun dismissNotice(id: Int) {
        userPreferences.saveDismissedSystemNoticeId(id)
        if (_state.value.notice?.id == id) {
            _state.value = _state.value.copy(notice = null)
        }
    }

    private fun Map<String, Any>.toRuntimeConfig(): RuntimeConfig {
        return RuntimeConfig(
            aiEnabled = booleanValue("AI_ENABLED") ?: true,
            aiDailyLimit = intValue("AI_DAILY_LIMIT"),
            personaTheme = stringValue("PERSONA_THEME"),
            maintenanceMode = booleanValue("MAINTENANCE_MODE") ?: false,
            scheduleCacheTtlSeconds = intValue("SCHEDULE_CACHE_TTL_SECONDS")
        )
    }

    private fun Map<String, Any>.booleanValue(key: String): Boolean? {
        return when (val value = this[key]) {
            is Boolean -> value
            is String -> value.equals("true", ignoreCase = true)
            is Number -> value.toInt() != 0
            else -> null
        }
    }

    private fun Map<String, Any>.intValue(key: String): Int? {
        return when (val value = this[key]) {
            is Number -> value.toInt()
            is String -> value.toIntOrNull()
            else -> null
        }
    }

    private fun Map<String, Any>.stringValue(key: String): String? {
        return this[key]?.toString()?.takeIf { it.isNotBlank() }
    }
}
