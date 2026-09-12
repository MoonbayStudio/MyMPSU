package ru.moonbaystudio.mympsu.data.remote

import com.google.gson.annotations.SerializedName
import retrofit2.Response
import retrofit2.http.*
import ru.moonbaystudio.mympsu.data.remote.dto.*

interface MyMPSUApiService {
    @GET("config/public")
    suspend fun getPublicConfig(): Response<PublicConfigResponse>

    @GET("system/notice")
    suspend fun getActiveSystemNotice(): Response<ActiveSystemNoticeResponse>

    @POST("auth/login")
    suspend fun login(@Body request: PasswordLoginRequest): Response<AppleSignInResponse>

    @POST("auth/signup")
    suspend fun signup(@Body request: SignupRequest): Response<SignupResponse>

    @POST("auth/signup/verify")
    suspend fun signupVerify(@Body request: SignupVerifyRequest): Response<AppleSignInResponse>

    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): Response<AppleSignInResponse>

    @GET("me")
    suspend fun getCurrentUser(): Response<AppleUser>

    @GET("profile")
    suspend fun getProfile(): Response<AppleUser>

    @PUT("profile")
    suspend fun updateProfile(@Body request: UpdateProfileRequest): Response<AppleUser>

    @GET("settings")
    suspend fun getSettings(): Response<UserSettings>

    @PUT("settings")
    suspend fun updateSettings(@Body settings: UserSettings): Response<UserSettings>

    @POST("me/password/create")
    suspend fun createPassword(@Body request: PasswordSetupRequest): Response<Unit>

    @POST("me/password/change")
    suspend fun changePassword(@Body request: PasswordChangeRequest): Response<Unit>

    @POST("auth/password/reset-request")
    suspend fun requestPasswordReset(@Body request: ResetPasswordRequest): Response<Unit>

    @POST("auth/password/reset-confirm")
    suspend fun confirmPasswordReset(@Body request: ResetPasswordConfirmRequest): Response<Unit>

    @POST("me/email/change-request")
    suspend fun requestEmailChange(@Body request: EmailChangeRequest): Response<Unit>

    @POST("me/email/confirm")
    suspend fun confirmEmailChange(@Body request: EmailConfirmRequest): Response<AppleUser>

    @POST("auth/contact-email/request")
    suspend fun requestContactEmail(@Body request: ContactEmailRequest): Response<Unit>

    @POST("auth/contact-email/resend-verification")
    suspend fun resendContactEmailVerification(): Response<Unit>

    @GET("account/sessions")
    suspend fun getSessions(): Response<List<AccountSession>>

    @DELETE("account/sessions/{sessionId}")
    suspend fun revokeSession(@Path("sessionId") sessionId: String): Response<Unit>

    @POST("account/sessions/logout-others")
    suspend fun logoutOthers(): Response<Unit>

    @POST("role-requests")
    suspend fun createRoleRequest(@Body request: RoleRequestCreateRequest): Response<RoleRequest>

    @GET("role-requests/me")
    suspend fun getMyRoleRequests(): Response<List<RoleRequest>>

    @POST("role-requests/{requestId}/cancel")
    suspend fun cancelRoleRequest(@Path("requestId") requestId: String): Response<RoleRequest>

    @POST("group-change-requests")
    suspend fun createGroupChangeRequest(@Body request: GroupChangeRequestCreateRequest): Response<GroupChangeRequestDto>

    @GET("group-change-requests/me")
    suspend fun getMyGroupChangeRequests(): Response<List<GroupChangeRequestDto>>

    @POST("group-change-requests/{requestId}/cancel")
    suspend fun cancelGroupChangeRequest(@Path("requestId") requestId: Int): Response<GroupChangeRequestDto>

    @GET("groups/{groupId}/homeworks")
    suspend fun getGroupHomeworks(
        @Path("groupId") groupId: Int,
        @Query("date") date: String?
    ): Response<List<Homework>>

    @POST("groups/{groupId}/homeworks")
    suspend fun createHomework(
        @Path("groupId") groupId: Int,
        @Body request: HomeworkMutationRequest
    ): Response<Homework>

    @PATCH("groups/{groupId}/homeworks/{homeworkId}")
    suspend fun updateHomework(
        @Path("groupId") groupId: Int,
        @Path("homeworkId") homeworkId: String,
        @Body request: HomeworkUpdateRequest
    ): Response<Homework>

    @DELETE("groups/{groupId}/homeworks/{homeworkId}")
    suspend fun deleteHomework(
        @Path("groupId") groupId: Int,
        @Path("homeworkId") homeworkId: String
    ): Response<Unit>

    @POST("assistant/chat")
    suspend fun assistantChat(@Body request: AssistantChatRequest): Response<AssistantChatResponse>

    @POST("auth/google")
    suspend fun googleLogin(@Body request: GoogleLoginRequest): Response<AppleSignInResponse>

    @POST("me/providers/google")
    suspend fun linkGoogle(@Body request: GoogleLoginRequest): Response<AppleUser>

    @GET("groups/{groupId}/users")
    suspend fun getGroupUsers(@Path("groupId") groupId: Int): Response<List<GroupUserDto>>

    @GET("admin/users")
    suspend fun getAdminUsers(): Response<List<AdminUserDto>>

    @GET("admin/role-requests")
    suspend fun getAdminRoleRequests(@Query("status") status: String): Response<List<AdminRoleRequestDto>>

    @POST("admin/role-requests/{requestId}/approve")
    suspend fun approveRoleRequest(@Path("requestId") requestId: Int): Response<Unit>

    @POST("admin/role-requests/{requestId}/reject")
    suspend fun rejectRoleRequest(
        @Path("requestId") requestId: Int,
        @Body request: RoleRequestReviewRequest
    ): Response<Unit>

    @GET("moderation/group-change-requests")
    suspend fun getGroupChangeRequests(@Query("status") status: String): Response<List<GroupChangeRequestDto>>

    @POST("moderation/group-change-requests/{requestId}/approve")
    suspend fun approveGroupChangeRequest(@Path("requestId") requestId: Int): Response<Unit>

    @POST("moderation/group-change-requests/{requestId}/reject")
    suspend fun rejectGroupChangeRequest(
        @Path("requestId") requestId: Int,
        @Body request: GroupChangeRequestReviewRequest
    ): Response<Unit>

    @POST("admin/roles/grant")
    suspend fun grantRole(@Body request: GrantRoleRequest): Response<Unit>

    @POST("admin/roles/revoke")
    suspend fun revokeRole(@Body request: GrantRoleRequest): Response<Unit>

    @GET("admin/badges")
    suspend fun getAdminBadges(): Response<List<BadgeDto>>

    @POST("admin/users/{userId}/badges")
    suspend fun grantBadge(
        @Path("userId") userId: String,
        @Body request: BadgeMutationRequest
    ): Response<AdminUserDto>

    @DELETE("admin/users/{userId}/badges/{badgeCode}")
    suspend fun revokeBadge(
        @Path("userId") userId: String,
        @Path("badgeCode") badgeCode: String
    ): Response<AdminUserDto>

    @GET("admin/settings")
    suspend fun getAdminSettings(): Response<List<AdminRuntimeSetting>>

    @PATCH("admin/settings/{key}")
    suspend fun updateAdminSetting(
        @Path("key") key: String,
        @Body request: RuntimeSettingPatchRequest
    ): Response<AdminRuntimeSetting>

    @GET("admin/system-notices")
    suspend fun getAdminSystemNotices(): Response<List<SystemNotice>>

    @POST("admin/system-notices")
    suspend fun createAdminSystemNotice(@Body request: SystemNoticeMutationRequest): Response<SystemNotice>

    @PATCH("admin/system-notices/{id}")
    suspend fun updateAdminSystemNotice(
        @Path("id") id: Int,
        @Body request: SystemNoticeMutationRequest
    ): Response<SystemNotice>

    @DELETE("admin/system-notices/{id}")
    suspend fun deleteAdminSystemNotice(@Path("id") id: Int): Response<Unit>

    @POST("admin/system-notices/{id}/activate")
    suspend fun activateSystemNotice(@Path("id") id: Int): Response<Unit>

    @POST("admin/system-notices/{id}/deactivate")
    suspend fun deactivateSystemNotice(@Path("id") id: Int): Response<Unit>

    @GET("admin/users/{userId}/sessions")
    suspend fun getAdminUserSessions(@Path("userId") userId: String): Response<List<AccountSession>>

    @POST("admin/sessions/{sessionId}/revoke")
    suspend fun revokeAdminSession(@Path("sessionId") sessionId: String): Response<Unit>
}
