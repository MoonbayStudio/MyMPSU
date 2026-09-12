package ru.moonbaystudio.mympsu.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.data.repository.ScheduleRepository
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val userPreferences: UserPreferences,
    private val repository: ScheduleRepository
) : ViewModel() {
    val defaultPersona = userPreferences.defaultPersona.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "pelikasha")
    val selectedGroupName = userPreferences.selectedGroupName.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)
    val selectedThemeId = userPreferences.selectedThemeId.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "classic")
    val selectedThemeFamilyId = userPreferences.selectedThemeFamilyId.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "standard")
    val followSystemTheme = userPreferences.followSystemTheme.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), true)
    val scheduleCacheWeeks = userPreferences.scheduleCacheWeeks.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 2)
    val liveActivityEnabled = userPreferences.liveActivityEnabled.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), true)
    val offlineScheduleEnabled = userPreferences.offlineScheduleEnabled.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), true)
    val reduceMotion = userPreferences.reduceMotion.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)
    val highContrast = userPreferences.highContrast.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)
    val largerText = userPreferences.largerText.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)
    val autoSpeakSchedule = userPreferences.autoSpeakSchedule.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)
    val speechDetailed = userPreferences.speechDetailed.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), true)
    val hapticsEnabled = userPreferences.hapticsEnabled.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), true)

    fun updateDefaultPersona(persona: String) = viewModelScope.launch {
        userPreferences.updateDefaultPersona(persona)
    }

    fun updateHighContrast(enabled: Boolean) = viewModelScope.launch {
        userPreferences.updateHighContrast(enabled)
    }

    fun updateReduceMotion(enabled: Boolean) = viewModelScope.launch {
        userPreferences.updateReduceMotion(enabled)
    }

    fun updateLargerText(enabled: Boolean) = viewModelScope.launch {
        userPreferences.updateLargerText(enabled)
    }

    fun updateAutoSpeakSchedule(enabled: Boolean) = viewModelScope.launch {
        userPreferences.updateAutoSpeakSchedule(enabled)
    }

    fun updateSpeechDetailed(enabled: Boolean) = viewModelScope.launch {
        userPreferences.updateSpeechDetailed(enabled)
    }

    fun updateHapticsEnabled(enabled: Boolean) = viewModelScope.launch {
        userPreferences.updateHapticsEnabled(enabled)
    }

    fun updateTheme(themeId: String) = viewModelScope.launch {
        userPreferences.saveThemeId(themeId)
    }

    fun updateThemeFamily(familyId: String) = viewModelScope.launch {
        userPreferences.saveThemeFamilyId(familyId)
    }

    fun updateFollowSystemTheme(enabled: Boolean) = viewModelScope.launch {
        userPreferences.updateFollowSystemTheme(enabled)
    }

    fun updateScheduleCacheWeeks(weeks: Int) = viewModelScope.launch {
        userPreferences.updateScheduleCacheWeeks(weeks)
    }

    fun updateOfflineScheduleEnabled(enabled: Boolean) = viewModelScope.launch {
        userPreferences.updateOfflineScheduleEnabled(enabled)
    }

    fun updateLiveActivityEnabled(enabled: Boolean) = viewModelScope.launch {
        userPreferences.updateLiveActivityEnabled(enabled)
    }

    fun clearCache() {
        viewModelScope.launch {
            userPreferences.selectedGroupId.first()?.let { groupId ->
                repository.clearCache(groupId)
            }
        }
    }
}
