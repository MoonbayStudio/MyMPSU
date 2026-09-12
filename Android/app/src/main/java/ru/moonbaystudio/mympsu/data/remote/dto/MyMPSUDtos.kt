package ru.moonbaystudio.mympsu.data.remote.dto

import com.google.gson.annotations.SerializedName

data class GrantRoleRequest(
    @SerializedName("user_id") val userId: String,
    val role: String
)

data class GoogleLoginRequest(
    val idToken: String,
    val deviceId: String?,
    val deviceName: String?,
    val platform: String = "android",
    @SerializedName("appVersion") val appVersion: String?,
    @SerializedName("systemVersion") val systemVersion: String?
)

data class AssistantChatRequest(
    val message: String,
    val persona: String,
    val messages: List<AssistantChatMessagePayload>? = null,
    val context: AssistantContext,
    @SerializedName("conversationId") val conversationId: String,
    @SerializedName("groupId") val groupId: Int?,
    @SerializedName("groupName") val groupName: String?,
    @SerializedName("targetDate") val targetDate: String?,
    @SerializedName("cachedSchedule") val cachedSchedule: CachedSchedulePayload?
)

data class AssistantChatMessagePayload(
    val role: String,
    val content: String
)

data class AssistantContext(
    @SerializedName("selectedGroupId") val selectedGroupId: Int?,
    @SerializedName("selectedGroupName") val selectedGroupName: String?,
    @SerializedName("selectedDate") val selectedDate: String?
)

data class CachedSchedulePayload(
    @SerializedName("generatedAt") val generatedAt: String,
    val source: String = "android_cache",
    val lessons: List<CachedScheduleLessonPayload>
)

data class CachedScheduleLessonPayload(
    val name: String,
    val type: String?,
    @SerializedName("startTime") val startTime: String,
    @SerializedName("endTime") val endTime: String,
    val date: String? = null,
    val room: String?,
    val teacher: String?,
    @SerializedName("roomId") val roomId: Int?,
    @SerializedName("teacherId") val teacherId: Int?,
    @SerializedName("classUrl") val classUrl: String?,
    val note: String?,
    @SerializedName("isExam") val isExam: Boolean?
)

data class AssistantChatResponse(
    val reply: String,
    val remaining: Int,
    val plan: String
)

data class PublicConfigResponse(
    val settings: Map<String, Any> = emptyMap()
)

data class ActiveSystemNoticeResponse(
    @SerializedName("isActive") val isActive: Boolean = false,
    val notice: SystemNotice? = null
)

data class PasswordLoginRequest(
    val email: String,
    val password: String,
    @SerializedName("deviceId") val deviceId: String?,
    @SerializedName("deviceName") val deviceName: String?,
    val platform: String = "android",
    @SerializedName("appVersion") val appVersion: String?
)

data class RegisterRequest(
    val name: String,
    val email: String,
    val password: String,
    @SerializedName("deviceId") val deviceId: String?,
    @SerializedName("deviceName") val deviceName: String?,
    val platform: String = "android",
    @SerializedName("appVersion") val appVersion: String?
)

data class AppleSignInResponse(
    val token: String,
    val user: AppleUser
)

data class UserRole(
    val type: String,
    val title: String,
    @SerializedName("groupId") val groupId: Int?
)

data class BadgeDto(
    val code: String,
    val title: String,
    val description: String?,
    @SerializedName("icon_name") val iconName: String,
    val rarity: String
)

