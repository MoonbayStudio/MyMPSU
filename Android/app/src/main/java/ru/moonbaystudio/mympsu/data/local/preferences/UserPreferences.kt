package ru.moonbaystudio.mympsu.data.local.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "user_prefs")

@Singleton
class UserPreferences @Inject constructor(@ApplicationContext private val context: Context) {

    private val TOKEN_KEY = stringPreferencesKey("auth_token")
    private val GROUP_ID_KEY = intPreferencesKey("selected_group_id")
    private val GROUP_NAME_KEY = stringPreferencesKey("selected_group_name")
    private val SCHEDULE_GROUP_ID_KEY = intPreferencesKey("schedule_group_id")
    private val SCHEDULE_GROUP_NAME_KEY = stringPreferencesKey("schedule_group_name")
    private val THEME_ID_KEY = stringPreferencesKey("selected_theme_id")
    private val THEME_FAMILY_ID_KEY = stringPreferencesKey("selected_theme_family_id")
    private val FOLLOW_SYSTEM_THEME_KEY = booleanPreferencesKey("follow_system_theme")
    
    // Accessibility
    private val REDUCE_MOTION_KEY = booleanPreferencesKey("accessibility_reduce_motion")
    private val HIGH_CONTRAST_KEY = booleanPreferencesKey("accessibility_high_contrast")
    private val LARGER_TEXT_KEY = booleanPreferencesKey("accessibility_larger_text")
    private val AUTO_SPEAK_SCHEDULE_KEY = booleanPreferencesKey("accessibility_auto_speak_schedule")
    private val SPEECH_DETAILED_KEY = booleanPreferencesKey("accessibility_speech_detailed")
    private val HAPTICS_ENABLED_KEY = booleanPreferencesKey("accessibility_haptics_enabled")
    private val DEFAULT_PERSONA_KEY = stringPreferencesKey("assistant_default_persona")
    private val DEVICE_ID_KEY = stringPreferencesKey("device_id")
    
    // Cache & Live Activity
    private val SCHEDULE_CACHE_WEEKS_KEY = intPreferencesKey("schedule_cache_weeks")
    private val LIVE_ACTIVITY_ENABLED_KEY = booleanPreferencesKey("live_activity_enabled")
    private val OFFLINE_SCHEDULE_ENABLED_KEY = booleanPreferencesKey("offline_schedule_enabled")
    private val ONBOARDING_COMPLETED_KEY = booleanPreferencesKey("onboarding_completed")
    private val ASSISTANT_HISTORY_KEY = stringPreferencesKey("assistant_chat_history")
    private val DISMISSED_SYSTEM_NOTICE_ID_KEY = intPreferencesKey("dismissed_system_notice_id")

    val authToken: Flow<String?> = context.dataStore.data.map { it[TOKEN_KEY] }
    val selectedGroupId: Flow<Int?> = context.dataStore.data.map { it[GROUP_ID_KEY] }
    val selectedGroupName: Flow<String?> = context.dataStore.data.map { it[GROUP_NAME_KEY] }
    val scheduleGroupId: Flow<Int?> = context.dataStore.data.map { it[SCHEDULE_GROUP_ID_KEY] ?: it[GROUP_ID_KEY] }
    val scheduleGroupName: Flow<String?> = context.dataStore.data.map { it[SCHEDULE_GROUP_NAME_KEY] ?: it[GROUP_NAME_KEY] }
    val selectedThemeId: Flow<String> = context.dataStore.data.map { it[THEME_ID_KEY] ?: "classic" }
    val selectedThemeFamilyId: Flow<String> = context.dataStore.data.map { it[THEME_FAMILY_ID_KEY] ?: "standard" }
    val followSystemTheme: Flow<Boolean> = context.dataStore.data.map { it[FOLLOW_SYSTEM_THEME_KEY] ?: true }

