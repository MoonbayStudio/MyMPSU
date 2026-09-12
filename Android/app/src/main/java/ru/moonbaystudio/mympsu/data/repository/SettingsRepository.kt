package ru.moonbaystudio.mympsu.data.repository

import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.data.remote.MyMPSUApiService
import ru.moonbaystudio.mympsu.data.remote.dto.GroupChangeRequestCreateRequest
import ru.moonbaystudio.mympsu.data.remote.dto.UserSettings
import ru.moonbaystudio.mympsu.util.NetworkResult
import ru.moonbaystudio.mympsu.util.safeApiCall
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

sealed class GroupSelectionResult {
    data object Applied : GroupSelectionResult()
    data object ChangeRequestCreated : GroupSelectionResult()
    data class Error(val message: String) : GroupSelectionResult()
}

@Singleton
class SettingsRepository @Inject constructor(
    private val userPreferences: UserPreferences,
    private val apiService: MyMPSUApiService
) {
    val selectedGroupId = userPreferences.selectedGroupId
    val selectedGroupName = userPreferences.selectedGroupName
    val scheduleCacheWeeks = userPreferences.scheduleCacheWeeks
    val offlineScheduleEnabled = userPreferences.offlineScheduleEnabled
    val offlineScheduleWeeks = userPreferences.scheduleCacheWeeks
    val liveActivityEnabled = userPreferences.liveActivityEnabled

    suspend fun saveSelectedGroup(id: Int, name: String): GroupSelectionResult {
        val token = userPreferences.authToken.first()
        if (token.isNullOrBlank()) {
            val currentGroupId = userPreferences.selectedGroupId.first()
            if (currentGroupId != null && currentGroupId != id) {
                return GroupSelectionResult.Error("Чтобы сменить группу, войдите в аккаунт.")
            }
            userPreferences.saveSelectedGroup(id, name)
            return GroupSelectionResult.Applied
        }

        val remoteSettings = when (val result = safeApiCall { apiService.getSettings() }) {
            is NetworkResult.Success -> result.data
            else -> null
        }

        val currentGroupId = remoteSettings?.selectedGroupId ?: userPreferences.selectedGroupId.first()
        if (currentGroupId == null || currentGroupId == id) {
            userPreferences.saveSelectedGroup(id, name)
            syncSelectedGroup(id, name, remoteSettings)
            return GroupSelectionResult.Applied
        }

        if (remoteSettings?.selectedGroupId != null) {
            userPreferences.saveSelectedGroup(
                remoteSettings.selectedGroupId,
                remoteSettings.selectedGroupName ?: remoteSettings.selectedGroupId.toString()
            )
        }

        val request = GroupChangeRequestCreateRequest(
            requestedGroupId = id,
            requestedGroupName = name
        )
        return when (safeApiCall { apiService.createGroupChangeRequest(request) }) {
            is NetworkResult.Success -> GroupSelectionResult.ChangeRequestCreated
            else -> GroupSelectionResult.Error("Не удалось отправить заявку на смену группы.")
        }
    }

    suspend fun selectScheduleGroup(id: Int, name: String): GroupSelectionResult {
        val token = userPreferences.authToken.first()
        val remoteSettings = if (token.isNullOrBlank()) {
            null
        } else {
            when (val result = safeApiCall { apiService.getSettings() }) {
                is NetworkResult.Success -> result.data
                else -> null
            }
        }

        val defaultGroupId = remoteSettings?.selectedGroupId ?: userPreferences.selectedGroupId.first()
        if (defaultGroupId == null) {
            return saveSelectedGroup(id, name)
        }

        if (remoteSettings?.selectedGroupId != null) {
            userPreferences.saveSelectedGroup(
                remoteSettings.selectedGroupId,
                remoteSettings.selectedGroupName ?: remoteSettings.selectedGroupId.toString()
            )
        }
        userPreferences.saveScheduleGroup(id, name)
        return GroupSelectionResult.Applied
    }

    suspend fun updateScheduleCacheWeeks(weeks: Int) {
        userPreferences.updateScheduleCacheWeeks(weeks)
    }

    suspend fun updateOfflineScheduleEnabled(enabled: Boolean) {
        userPreferences.updateOfflineScheduleEnabled(enabled)
    }

    suspend fun updateLiveActivityEnabled(enabled: Boolean) {
        userPreferences.updateLiveActivityEnabled(enabled)
    }

    private suspend fun syncSelectedGroup(id: Int, name: String, remoteSettings: UserSettings? = null) {
        val token = userPreferences.authToken.first() ?: return
        if (token.isBlank()) return

        val settings = UserSettings(
            selectedGroupId = id,
            selectedGroupName = name,
            scheduleCacheWeeks = remoteSettings?.scheduleCacheWeeks ?: userPreferences.scheduleCacheWeeks.first(),
            liveActivityEnabled = remoteSettings?.liveActivityEnabled ?: userPreferences.liveActivityEnabled.first()
        )
        safeApiCall { apiService.updateSettings(settings) }
    }
}