data class AppleUser(
    val id: String,
    @SerializedName("displayName") val displayName: String? = null,
    val email: String?,
    @SerializedName("appleEmail") val appleEmail: String?,
    @SerializedName("contactEmail") val contactEmail: String?,
    @SerializedName("contactEmailVerified") val contactEmailVerified: Boolean = false,
    @SerializedName("pendingContactEmail") val pendingContactEmail: String?,
    @SerializedName("needsContactEmail") val needsContactEmail: Boolean = false,
    @SerializedName("isAppleRelayEmail") val isAppleRelayEmail: Boolean = false,
    val roles: List<UserRole> = emptyList(),
    val badges: List<BadgeDto> = emptyList(),
    val tier: String = "free",
    @SerializedName("remainingToday") val remainingToday: Int? = null,
    @SerializedName("scheduleCacheWeeks") val scheduleCacheWeeks: Int = 2,
    @SerializedName("liveActivityEnabled") val liveActivityEnabled: Boolean = true,
    @SerializedName("hasPassword") val hasPassword: Boolean = false,
    @SerializedName("emailVerified") val emailVerified: Boolean = false,
    @SerializedName("pendingEmail") val pendingEmail: String?,
    @SerializedName("linkedProviders") val linkedProviders: List<String> = emptyList()
) {
    val isAdmin: Boolean get() = roles.any { it.type == "admin" }
    val isModerator: Boolean get() = roles.any { it.type == "moderator" }
    val isGroupLeader: Boolean get() = roles.any { it.type == "group_leader" }
    val isTester: Boolean get() = roles.any { it.type == "tester" }

    val name: String? get() = displayName
}

data class UserSettings(
    @SerializedName("selectedGroupId") val selectedGroupId: Int?,
    @SerializedName("selectedGroupName") val selectedGroupName: String?,
    @SerializedName("scheduleCacheWeeks") val scheduleCacheWeeks: Int = 2,
    @SerializedName("liveActivityEnabled") val liveActivityEnabled: Boolean = true
)

data class Homework(
    val id: String,
    @SerializedName("group_id") val groupId: Int,
    @SerializedName("lesson_date") val lessonDate: String,
    @SerializedName("lesson_time") val lessonTime: String,
    val subject: String,
    val teacher: String?,
    val room: String?,
    val text: String,
    @SerializedName("created_by") val createdBy: String?,
    @SerializedName("created_at") val createdAt: String?,
    @SerializedName("updated_at") val updatedAt: String?
)

data class HomeworkMutationRequest(
    @SerializedName("lesson_date") val lessonDate: String,
    @SerializedName("lesson_time") val lessonTime: String,
    val subject: String,
    val teacher: String?,
    val room: String?,
    val text: String
)

data class HomeworkUpdateRequest(
    val text: String
)

data class UpdateProfileRequest(val displayName: String)

data class PasswordSetupRequest(val password: String)

data class PasswordChangeRequest(
    val currentPassword: String,
    val newPassword: String
)

data class ResetPasswordRequest(val email: String)

data class ResetPasswordConfirmRequest(
    val code: String,
    val newPassword: String
)

data class EmailChangeRequest(val email: String)

data class EmailConfirmRequest(val code: String)

data class ContactEmailRequest(val email: String)

data class SuccessResponse(val success: Boolean)

data class SignupRequest(
    val email: String,
    val password: String,
    @SerializedName("displayName") val displayName: String
)

data class SignupResponse(
    val status: String,
    val email: String
)

data class SignupVerifyRequest(
    val email: String,
    val code: String,
    @SerializedName("deviceId") val deviceId: String?,
    @SerializedName("deviceName") val deviceName: String?,
    val platform: String = "android",
    @SerializedName("appVersion") val appVersion: String?
)

data class AccountSession(
    val id: String,
    @SerializedName("device_id", alternate = ["deviceId"]) val deviceId: String?,
    @SerializedName("device_name", alternate = ["deviceName"]) val deviceName: String?,
    val platform: String?,
    @SerializedName("app_version", alternate = ["appVersion"]) val appVersion: String?,
    @SerializedName("ip_address", alternate = ["ipAddress"]) val ipAddress: String?,
    @SerializedName("masked_ip", alternate = ["maskedIp"]) val maskedIp: String?,
    @SerializedName("user_agent", alternate = ["userAgent"]) val userAgent: String?,
    @SerializedName("created_at", alternate = ["createdAt"]) val createdAt: String?,
    @SerializedName("last_seen_at", alternate = ["lastSeenAt"]) val lastSeenAt: String?,
    @SerializedName("revoked_at", alternate = ["revokedAt"]) val revokedAt: String?,
    @SerializedName("is_current", alternate = ["isCurrent"]) val isCurrent: Boolean
) {
    val safeIpText: String?
        get() {
            if (!maskedIp.isNullOrBlank()) return maskedIp
            val ip = ipAddress ?: return null
            if (ip.contains(":")) return "IPv6 скрыт"
            val parts = ip.split(".")
            return if (parts.size == 4) "${parts[0]}.${parts[1]}.***.***" else "IP скрыт"
        }
}