    val reduceMotion: Flow<Boolean> = context.dataStore.data.map { it[REDUCE_MOTION_KEY] ?: false }
    val highContrast: Flow<Boolean> = context.dataStore.data.map { it[HIGH_CONTRAST_KEY] ?: false }
    val largerText: Flow<Boolean> = context.dataStore.data.map { it[LARGER_TEXT_KEY] ?: false }
    val autoSpeakSchedule: Flow<Boolean> = context.dataStore.data.map { it[AUTO_SPEAK_SCHEDULE_KEY] ?: false }
    val speechDetailed: Flow<Boolean> = context.dataStore.data.map { it[SPEECH_DETAILED_KEY] ?: true }
    val hapticsEnabled: Flow<Boolean> = context.dataStore.data.map { it[HAPTICS_ENABLED_KEY] ?: true }
    val defaultPersona: Flow<String> = context.dataStore.data.map { it[DEFAULT_PERSONA_KEY] ?: "pelikasha" }
    
    val scheduleCacheWeeks: Flow<Int> = context.dataStore.data.map { it[SCHEDULE_CACHE_WEEKS_KEY] ?: 2 }
    val liveActivityEnabled: Flow<Boolean> = context.dataStore.data.map { it[LIVE_ACTIVITY_ENABLED_KEY] ?: true }
    val offlineScheduleEnabled: Flow<Boolean> = context.dataStore.data.map { it[OFFLINE_SCHEDULE_ENABLED_KEY] ?: ((it[SCHEDULE_CACHE_WEEKS_KEY] ?: 2) > 0) }
    val onboardingCompleted: Flow<Boolean> = context.dataStore.data.map { it[ONBOARDING_COMPLETED_KEY] ?: false }
    val assistantHistory: Flow<String?> = context.dataStore.data.map { it[ASSISTANT_HISTORY_KEY] }
    val dismissedSystemNoticeId: Flow<Int?> = context.dataStore.data.map { it[DISMISSED_SYSTEM_NOTICE_ID_KEY] }
    
    val deviceId: Flow<String> = context.dataStore.data.map { 
        it[DEVICE_ID_KEY] ?: run {
            val newId = java.util.UUID.randomUUID().toString()
            saveDeviceId(newId)
            newId
        }
    }

    suspend fun saveAuthToken(token: String) {
        context.dataStore.edit { it[TOKEN_KEY] = token }
    }

    suspend fun clearAuthToken() {
        context.dataStore.edit { it.remove(TOKEN_KEY) }
    }

    suspend fun saveSelectedGroup(id: Int, name: String) {
        context.dataStore.edit {
            it[GROUP_ID_KEY] = id
            it[GROUP_NAME_KEY] = name
            if (!it.contains(SCHEDULE_GROUP_ID_KEY)) {
                it[SCHEDULE_GROUP_ID_KEY] = id
                it[SCHEDULE_GROUP_NAME_KEY] = name
            }
        }
    }

    suspend fun saveUserSettings(
        selectedGroupId: Int?,
        selectedGroupName: String?,
        scheduleCacheWeeks: Int,
        liveActivityEnabled: Boolean
    ) {
        context.dataStore.edit {
            if (selectedGroupId != null) {
                it[GROUP_ID_KEY] = selectedGroupId
                it[GROUP_NAME_KEY] = selectedGroupName ?: selectedGroupId.toString()
                if (!it.contains(SCHEDULE_GROUP_ID_KEY)) {
                    it[SCHEDULE_GROUP_ID_KEY] = selectedGroupId
                    it[SCHEDULE_GROUP_NAME_KEY] = selectedGroupName ?: selectedGroupId.toString()
                }
            }
            it[SCHEDULE_CACHE_WEEKS_KEY] = scheduleCacheWeeks.coerceIn(0, 4)
            it[OFFLINE_SCHEDULE_ENABLED_KEY] = scheduleCacheWeeks > 0
            it[LIVE_ACTIVITY_ENABLED_KEY] = liveActivityEnabled
        }
    }

