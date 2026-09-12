package ru.moonbaystudio.mympsu.data.repository

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.data.remote.MyMPSUApiService
import ru.moonbaystudio.mympsu.data.remote.dto.*
import ru.moonbaystudio.mympsu.util.*
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val apiService: MyMPSUApiService,
    private val userPreferences: UserPreferences
) {
    private val _currentUser = MutableStateFlow<AppleUser?>(null)
    val currentUser: StateFlow<AppleUser?> = _currentUser.asStateFlow()

    val isLoggedIn = userPreferences.authToken.map { it != null }

    suspend fun login(email: String, password: String): Result<Unit> {
        val deviceIdValue = userPreferences.deviceId.first()
        val request = PasswordLoginRequest(
            email = email,
            password = password,
            deviceId = deviceIdValue,
            deviceName = android.os.Build.MODEL,
            appVersion = "1.0"
        )
        val result = safeApiCall { apiService.login(request) }.toResult()
        return result.fold(
            onSuccess = { body ->
                userPreferences.saveAuthToken(body.token)
                _currentUser.value = body.user
                syncLocalSelectedGroup()
                Result.success(Unit)
            },
            onFailure = { Result.failure(it) }
        )
    }

    suspend fun register(name: String, email: String, password: String): Result<Unit> {
        val request = SignupRequest(
            email = email,
            password = password,
            displayName = name
        )
        return safeApiCall { apiService.signup(request) }.toResult().map { Unit }
    }

    suspend fun verifySignup(email: String, code: String): Result<Unit> {
        val deviceIdValue = userPreferences.deviceId.first()
        val request = SignupVerifyRequest(
            email = email,
            code = code,
            deviceId = deviceIdValue,
            deviceName = android.os.Build.MODEL,
            appVersion = "1.0"
        )
        val result = safeApiCall { apiService.signupVerify(request) }.toResult()
        return result.fold(
            onSuccess = { body ->
                userPreferences.saveAuthToken(body.token)
                _currentUser.value = body.user
                syncLocalSelectedGroup()
                Result.success(Unit)
            },
            onFailure = { Result.failure(it) }
        )
    }

    suspend fun googleLogin(idToken: String): Result<Unit> {
        val deviceIdValue = userPreferences.deviceId.first()
        val request = GoogleLoginRequest(
            idToken = idToken,
            deviceId = deviceIdValue,
            deviceName = android.os.Build.MODEL,
            appVersion = "1.0",
            systemVersion = android.os.Build.VERSION.RELEASE
        )
        val result = safeApiCall { apiService.googleLogin(request) }.toResult()
        return result.fold(
            onSuccess = { body ->
                userPreferences.saveAuthToken(body.token)
                _currentUser.value = body.user
                syncLocalSelectedGroup()
                Result.success(Unit)
            },
            onFailure = { Result.failure(it) }
        )
    }

    suspend fun linkGoogle(idToken: String): Result<AppleUser> {
        val deviceIdValue = userPreferences.deviceId.first()
        val request = GoogleLoginRequest(
            idToken = idToken,
            deviceId = deviceIdValue,
            deviceName = android.os.Build.MODEL,
            appVersion = "1.0",
            systemVersion = android.os.Build.VERSION.RELEASE
        )
        val result = safeApiCall { apiService.linkGoogle(request) }.toResult()
        return result.onSuccess { _currentUser.value = it }
    }

    suspend fun logout() {
        userPreferences.clearAuthToken()
        _currentUser.value = null
    }

    suspend fun refreshUser() {
        safeApiCall { apiService.getProfile() }.toResult().onSuccess {
            _currentUser.value = it
        }
    }

    suspend fun updateProfile(name: String): Result<AppleUser> {
        return safeApiCall { apiService.updateProfile(UpdateProfileRequest(name)) }
            .toResult()
            .onSuccess { _currentUser.value = it }
    }

    suspend fun createPassword(password: String): Result<Unit> {
        return safeApiCall { apiService.createPassword(PasswordSetupRequest(password)) }.toResult().map { Unit }
    }

    suspend fun changePassword(current: String, new: String): Result<Unit> {
        return safeApiCall { apiService.changePassword(PasswordChangeRequest(current, new)) }.toResult().map { Unit }
    }

    suspend fun requestEmailChange(email: String): Result<Unit> {
        return safeApiCall { apiService.requestEmailChange(EmailChangeRequest(email)) }.toResult().map { Unit }
    }

    suspend fun confirmEmailChange(code: String): Result<AppleUser> {
        return safeApiCall { apiService.confirmEmailChange(EmailConfirmRequest(code)) }
            .toResult()
            .onSuccess { _currentUser.value = it }
    }

    suspend fun getSessions(): List<AccountSession> {
        return safeApiCall { apiService.getSessions() }.toResult().getOrElse { emptyList() }
    }

    suspend fun revokeSession(sessionId: String): Result<Unit> {
        return safeApiCall { apiService.revokeSession(sessionId) }.toResult().map { Unit }
    }

    suspend fun logoutOthers(): Result<Unit> {
        return safeApiCall { apiService.logoutOthers() }.toResult().map { Unit }
    }

    suspend fun getMyRoleRequests(): List<RoleRequest> {
        return safeApiCall { apiService.getMyRoleRequests() }.toResult().getOrElse { emptyList() }
    }

    suspend fun getMyGroupChangeRequests(): List<GroupChangeRequestDto> {
        return safeApiCall { apiService.getMyGroupChangeRequests() }.toResult().getOrElse { emptyList() }
    }

    suspend fun createRoleRequest(type: String, groupId: Int?, groupName: String?, comment: String?): Result<RoleRequest> {
        return safeApiCall { apiService.createRoleRequest(RoleRequestCreateRequest(type, groupId, groupName, comment)) }.toResult()
    }

    suspend fun cancelRoleRequest(requestId: String): Result<RoleRequest> {
        return safeApiCall { apiService.cancelRoleRequest(requestId) }.toResult()
    }

    suspend fun cancelGroupChangeRequest(requestId: Int): Result<GroupChangeRequestDto> {
        return safeApiCall { apiService.cancelGroupChangeRequest(requestId) }.toResult()
    }

    suspend fun requestEmailVerification(email: String): Result<Unit> {
        return safeApiCall { apiService.requestContactEmail(ContactEmailRequest(email)) }.toResult().map { Unit }
    }

    suspend fun resendEmailVerification(): Result<Unit> {
        return safeApiCall { apiService.resendContactEmailVerification() }.toResult().map { Unit }
    }

    suspend fun getGroupUsers(groupId: Int): List<GroupUserDto> {
        return safeApiCall { apiService.getGroupUsers(groupId) }.toResult().getOrElse { emptyList() }
    }

    suspend fun getAdminUsers(): List<AdminUserDto> {
        return safeApiCall { apiService.getAdminUsers() }.toResult().getOrElse { emptyList() }
    }

    suspend fun getAdminRoleRequests(status: String): List<AdminRoleRequestDto> {
        return safeApiCall { apiService.getAdminRoleRequests(status) }.toResult().getOrElse { emptyList() }
    }

    suspend fun getGroupChangeRequests(status: String): List<GroupChangeRequestDto> {
        return safeApiCall { apiService.getGroupChangeRequests(status) }.toResult().getOrElse { emptyList() }
    }

    suspend fun approveRoleRequest(requestId: Int): Result<Unit> {
        return safeApiCall { apiService.approveRoleRequest(requestId) }.toResult().map { Unit }
    }

    suspend fun rejectRoleRequest(requestId: Int, comment: String? = null): Result<Unit> {
        return safeApiCall {
            apiService.rejectRoleRequest(requestId, RoleRequestReviewRequest(comment))
        }.toResult().map { Unit }
    }

    suspend fun approveGroupChangeRequest(requestId: Int): Result<Unit> {
        return safeApiCall { apiService.approveGroupChangeRequest(requestId) }.toResult().map { Unit }
    }

    suspend fun rejectGroupChangeRequest(requestId: Int, comment: String? = null): Result<Unit> {
        return safeApiCall {
            apiService.rejectGroupChangeRequest(requestId, GroupChangeRequestReviewRequest(comment))
        }.toResult().map { Unit }
    }

    suspend fun grantRole(userId: String, role: String): Result<Unit> {
        return safeApiCall { apiService.grantRole(GrantRoleRequest(userId, role)) }.toResult().map { Unit }
    }

    suspend fun revokeRole(userId: String, role: String): Result<Unit> {
        return safeApiCall { apiService.revokeRole(GrantRoleRequest(userId, role)) }.toResult().map { Unit }
    }

    suspend fun getAdminBadges(): List<BadgeDto> {
        return safeApiCall { apiService.getAdminBadges() }.toResult().getOrElse { emptyList() }
    }

    suspend fun grantBadge(userId: String, badgeCode: String, note: String?): Result<AdminUserDto> {
        return safeApiCall { apiService.grantBadge(userId, BadgeMutationRequest(badgeCode, note)) }.toResult()
    }

    suspend fun revokeBadge(userId: String, badgeCode: String): Result<AdminUserDto> {
        return safeApiCall { apiService.revokeBadge(userId, badgeCode) }.toResult()
    }

    suspend fun getAdminSettings(): List<AdminRuntimeSetting> {
        return safeApiCall { apiService.getAdminSettings() }.toResult().getOrElse { emptyList() }
    }

    suspend fun updateAdminSetting(key: String, value: Any): Result<AdminRuntimeSetting> {
        return safeApiCall { apiService.updateAdminSetting(key, RuntimeSettingPatchRequest(value)) }.toResult()
    }

    suspend fun getAdminSystemNotices(): List<SystemNotice> {
        return safeApiCall { apiService.getAdminSystemNotices() }.toResult().getOrElse { emptyList() }
    }

    suspend fun createAdminSystemNotice(request: SystemNoticeMutationRequest): Result<SystemNotice> {
        return safeApiCall { apiService.createAdminSystemNotice(request) }.toResult()
    }

    suspend fun updateAdminSystemNotice(id: Int, request: SystemNoticeMutationRequest): Result<SystemNotice> {
        return safeApiCall { apiService.updateAdminSystemNotice(id, request) }.toResult()
    }

    suspend fun deleteAdminSystemNotice(id: Int): Result<Unit> {
        return safeApiCall { apiService.deleteAdminSystemNotice(id) }.toResult().map { Unit }
    }

    suspend fun activateSystemNotice(id: Int): Result<Unit> {
        return safeApiCall { apiService.activateSystemNotice(id) }.toResult().map { Unit }
    }

    suspend fun deactivateSystemNotice(id: Int): Result<Unit> {
        return safeApiCall { apiService.deactivateSystemNotice(id) }.toResult().map { Unit }
    }

    suspend fun getAdminUserSessions(userId: String): List<AccountSession> {
        return safeApiCall { apiService.getAdminUserSessions(userId) }.toResult().getOrElse { emptyList() }
    }

    suspend fun revokeAdminSession(sessionId: String): Result<Unit> {
        return safeApiCall { apiService.revokeAdminSession(sessionId) }.toResult().map { Unit }
    }

    suspend fun requestPasswordReset(email: String): Result<Unit> {
        return safeApiCall { apiService.requestPasswordReset(ResetPasswordRequest(email)) }.toResult().map { Unit }
    }

    suspend fun confirmPasswordReset(code: String, newPassword: String): Result<Unit> {
        return safeApiCall { apiService.confirmPasswordReset(ResetPasswordConfirmRequest(code, newPassword)) }.toResult().map { Unit }
    }

    suspend fun pushLocalSettingsToAccount(): Result<Unit> {
        val groupId = userPreferences.selectedGroupId.first() ?: return Result.success(Unit)
        val groupName = userPreferences.selectedGroupName.first() ?: groupId.toString()
        val settings = UserSettings(
            selectedGroupId = groupId,
            selectedGroupName = groupName,
            scheduleCacheWeeks = userPreferences.scheduleCacheWeeks.first(),
            liveActivityEnabled = userPreferences.liveActivityEnabled.first()
        )
        return safeApiCall { apiService.updateSettings(settings) }.toResult().map { Unit }
    }

    suspend fun syncLocalSelectedGroup() {
        // Небольшая задержка, чтобы токен точно прописался в заголовках OkHttp
        kotlinx.coroutines.delay(100)
        val remoteSettings = when (val result = safeApiCall { apiService.getSettings() }) {
            is NetworkResult.Success -> result.data
            else -> null
        }

        if (remoteSettings?.selectedGroupId != null) {
            userPreferences.saveUserSettings(
                selectedGroupId = remoteSettings.selectedGroupId,
                selectedGroupName = remoteSettings.selectedGroupName ?: remoteSettings.selectedGroupId.toString(),
                scheduleCacheWeeks = remoteSettings.scheduleCacheWeeks,
                liveActivityEnabled = remoteSettings.liveActivityEnabled
            )
            return
        }

        val groupId = userPreferences.selectedGroupId.first() ?: return
        val groupName = userPreferences.selectedGroupName.first() ?: groupId.toString()
        val settings = UserSettings(
            selectedGroupId = groupId,
            selectedGroupName = groupName,
            scheduleCacheWeeks = userPreferences.scheduleCacheWeeks.first(),
            liveActivityEnabled = userPreferences.liveActivityEnabled.first()
        )
        safeApiCall { apiService.updateSettings(settings) }
    }
}