data class AdminRuntimeSetting(
    val key: String,
    val value: Any, // Can be Boolean, Int, String
    @SerializedName("valueType") val valueType: String? = null,
    val description: String? = null,
    @SerializedName("isPublic") val isPublic: Boolean = false
)

data class SystemNotice(
    val id: Int,
    val title: String,
    val message: String,
    val type: String, // info, warning, maintenance, critical
    @SerializedName("showAs", alternate = ["show_as"]) val showAs: String, // banner, modal
    val dismissible: Boolean,
    @SerializedName("startsAt", alternate = ["starts_at"]) val startsAt: String?,
    @SerializedName("endsAt", alternate = ["ends_at"]) val endsAt: String?,
    @SerializedName("isActive", alternate = ["is_active"]) val isActive: Boolean?
)

data class SystemNoticeMutationRequest(
    val title: String,
    val message: String,
    val type: String,
    @SerializedName("showAs") val showAs: String,
    val dismissible: Boolean,
    @SerializedName("startsAt") val startsAt: String?,
    @SerializedName("endsAt") val endsAt: String?,
    @SerializedName("isActive") val isActive: Boolean? = null
)

data class RoleRequestCreateRequest(
    @SerializedName("roleType") val roleType: String,
    @SerializedName("groupId") val groupId: Int?,
    @SerializedName("groupName") val groupName: String?,
    val comment: String?
)

data class RoleRequest(
    val id: String,
    @SerializedName("roleType", alternate = ["role_type", "requestedRole"]) val roleType: String,
    val status: String,
    @SerializedName("createdAt", alternate = ["created_at"]) val createdAt: String,
    @SerializedName("reviewComment") val reviewComment: String? = null,
    val comment: String? = null
)

data class GroupChangeRequestCreateRequest(
    @SerializedName("requestedGroupId") val requestedGroupId: Int,
    @SerializedName("requestedGroupName") val requestedGroupName: String?,
    val comment: String? = null
)

data class GroupChangeRequestReviewRequest(
    val comment: String?
)

data class RoleRequestReviewRequest(
    val comment: String?
)

data class GroupChangeRequestDto(
    val id: Int,
    @SerializedName("userId") val userId: Int,
    @SerializedName("userName") val userName: String?,
    @SerializedName("userEmail") val userEmail: String?,
    @SerializedName("currentGroupId") val currentGroupId: Int?,
    @SerializedName("currentGroupName") val currentGroupName: String?,
    @SerializedName("requestedGroupId") val requestedGroupId: Int,
    @SerializedName("requestedGroupName") val requestedGroupName: String?,
    val comment: String?,
    val status: String,
    @SerializedName("reviewedByAdminEmail") val reviewedByAdminEmail: String?,
    @SerializedName("reviewComment") val reviewComment: String?,
    @SerializedName("createdAt") val createdAt: String,
    @SerializedName("reviewedAt") val reviewedAt: String?
)

data class GroupUserDto(
    val id: String,
    val email: String?,
    val name: String?,
    @SerializedName("group_id") val groupId: Int,
    val roles: List<UserRole>,
    val badges: List<BadgeDto> = emptyList(),
    val tier: String
)

data class AdminUserDto(
    val id: String,
    val email: String?,
    val name: String?,
    val roles: List<UserRole>,
    val badges: List<BadgeDto> = emptyList(),
    @SerializedName("remainingToday") val remainingToday: Int,
    val tier: String
)

data class AdminRoleRequestDto(
    val id: Int,
    @SerializedName("userId", alternate = ["user_id"]) val userId: String,
    @SerializedName("userEmail", alternate = ["user_email"]) val userEmail: String?,
    @SerializedName("roleType", alternate = ["role_type", "requestedRole"]) val roleType: String,
    val status: String,
    @SerializedName("createdAt", alternate = ["created_at"]) val createdAt: String,
    @SerializedName("reviewComment") val reviewComment: String? = null
)

data class RuntimeSettingPatchRequest(val value: Any)

data class BadgeMutationRequest(
    @SerializedName("badge_code") val badgeCode: String,
    val note: String?
)