    suspend fun saveScheduleGroup(id: Int, name: String) {
        context.dataStore.edit {
            it[SCHEDULE_GROUP_ID_KEY] = id
            it[SCHEDULE_GROUP_NAME_KEY] = name
        }
    }

    suspend fun saveThemeId(themeId: String) {
        context.dataStore.edit { it[THEME_ID_KEY] = themeId }
    }

    suspend fun saveThemeFamilyId(familyId: String) {
        context.dataStore.edit { it[THEME_FAMILY_ID_KEY] = familyId }
    }

    suspend fun updateFollowSystemTheme(enabled: Boolean) {
        context.dataStore.edit { it[FOLLOW_SYSTEM_THEME_KEY] = enabled }
    }

    suspend fun updateReduceMotion(enabled: Boolean) {
        context.dataStore.edit { it[REDUCE_MOTION_KEY] = enabled }
    }

    suspend fun updateHighContrast(enabled: Boolean) {
        context.dataStore.edit { it[HIGH_CONTRAST_KEY] = enabled }
    }

    suspend fun updateLargerText(enabled: Boolean) {
        context.dataStore.edit { it[LARGER_TEXT_KEY] = enabled }
    }

    suspend fun updateAutoSpeakSchedule(enabled: Boolean) {
        context.dataStore.edit { it[AUTO_SPEAK_SCHEDULE_KEY] = enabled }
    }

    suspend fun updateSpeechDetailed(enabled: Boolean) {
        context.dataStore.edit { it[SPEECH_DETAILED_KEY] = enabled }
    }

    suspend fun updateHapticsEnabled(enabled: Boolean) {
        context.dataStore.edit { it[HAPTICS_ENABLED_KEY] = enabled }
    }

    suspend fun updateDefaultPersona(persona: String) {
        context.dataStore.edit { it[DEFAULT_PERSONA_KEY] = persona }
    }

    suspend fun updateScheduleCacheWeeks(weeks: Int) {
        context.dataStore.edit {
            val normalizedWeeks = weeks.coerceIn(0, 4)
            it[SCHEDULE_CACHE_WEEKS_KEY] = normalizedWeeks
            it[OFFLINE_SCHEDULE_ENABLED_KEY] = normalizedWeeks > 0
        }
    }

    suspend fun updateLiveActivityEnabled(enabled: Boolean) {
        context.dataStore.edit { it[LIVE_ACTIVITY_ENABLED_KEY] = enabled }
    }

    suspend fun updateOfflineScheduleEnabled(enabled: Boolean) {
        context.dataStore.edit {
            it[OFFLINE_SCHEDULE_ENABLED_KEY] = enabled
            val currentWeeks = it[SCHEDULE_CACHE_WEEKS_KEY] ?: 2
            if (enabled && currentWeeks == 0) {
                it[SCHEDULE_CACHE_WEEKS_KEY] = 2
            } else if (!enabled) {
                it[SCHEDULE_CACHE_WEEKS_KEY] = 0
            }
        }
    }

    suspend fun setOnboardingCompleted(completed: Boolean) {
        context.dataStore.edit { it[ONBOARDING_COMPLETED_KEY] = completed }
    }

    suspend fun saveAssistantHistory(historyJson: String) {
        context.dataStore.edit { it[ASSISTANT_HISTORY_KEY] = historyJson }
    }

    suspend fun clearAssistantHistory() {
        context.dataStore.edit { it.remove(ASSISTANT_HISTORY_KEY) }
    }

    suspend fun saveDismissedSystemNoticeId(id: Int) {
        context.dataStore.edit { it[DISMISSED_SYSTEM_NOTICE_ID_KEY] = id }
    }

    private suspend fun saveDeviceId(id: String) {
        context.dataStore.edit { it[DEVICE_ID_KEY] = id }
    }
}
