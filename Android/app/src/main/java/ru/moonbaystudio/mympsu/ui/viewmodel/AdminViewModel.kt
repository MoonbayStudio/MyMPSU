package ru.moonbaystudio.mympsu.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.remote.dto.*
import ru.moonbaystudio.mympsu.data.repository.AuthRepository
import javax.inject.Inject

@HiltViewModel
class AdminViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {
    private val _users = MutableStateFlow<List<AdminUserDto>>(emptyList())
    val users: StateFlow<List<AdminUserDto>> = _users.asStateFlow()

    private val _requests = MutableStateFlow<List<AdminRoleRequestDto>>(emptyList())
    val requests: StateFlow<List<AdminRoleRequestDto>> = _requests.asStateFlow()

    private val _groupChangeRequests = MutableStateFlow<List<GroupChangeRequestDto>>(emptyList())
    val groupChangeRequests: StateFlow<List<GroupChangeRequestDto>> = _groupChangeRequests.asStateFlow()

    private val _badges = MutableStateFlow<List<BadgeDto>>(emptyList())
    val badges: StateFlow<List<BadgeDto>> = _badges.asStateFlow()

    private val _settings = MutableStateFlow<List<AdminRuntimeSetting>>(emptyList())
    val settings: StateFlow<List<AdminRuntimeSetting>> = _settings.asStateFlow()

    private val _notices = MutableStateFlow<List<SystemNotice>>(emptyList())
    val notices: StateFlow<List<SystemNotice>> = _notices.asStateFlow()

    private val _userSessions = MutableStateFlow<List<AccountSession>>(emptyList())
    val userSessions: StateFlow<List<AccountSession>> = _userSessions.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    fun loadAllData() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                _users.value = authRepository.getAdminUsers()
                _requests.value = authRepository.getAdminRoleRequests("pending")
                _groupChangeRequests.value = authRepository.getGroupChangeRequests("pending")
                _badges.value = authRepository.getAdminBadges()
                _settings.value = authRepository.getAdminSettings()
                _notices.value = authRepository.getAdminSystemNotices()
            } catch (e: Exception) {
                _errorMessage.value = "Ошибка загрузки: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun approveRequest(requestId: Int) {
        viewModelScope.launch {
            authRepository.approveRoleRequest(requestId).onSuccess { loadAllData() }
        }
    }

    fun rejectRequest(requestId: Int, comment: String? = null) {
        viewModelScope.launch {
            authRepository.rejectRoleRequest(requestId, comment).onSuccess { loadAllData() }
        }
    }

    fun approveGroupChangeRequest(requestId: Int) {
        viewModelScope.launch {
            authRepository.approveGroupChangeRequest(requestId).onSuccess { loadAllData() }
        }
    }

    fun rejectGroupChangeRequest(requestId: Int, comment: String? = null) {
        viewModelScope.launch {
            authRepository.rejectGroupChangeRequest(requestId, comment).onSuccess { loadAllData() }
        }
    }

    fun setRole(userId: String, role: String, enabled: Boolean) {
        viewModelScope.launch {
            val result = if (enabled) authRepository.grantRole(userId, role) else authRepository.revokeRole(userId, role)
            result.onSuccess { loadAllData() }
        }
    }

    fun setBadge(userId: String, badgeCode: String, enabled: Boolean, note: String?) {
        viewModelScope.launch {
            val result = if (enabled) authRepository.grantBadge(userId, badgeCode, note) else authRepository.revokeBadge(userId, badgeCode)
            result.onSuccess { loadAllData() }
        }
    }

    fun updateSetting(key: String, value: Any) {
        viewModelScope.launch {
            authRepository.updateAdminSetting(key, value).onSuccess { loadAllData() }
        }
    }

    fun deleteNotice(id: Int) {
        viewModelScope.launch {
            authRepository.deleteAdminSystemNotice(id).onSuccess { loadAllData() }
        }
    }

    fun toggleNotice(id: Int, active: Boolean) {
        viewModelScope.launch {
            val result = if (active) authRepository.activateSystemNotice(id) else authRepository.deactivateSystemNotice(id)
            result.onSuccess { loadAllData() }
        }
    }

    fun loadUserSessions(userId: String) {
        viewModelScope.launch {
            _userSessions.value = authRepository.getAdminUserSessions(userId)
        }
    }

    fun revokeUserSession(userId: String, sessionId: String) {
        viewModelScope.launch {
            authRepository.revokeAdminSession(sessionId).onSuccess { loadUserSessions(userId) }
        }
    }

    fun createNotice(request: SystemNoticeMutationRequest) {
        viewModelScope.launch {
            authRepository.createAdminSystemNotice(request).onSuccess { loadAllData() }
        }
    }
}
