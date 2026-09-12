package ru.moonbaystudio.mympsu.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.remote.dto.AccountSession
import ru.moonbaystudio.mympsu.data.remote.dto.AppleUser
import ru.moonbaystudio.mympsu.data.remote.dto.GroupChangeRequestDto
import ru.moonbaystudio.mympsu.data.remote.dto.RoleRequest
import ru.moonbaystudio.mympsu.data.repository.AuthRepository
import javax.inject.Inject

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private val _success = MutableStateFlow<Boolean>(false)
    val success: StateFlow<Boolean> = _success.asStateFlow()

    private val _sessions = MutableStateFlow<List<AccountSession>>(emptyList())
    val sessions: StateFlow<List<AccountSession>> = _sessions.asStateFlow()

    private val _roleRequests = MutableStateFlow<List<RoleRequest>>(emptyList())
    val roleRequests: StateFlow<List<RoleRequest>> = _roleRequests.asStateFlow()

    private val _groupChangeRequests = MutableStateFlow<List<GroupChangeRequestDto>>(emptyList())
    val groupChangeRequests: StateFlow<List<GroupChangeRequestDto>> = _groupChangeRequests.asStateFlow()

    private val _isVerificationRequired = MutableStateFlow(false)
    val isVerificationRequired: StateFlow<Boolean> = _isVerificationRequired.asStateFlow()

    private val _pendingEmail = MutableStateFlow<String?>(null)
    val pendingEmail: StateFlow<String?> = _pendingEmail.asStateFlow()

    val isLoggedIn = authRepository.isLoggedIn

    val currentUser: StateFlow<AppleUser?> = authRepository.currentUser

    init {
        viewModelScope.launch {
            authRepository.isLoggedIn.collect { loggedIn ->
                if (loggedIn) {
                    _isLoading.value = true
                    authRepository.refreshUser()
                    authRepository.syncLocalSelectedGroup()
                    _isLoading.value = false
                }
            }
        }
    }

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.login(email, password)
            if (result.isFailure) {
                _error.value = result.exceptionOrNull()?.message ?: "Login failed"
            }
            _isLoading.value = false
        }
    }

    fun register(name: String, email: String, password: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.register(name, email, password)
            if (result.isSuccess) {
                _pendingEmail.value = email
                _isVerificationRequired.value = true
            } else {
                _error.value = result.exceptionOrNull()?.message ?: "Registration failed"
            }
            _isLoading.value = false
        }
    }

    fun verifySignup(code: String) {
        val email = _pendingEmail.value ?: return
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.verifySignup(email, code)
            if (result.isSuccess) {
                _isVerificationRequired.value = false
                _pendingEmail.value = null
            } else {
                _error.value = result.exceptionOrNull()?.message ?: "Verification failed"
            }
            _isLoading.value = false
        }
    }

    fun googleLogin(idToken: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.googleLogin(idToken)
            if (result.isFailure) {
                _error.value = result.exceptionOrNull()?.message ?: "Google login failed"
            }
            _isLoading.value = false
        }
    }

    fun linkGoogle(idToken: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.linkGoogle(idToken)
            if (result.isFailure) {
                _error.value = result.exceptionOrNull()?.message ?: "Google linking failed"
            }
            _isLoading.value = false
        }
    }

    fun logout() {
        viewModelScope.launch {
            authRepository.logout()
        }
    }

    fun updateProfile(name: String) {
        viewModelScope.launch {
            _isLoading.value = true
            val result = authRepository.updateProfile(name)
            if (result.isSuccess) _success.value = true
            _isLoading.value = false
        }
    }

    fun requestEmailChange(email: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.requestEmailChange(email)
            if (result.isSuccess) _success.value = true else _error.value = result.exceptionOrNull()?.message
            _isLoading.value = false
        }
    }

    fun confirmEmailChange(code: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.confirmEmailChange(code)
            if (result.isSuccess) _success.value = true else _error.value = result.exceptionOrNull()?.message
            _isLoading.value = false
        }
    }

    fun setupPassword(password: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.createPassword(password)
            if (result.isSuccess) _success.value = true else _error.value = result.exceptionOrNull()?.message
            _isLoading.value = false
        }
    }

    fun changePassword(current: String, new: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.changePassword(current, new)
            if (result.isSuccess) _success.value = true else _error.value = result.exceptionOrNull()?.message
            _isLoading.value = false
        }
    }

    fun requestPasswordReset(email: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.requestPasswordReset(email)
            if (result.isSuccess) _success.value = true else _error.value = result.exceptionOrNull()?.message
            _isLoading.value = false
        }
    }

    fun confirmPasswordReset(code: String, new: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.confirmPasswordReset(code, new)
            if (result.isSuccess) _success.value = true else _error.value = result.exceptionOrNull()?.message
            _isLoading.value = false
        }
    }

    fun resetStatus() {
        _success.value = false
        _error.value = null
        _isVerificationRequired.value = false
        _pendingEmail.value = null
    }

    fun loadSessions() {
        viewModelScope.launch {
            _isLoading.value = true
            _sessions.value = authRepository.getSessions()
            _isLoading.value = false
        }
    }

    fun revokeSession(sessionId: String) {
        viewModelScope.launch {
            authRepository.revokeSession(sessionId)
            loadSessions()
        }
    }

    fun logoutOthers() {
        viewModelScope.launch {
            authRepository.logoutOthers()
            loadSessions()
        }
    }

    fun loadRoleRequests() {
        loadMyRequests()
    }

    fun loadMyRequests() {
        viewModelScope.launch {
            _roleRequests.value = authRepository.getMyRoleRequests()
            _groupChangeRequests.value = authRepository.getMyGroupChangeRequests()
        }
    }

    fun requestTesterRole() {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.createRoleRequest(
                type = "tester",
                groupId = null,
                groupName = null,
                comment = "Хочу тестировать Android-версию MyMPSU"
            )
            if (result.isSuccess) {
                loadMyRequests()
            } else {
                _error.value = result.exceptionOrNull()?.message ?: "Не удалось отправить заявку"
            }
            _isLoading.value = false
        }
    }

    fun cancelRoleRequest(requestId: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.cancelRoleRequest(requestId)
            if (result.isSuccess) {
                loadMyRequests()
            } else {
                _error.value = result.exceptionOrNull()?.message ?: "Не удалось отменить заявку"
            }
            _isLoading.value = false
        }
    }

    fun cancelGroupChangeRequest(requestId: Int) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            val result = authRepository.cancelGroupChangeRequest(requestId)
            if (result.isSuccess) {
                loadMyRequests()
            } else {
                _error.value = result.exceptionOrNull()?.message ?: "Не удалось отменить заявку"
            }
            _isLoading.value = false
        }
    }

    fun requestEmailVerification(email: String) {
        viewModelScope.launch {
            _isLoading.value = true
            val result = authRepository.requestEmailVerification(email)
            if (result.isFailure) {
                _error.value = result.exceptionOrNull()?.message ?: "Request failed"
            }
            _isLoading.value = false
        }
    }

    fun resendEmailVerification() {
        viewModelScope.launch {
            _isLoading.value = true
            val result = authRepository.resendEmailVerification()
            if (result.isFailure) {
                _error.value = result.exceptionOrNull()?.message ?: "Resend failed"
            }
            _isLoading.value = false
        }
    }
}
