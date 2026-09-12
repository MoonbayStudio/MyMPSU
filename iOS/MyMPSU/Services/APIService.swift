import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

final class APIService {
    static let shared = APIService()
    private init() {}

    // Requires the MPGU adapter described in docs/MYMPSU_SETUP.md.
    private let baseURL = "https://api.mympsu.moonbaystudio.ru/schedule/v1"
    private let myMPSUBaseURL = "https://api.mympsu.moonbaystudio.ru"
    private var groupNameToIDCache: [String: Int] = [:]
    private let institutesCacheFileName = "institutes_groups_cache.json"

    private static let requestDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let sessionDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = .current
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISO8601DateFormatter: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    private static var authDeviceID: String {
        let key = "mympsuAuthDeviceID"
        if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }

    private static var authDeviceMetadata: AuthDeviceMetadata {
        AuthDeviceMetadata(
            deviceId: authDeviceID,
            deviceName: currentDeviceName,
            platform: currentPlatform,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
    }

    private static var currentDeviceName: String? {
#if os(iOS)
        UIDevice.current.name
#elseif os(macOS)
        Host.current().localizedName
#else
        nil
#endif
    }

    private static var currentPlatform: String {
#if os(iOS)
        "iOS"
#elseif os(macOS)
        "macOS"
#else
        "unknown"
#endif
    }

    private(set) var lastScheduleConnectionError = false

    private func log(_ message: String) {
        print("[APIService] \(message)")
    }

    private func googleIDTokenDiagnostics(_ token: String) -> String {
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let header = decodeJWTPart(String(parts[0])),
              let payload = decodeJWTPart(String(parts[1])) else {
            return "jwt=<unreadable>"
        }

        let algorithm = header["alg"] as? String ?? "<missing>"
        let keyID = header["kid"] as? String ?? "<missing>"
        let issuer = payload["iss"] as? String ?? "<missing>"
        let audience = payload["aud"] as? String ?? "<missing>"
        return "jwtAlg=\(algorithm), jwtKid=\(keyID), jwtIssuer=\(issuer), jwtAudience=\(audience)"
    }

    private func decodeJWTPart(_ value: String) -> [String: Any]? {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private func isConnectionError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .timedOut,
             .secureConnectionFailed,
             .serverCertificateHasBadDate,
             .serverCertificateUntrusted,
             .serverCertificateNotYetValid,
             .clientCertificateRejected,
             .clientCertificateRequired:
            return true
        default:
            return false
        }
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        appleUserID: String,
        fullName: String?,
        email: String?
    ) async throws -> AppleSignInResponse {
        let deviceMetadata = Self.authDeviceMetadata
        let payload = AppleSignInRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            appleUserID: appleUserID,
            fullName: fullName,
            email: email,
            deviceId: deviceMetadata.deviceId,
            deviceName: deviceMetadata.deviceName,
            platform: deviceMetadata.platform,
            appVersion: deviceMetadata.appVersion
        )

        var request = try makeMyMPSURequest(path: "/auth/apple", method: "POST", authorized: false)
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        log("signInWithApple request: url=\(request.url?.absoluteString ?? "<nil>"), identityTokenLength=\(identityToken.count), authorizationCodeLength=\(authorizationCode?.count ?? 0), hasAppleUserID=\(!appleUserID.isEmpty), hasEmail=\(email != nil), hasFullName=\(fullName != nil)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            log("signInWithApple invalid response: \(response)")
            throw APIServiceError.invalidResponse
        }
        log("signInWithApple response HTTP \(httpResponse.statusCode), bytes=\(data.count)")
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("signInWithApple HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }

        do {
            let response = try MyMPSUBackendSystem.jsonDecoder.decode(AppleSignInResponse.self, from: data)
            return response
        } catch {
            log("signInWithApple decode error: \(error)")
            throw error
        }
    }

    func signInWithGoogle(
        idToken: String,
        accessToken: String,
        googleUserID: String?,
        fullName: String?,
        email: String?
    ) async throws -> AppleSignInResponse {
        let deviceMetadata = Self.authDeviceMetadata
        let payload = GoogleSignInRequest(
            idToken: idToken,
            accessToken: accessToken,
            googleUserID: googleUserID,
            fullName: fullName,
            email: email,
            deviceId: deviceMetadata.deviceId,
            deviceName: deviceMetadata.deviceName,
            platform: deviceMetadata.platform,
            appVersion: deviceMetadata.appVersion
        )

        var request = try makeMyMPSURequest(path: "/auth/google", method: "POST", authorized: false)
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        log("signInWithGoogle request: url=\(request.url?.absoluteString ?? "<nil>"), idTokenLength=\(idToken.count), accessTokenLength=\(accessToken.count), hasGoogleUserID=\(googleUserID?.isEmpty == false), hasEmail=\(email != nil), hasFullName=\(fullName != nil), \(googleIDTokenDiagnostics(idToken))")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            log("signInWithGoogle invalid response: \(response)")
            throw APIServiceError.invalidResponse
        }
        log("signInWithGoogle response HTTP \(httpResponse.statusCode), bytes=\(data.count)")
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("signInWithGoogle HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }

        return try MyMPSUBackendSystem.jsonDecoder.decode(AppleSignInResponse.self, from: data)
    }

    func linkGoogleProvider(
        idToken: String,
        accessToken: String,
        googleUserID: String?,
        fullName: String?,
        email: String?
    ) async throws -> AppleUser {
        let deviceMetadata = Self.authDeviceMetadata
        let payload = GoogleSignInRequest(
            idToken: idToken,
            accessToken: accessToken,
            googleUserID: googleUserID,
            fullName: fullName,
            email: email,
            deviceId: deviceMetadata.deviceId,
            deviceName: deviceMetadata.deviceName,
            platform: deviceMetadata.platform,
            appVersion: deviceMetadata.appVersion
        )

        var request = try makeMyMPSURequest(path: "/me/providers/google", method: "POST", authorized: true)
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        log("linkGoogleProvider request: url=\(request.url?.absoluteString ?? "<nil>"), idTokenLength=\(idToken.count), accessTokenLength=\(accessToken.count), hasGoogleUserID=\(googleUserID?.isEmpty == false), hasEmail=\(email != nil), hasFullName=\(fullName != nil), \(googleIDTokenDiagnostics(idToken))")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            log("linkGoogleProvider invalid response: \(response)")
            throw APIServiceError.invalidResponse
        }
        log("linkGoogleProvider response HTTP \(httpResponse.statusCode), bytes=\(data.count)")
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("linkGoogleProvider HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }

        return try decodeProfileUser(from: data, context: "linkGoogleProvider")
    }

    func makeAuthorizedMyMPSURequest(path: String, method: String = "GET") throws -> URLRequest {
        try makeMyMPSURequest(path: path, method: method, authorized: true)
    }

    func createPassword(password: String) async throws -> AppleUser {
        let payload = PasswordSetupRequest(password: password)
        try await sendPasswordRequest(path: "/me/password/create", payload: payload, authorized: true)
        return try await fetchCurrentUser()
    }

    func loginWithPassword(email: String, password: String) async throws -> AppleSignInResponse {
        let deviceMetadata = Self.authDeviceMetadata
        let payload = PasswordLoginRequest(
            email: email,
            password: password,
            deviceId: deviceMetadata.deviceId,
            deviceName: deviceMetadata.deviceName,
            platform: deviceMetadata.platform,
            appVersion: deviceMetadata.appVersion
        )
        var request = try makeMyMPSURequest(path: "/auth/login", method: "POST", authorized: false)
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            log("loginWithPassword HTTP \(httpResponse.statusCode)")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(AppleSignInResponse.self, from: data)
    }

    func signUpWithPassword(email: String, password: String, displayName: String) async throws -> String {
        let deviceMetadata = Self.authDeviceMetadata
        let payload = PasswordSignupRequest(
            email: email,
            password: password,
            displayName: displayName,
            deviceId: deviceMetadata.deviceId,
            deviceName: deviceMetadata.deviceName,
            platform: deviceMetadata.platform,
            appVersion: deviceMetadata.appVersion
        )
        var request = try makeMyMPSURequest(path: "/auth/signup", method: "POST", authorized: false)
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            log("signUpWithPassword HTTP \(httpResponse.statusCode)")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        let signupResponse = try MyMPSUBackendSystem.jsonDecoder.decode(PasswordSignupResponse.self, from: data)
        return signupResponse.email
    }

    func verifyPasswordSignup(email: String, code: String) async throws -> AppleSignInResponse {
        let deviceMetadata = Self.authDeviceMetadata
        let payload = PasswordSignupVerificationRequest(
            email: email,
            code: code,
            deviceId: deviceMetadata.deviceId,
            deviceName: deviceMetadata.deviceName,
            platform: deviceMetadata.platform,
            appVersion: deviceMetadata.appVersion
        )
        var request = try makeMyMPSURequest(path: "/auth/signup/verify", method: "POST", authorized: false)
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            log("verifyPasswordSignup HTTP \(httpResponse.statusCode)")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(AppleSignInResponse.self, from: data)
    }

    func changePassword(currentPassword: String, newPassword: String) async throws -> AppleUser {
        let payload = PasswordChangeRequest(currentPassword: currentPassword, newPassword: newPassword)
        try await sendPasswordRequest(path: "/me/password/change", payload: payload, authorized: true)
        return try await fetchCurrentUser()
    }

    func requestPasswordReset(email: String) async throws {
        let payload = PasswordResetRequest(email: email)
        try await sendPasswordRequest(path: "/auth/password/reset-request", payload: payload, authorized: false)
    }

    func confirmPasswordReset(code: String, newPassword: String) async throws {
        let payload = PasswordResetConfirmationRequest(code: code, newPassword: newPassword)
        try await sendPasswordRequest(path: "/auth/password/reset-confirm", payload: payload, authorized: false)
    }

    func requestEmailChange(newEmail: String) async throws -> AppleUser {
        let payload = AccountEmailChangeRequest(email: newEmail)
        try await sendPasswordRequest(path: "/me/email/change-request", payload: payload, authorized: true)
        return try await fetchCurrentUser()
    }

    func confirmEmailChange(code: String) async throws -> AppleUser {
        let payload = AccountEmailConfirmationRequest(code: code)
        try await sendPasswordRequest(path: "/me/email/confirm", payload: payload, authorized: true)
        return try await fetchCurrentUser()
    }

    func requestContactEmailVerification(email: String) async throws {
        let payload = ContactEmailRequest(email: email)
        try await sendPasswordRequest(path: "/auth/contact-email/request", payload: payload, authorized: true)
    }

    func resendContactEmailVerification() async throws {
        let request = try makeAuthorizedMyMPSURequest(path: "/auth/contact-email/resend-verification", method: "POST")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            log("resendContactEmailVerification HTTP \(httpResponse.statusCode)")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
    }

    func refreshCurrentUser() async throws -> AppleUser {
        try await fetchCurrentUser()
    }

    private func sendPasswordRequest<T: Encodable>(path: String, payload: T, authorized: Bool) async throws {
        var request = try makeMyMPSURequest(path: path, method: "POST", authorized: authorized)
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            log("\(path) HTTP \(httpResponse.statusCode)")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
    }

    func fetchCurrentUser() async throws -> AppleUser {
        let request = try makeAuthorizedMyMPSURequest(path: "/profile")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchCurrentUser HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try decodeProfileUser(from: data, context: "fetchCurrentUser")
    }

    func updateProfile(name: String) async throws -> AppleUser {
        let payload = ProfileUpdateRequest(name: name)
        var request = try makeAuthorizedMyMPSURequest(path: "/me", method: "PATCH")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("updateProfile HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }

        return try decodeProfileUser(from: data, context: "updateProfile")
    }

    private func decodeProfileUser(from data: Data, context: String) throws -> AppleUser {
        do {
            return try MyMPSUBackendSystem.jsonDecoder.decode(AppleUser.self, from: data)
        } catch {
            do {
                return try MyMPSUBackendSystem.jsonDecoder.decode(ProfileUserResponse.self, from: data).resolvedUser
            } catch {
                log("\(context) profile decode error: \(error)")
                throw error
            }
        }
    }

    func fetchSettings() async throws -> UserSettings {
        let request = try makeAuthorizedMyMPSURequest(path: "/settings")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchSettings HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(UserSettings.self, from: data)
    }

    func updateSettings(selectedGroupId: Int, selectedGroupName: String) async throws -> UserSettings {
        try await updateSettings(
            selectedGroupId: selectedGroupId,
            selectedGroupName: selectedGroupName,
            scheduleCacheWeeks: UserDefaults.standard.bool(forKey: "offlineScheduleEnabled")
                ? UserDefaults.standard.integer(forKey: "offlineScheduleWeeks")
                : 0,
            liveActivityEnabled: Self.defaultLiveActivityEnabledSetting()
        )
    }

    func updateSettings(
        selectedGroupId: Int,
        selectedGroupName: String,
        scheduleCacheWeeks: Int,
        liveActivityEnabled: Bool
    ) async throws -> UserSettings {
        let payload = UserSettings(
            selectedGroupId: selectedGroupId,
            selectedGroupName: selectedGroupName,
            scheduleCacheWeeks: scheduleCacheWeeks,
            liveActivityEnabled: liveActivityEnabled
        )
        var request = try makeAuthorizedMyMPSURequest(path: "/settings", method: "PUT")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("updateSettings HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(UserSettings.self, from: data)
    }

    private static func defaultLiveActivityEnabledSetting() -> Bool {
        guard UserDefaults.standard.object(forKey: "liveActivityEnabled") != nil else { return true }
        return UserDefaults.standard.bool(forKey: "liveActivityEnabled")
    }

    func createRoleRequest(roleType: String, groupId: Int?, groupName: String?, comment: String?) async throws -> RoleRequest {
        let payload = RoleRequestCreateRequest(
            roleType: roleType,
            groupId: groupId,
            groupName: groupName,
            comment: comment
        )
        var request = try makeAuthorizedMyMPSURequest(path: "/role-requests", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("createRoleRequest HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(RoleRequest.self, from: data)
    }

    func fetchLegacyMyRoleRequests() async throws -> [RoleRequest] {
        let request = try makeAuthorizedMyMPSURequest(path: "/role-requests/me")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchLegacyMyRoleRequests HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode([RoleRequest].self, from: data)
    }

    func createRoleRequest(role: String, message: String) async throws -> RoleRequestDTO {
        let payload = RoleRequestCreateDTO(role: role, message: message)
        var request = try makeAuthorizedMyMPSURequest(path: "/me/role-requests", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("createRoleRequest /me HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(RoleRequestDTO.self, from: data)
    }

    func fetchMyRoleRequests() async throws -> [RoleRequestDTO] {
        let request = try makeAuthorizedMyMPSURequest(path: "/me/role-requests")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchMyRoleRequests /me HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode([RoleRequestDTO].self, from: data)
    }

    func cancelRoleRequest(id: String) async throws {
        let escapedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let request = try makeAuthorizedMyMPSURequest(path: "/me/role-requests/\(escapedId)/cancel", method: "POST")
        try await sendRoleRequestAction(request, operation: "cancelRoleRequest")
    }

    func fetchAdminRoleRequests(status: String = "pending") async throws -> [RoleRequestDTO] {
        let escapedStatus = status.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? status
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/role-requests?status=\(escapedStatus)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchAdminRoleRequests HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode([RoleRequestDTO].self, from: data)
    }

    func approveAdminRoleRequest(id: String) async throws {
        let escapedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/role-requests/\(escapedId)/approve", method: "POST")
        try await sendRoleRequestAction(request, operation: "approveAdminRoleRequest")
    }

    func rejectAdminRoleRequest(id: String) async throws {
        let escapedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/role-requests/\(escapedId)/reject", method: "POST")
        try await sendRoleRequestAction(request, operation: "rejectAdminRoleRequest")
    }

    private func sendRoleRequestAction(_ request: URLRequest, operation: String) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("\(operation) HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
    }

    func fetchModerationRoleRequests() async throws -> [RoleRequest] {
        let request = try makeAuthorizedMyMPSURequest(path: "/moderation/role-requests")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchModerationRoleRequests HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try decodeModerationRoleRequests(from: data)
    }

    func approveRoleRequest(id: String) async throws {
        let escapedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let request = try makeAuthorizedMyMPSURequest(path: "/moderation/role-requests/\(escapedId)/approve", method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("approveRoleRequest HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
    }

    func rejectRoleRequest(id: String, comment: String?) async throws {
        let payload = RoleRequestRejectRequest(comment: comment)
        let escapedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        var request = try makeAuthorizedMyMPSURequest(path: "/moderation/role-requests/\(escapedId)/reject", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("rejectRoleRequest HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
    }

    func createGroupChangeRequest(
        requestedGroupId: Int,
        requestedGroupName: String?,
        comment: String? = nil
    ) async throws -> GroupChangeRequestDTO {
        let payload = GroupChangeRequestCreateRequest(
            requestedGroupId: requestedGroupId,
            requestedGroupName: requestedGroupName,
            comment: comment
        )
        var request = try makeAuthorizedMyMPSURequest(path: "/group-change-requests", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "createGroupChangeRequest")
        return try MyMPSUBackendSystem.jsonDecoder.decode(GroupChangeRequestDTO.self, from: data)
    }

    func fetchMyGroupChangeRequests() async throws -> [GroupChangeRequestDTO] {
        let request = try makeAuthorizedMyMPSURequest(path: "/group-change-requests/me")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "fetchMyGroupChangeRequests")
        return try MyMPSUBackendSystem.jsonDecoder.decode([GroupChangeRequestDTO].self, from: data)
    }

    func fetchModerationGroupChangeRequests(status: String = "pending") async throws -> [GroupChangeRequestDTO] {
        let escapedStatus = status.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? status
        let request = try makeAuthorizedMyMPSURequest(path: "/moderation/group-change-requests?status=\(escapedStatus)")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "fetchModerationGroupChangeRequests")
        return try MyMPSUBackendSystem.jsonDecoder.decode([GroupChangeRequestDTO].self, from: data)
    }

    func approveGroupChangeRequest(id: String) async throws {
        let escapedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let request = try makeAuthorizedMyMPSURequest(path: "/moderation/group-change-requests/\(escapedId)/approve", method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "approveGroupChangeRequest")
    }

    func rejectGroupChangeRequest(id: String, comment: String?) async throws {
        let payload = GroupChangeRequestReviewRequest(comment: comment)
        let escapedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        var request = try makeAuthorizedMyMPSURequest(path: "/moderation/group-change-requests/\(escapedId)/reject", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "rejectGroupChangeRequest")
    }

    private func decodeModerationRoleRequests(from data: Data) throws -> [RoleRequest] {
        let body = String(data: data, encoding: .utf8)?.mympsuTrimmed ?? ""
        guard !body.isEmpty, body != "null" else {
            log("decodeModerationRoleRequests: empty response, treating as no requests")
            return []
        }

        do {
            return try MyMPSUBackendSystem.jsonDecoder.decode([RoleRequest].self, from: data)
        } catch {
            if let wrapped = try? MyMPSUBackendSystem.jsonDecoder.decode(RoleRequestsResponse.self, from: data) {
                return wrapped.requests
            }
            log("decodeModerationRoleRequests failed: \(Self.describeDecodingError(error)), body: \(Self.utf8Preview(from: data))")
            throw error
        }
    }

    func fetchAdminUsers() async throws -> [AdminUserDTO] {
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/users")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchAdminUsers HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode([AdminUserDTO].self, from: data)
    }

    func fetchAdminBadges() async throws -> [UserBadge] {
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/badges")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "fetchAdminBadges")
        return try MyMPSUBackendSystem.jsonDecoder.decode([UserBadge].self, from: data)
    }

    func fetchGroupUsers(groupId: Int) async throws -> [GroupUser] {
        let escapedGroupId = String(groupId).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(groupId)
        let request = try makeAuthorizedMyMPSURequest(path: "/groups/\(escapedGroupId)/users")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchGroupUsers HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatusWithBody(httpResponse.statusCode, body)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode([GroupUser].self, from: data)
    }

    func joinGroup(groupId: Int) async throws {
        let escapedGroupId = String(groupId).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(groupId)
        let request = try makeAuthorizedMyMPSURequest(path: "/groups/\(escapedGroupId)/join", method: "POST")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
    }

    func assignUserToGroup(userId: String, groupId: Int) async throws -> AdminUserDTO {
        let escapedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        let payload = AssignUserGroupRequest(groupId: groupId)
        var request = try makeAuthorizedMyMPSURequest(path: "/admin/users/\(escapedUserId)/group", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("assignUserToGroup HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatusWithBody(httpResponse.statusCode, body)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(AdminUserDTO.self, from: data)
    }

    func fetchGroupHomeworks(groupId: Int, date: String? = nil) async throws -> [Homework] {
        let escapedGroupId = String(groupId).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(groupId)
        var path = "/groups/\(escapedGroupId)/homeworks"
        if let date, !date.isEmpty {
            let escapedDate = date.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? date
            path += "?date=\(escapedDate)"
        }
        let request = try makeAuthorizedMyMPSURequest(path: path)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchGroupHomeworks HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatusWithBody(httpResponse.statusCode, body)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode([Homework].self, from: data)
    }

    func fetchLessonHomework(groupId: Int, date: String, time: String, subject: String) async throws -> Homework? {
        let escapedGroupId = String(groupId).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(groupId)
        var components = URLComponents()
        components.path = "/groups/\(escapedGroupId)/homeworks/lesson"
        components.queryItems = [
            URLQueryItem(name: "date", value: date),
            URLQueryItem(name: "time", value: time),
            URLQueryItem(name: "subject", value: subject)
        ]
        let path = components.string ?? "/groups/\(escapedGroupId)/homeworks/lesson"
        let request = try makeAuthorizedMyMPSURequest(path: path)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        if httpResponse.statusCode == 404 {
            return nil
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("fetchLessonHomework HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatusWithBody(httpResponse.statusCode, body)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(Homework.self, from: data)
    }

    func createHomework(
        groupId: Int,
        lessonDate: String,
        lessonTime: String,
        subject: String,
        teacher: String?,
        room: String?,
        text: String
    ) async throws -> Homework {
        let escapedGroupId = String(groupId).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(groupId)
        let payload = HomeworkMutationRequest(
            lessonDate: lessonDate,
            lessonTime: lessonTime,
            subject: subject,
            teacher: teacher,
            room: room,
            text: text
        )
        var request = try makeAuthorizedMyMPSURequest(path: "/groups/\(escapedGroupId)/homeworks", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        return try await sendHomeworkMutation(request, operation: "createHomework")
    }

    func updateHomework(groupId: Int, homeworkId: String, text: String) async throws -> Homework {
        let escapedGroupId = String(groupId).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(groupId)
        let escapedHomeworkId = homeworkId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? homeworkId
        var request = try makeAuthorizedMyMPSURequest(path: "/groups/\(escapedGroupId)/homeworks/\(escapedHomeworkId)", method: "PATCH")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(HomeworkUpdateRequest(text: text))
        return try await sendHomeworkMutation(request, operation: "updateHomework")
    }

    func deleteHomework(groupId: Int, homeworkId: String) async throws {
        let escapedGroupId = String(groupId).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(groupId)
        let escapedHomeworkId = homeworkId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? homeworkId
        let request = try makeAuthorizedMyMPSURequest(path: "/groups/\(escapedGroupId)/homeworks/\(escapedHomeworkId)", method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("deleteHomework HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatusWithBody(httpResponse.statusCode, body)
        }
    }

    private func sendHomeworkMutation(_ request: URLRequest, operation: String) async throws -> Homework {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("\(operation) HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatusWithBody(httpResponse.statusCode, body)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(Homework.self, from: data)
    }

    func grantRole(userId: String, role: String) async throws -> AdminUserDTO {
        let payload = RoleMutationRequest(userId: userId, role: normalizedRoleKey(role))
        var request = try makeAuthorizedMyMPSURequest(path: "/admin/roles/grant", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        return try await sendAdminRoleMutation(request, operation: "grantRole")
    }

    func revokeRole(userId: String, role: String) async throws -> AdminUserDTO {
        let payload = RoleMutationRequest(userId: userId, role: normalizedRoleKey(role))
        var request = try makeAuthorizedMyMPSURequest(path: "/admin/roles/revoke", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        return try await sendAdminRoleMutation(request, operation: "revokeRole")
    }

    func grantBadge(userId: String, badgeCode: String, note: String?) async throws -> AdminUserDTO {
        let escapedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        let payload = BadgeMutationRequest(badgeCode: badgeCode, note: note)
        var request = try makeAuthorizedMyMPSURequest(path: "/admin/users/\(escapedUserId)/badges", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        return try await sendAdminUserMutation(request, operation: "grantBadge")
    }

    func revokeBadge(userId: String, badgeCode: String) async throws -> AdminUserDTO {
        let escapedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        let escapedBadgeCode = badgeCode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? badgeCode
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/users/\(escapedUserId)/badges/\(escapedBadgeCode)", method: "DELETE")
        return try await sendAdminUserMutation(request, operation: "revokeBadge")
    }

    private func normalizedRoleKey(_ role: String) -> String {
        role.mympsuTrimmed.lowercased()
    }

    private func sendAdminRoleMutation(_ request: URLRequest, operation: String) async throws -> AdminUserDTO {
        try await sendAdminUserMutation(request, operation: operation)
    }

    private func sendAdminUserMutation(_ request: URLRequest, operation: String) async throws -> AdminUserDTO {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("\(operation) HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatusWithBody(httpResponse.statusCode, body)
        }
        return try MyMPSUBackendSystem.jsonDecoder.decode(AdminUserDTO.self, from: data)
    }

    func fetchPublicConfig() async throws -> PublicConfig {
        let request = try makeMyMPSURequest(path: "/config/public", method: "GET", authorized: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "fetchPublicConfig")
        return try MyMPSUBackendSystem.jsonDecoder.decode(PublicConfig.self, from: data)
    }

    func fetchSystemNotice() async throws -> SystemNoticeResponse {
        let request = try makeMyMPSURequest(path: "/system/notice", method: "GET", authorized: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "fetchSystemNotice")
        return try MyMPSUBackendSystem.jsonDecoder.decode(SystemNoticeResponse.self, from: data)
    }

    func fetchAccountSessions() async throws -> [AccountSession] {
        let request = try makeAuthorizedMyMPSURequest(path: "/account/sessions")
        log("fetchAccountSessions: GET \(request.url?.absoluteString ?? "<missing url>")")
        let (data, response) = try await URLSession.shared.data(for: request)
        logSessionResponse(response: response, data: data, operation: "fetchAccountSessions")
        try validate(response: response, data: data, operation: "fetchAccountSessions")
        return try decodeSessionList(from: data)
    }

    func revokeAccountSession(id: String) async throws {
        let escapedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let request = try makeAuthorizedMyMPSURequest(path: "/account/sessions/\(escapedId)", method: "DELETE")
        log("revokeAccountSession: DELETE \(request.url?.absoluteString ?? "<missing url>")")
        let (data, response) = try await URLSession.shared.data(for: request)
        logSessionResponse(response: response, data: data, operation: "revokeAccountSession")
        try validate(response: response, data: data, operation: "revokeAccountSession")
    }

    func logoutOtherAccountSessions() async throws {
        let request = try makeAuthorizedMyMPSURequest(path: "/account/sessions/logout-others", method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "logoutOtherAccountSessions")
    }

    func fetchAdminSettings() async throws -> [AdminRuntimeSetting] {
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/settings")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "fetchAdminSettings")
        return try MyMPSUBackendSystem.jsonDecoder.decode(AdminRuntimeSettingsResponse.self, from: data).settings
    }

    func updateAdminSetting(key: String, value: RuntimeSettingValue) async throws -> AdminRuntimeSetting {
        let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        var request = try makeAuthorizedMyMPSURequest(path: "/admin/settings/\(escapedKey)", method: "PATCH")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(RuntimeSettingPatchRequest(value: value))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "updateAdminSetting")
        if data.isEmpty {
            return AdminRuntimeSetting(key: key, value: value)
        }
        if let setting = try? MyMPSUBackendSystem.jsonDecoder.decode(AdminRuntimeSetting.self, from: data) {
            return setting
        }
        return AdminRuntimeSetting(key: key, value: value)
    }

    func fetchAdminSystemNotices() async throws -> [SystemNotice] {
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/system-notices")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "fetchAdminSystemNotices")
        return try decodeNoticeList(from: data)
    }

    func createAdminSystemNotice(_ payload: SystemNoticeMutationRequest) async throws -> SystemNotice {
        var request = try makeAuthorizedMyMPSURequest(path: "/admin/system-notices", method: "POST")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        return try await sendNoticeMutation(request, operation: "createAdminSystemNotice")
    }

    func updateAdminSystemNotice(id: Int, payload: SystemNoticeMutationRequest) async throws -> SystemNotice {
        let escapedId = String(id).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(id)
        var request = try makeAuthorizedMyMPSURequest(path: "/admin/system-notices/\(escapedId)", method: "PATCH")
        request.httpBody = try MyMPSUBackendSystem.jsonEncoder.encode(payload)
        return try await sendNoticeMutation(request, operation: "updateAdminSystemNotice")
    }

    func deleteAdminSystemNotice(id: Int) async throws {
        let escapedId = String(id).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(id)
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/system-notices/\(escapedId)", method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "deleteAdminSystemNotice")
    }

    func activateAdminSystemNotice(id: Int) async throws {
        try await sendAdminNoticeAction(id: id, action: "activate")
    }

    func deactivateAdminSystemNotice(id: Int) async throws {
        try await sendAdminNoticeAction(id: id, action: "deactivate")
    }

    func fetchAdminUserSessions(userId: String) async throws -> [AccountSession] {
        let escapedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/users/\(escapedUserId)/sessions")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "fetchAdminUserSessions")
        return try decodeSessionList(from: data)
    }

    func revokeAdminSession(id: String) async throws {
        let escapedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/sessions/\(escapedId)/revoke", method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "revokeAdminSession")
    }

    private func sendAdminNoticeAction(id: Int, action: String) async throws {
        let escapedId = String(id).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(id)
        let request = try makeAuthorizedMyMPSURequest(path: "/admin/system-notices/\(escapedId)/\(action)", method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: "\(action)AdminSystemNotice")
    }

    private func sendNoticeMutation(_ request: URLRequest, operation: String) async throws -> SystemNotice {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, operation: operation)
        return try MyMPSUBackendSystem.jsonDecoder.decode(SystemNotice.self, from: data)
    }

    private func decodeSessionList(from data: Data) throws -> [AccountSession] {
        do {
            let array = try MyMPSUBackendSystem.jsonDecoder.decode([AccountSession].self, from: data)
            log("decodeSessionList: decoded top-level array, count=\(array.count)")
            return array
        } catch {
            log("decodeSessionList: top-level array decode failed: \(Self.describeDecodingError(error))")
        }

        do {
            let response = try MyMPSUBackendSystem.jsonDecoder.decode(AccountSessionsResponse.self, from: data)
            let sessions = try response.resolvedSessions()
            log("decodeSessionList: decoded wrapped response, count=\(sessions.count)")
            return sessions
        } catch {
            log("decodeSessionList: wrapped response decode failed: \(Self.describeDecodingError(error))")
        }

        log("decodeSessionList: unsupported response body: \(Self.utf8Preview(from: data))")
        throw APIServiceError.invalidResponse
    }

    private func logSessionResponse(response: URLResponse, data: Data, operation: String) {
        let status = (response as? HTTPURLResponse)?.statusCode
        log("\(operation): HTTP \(status.map(String.init) ?? "<non-http>"), bytes=\(data.count), body=\(Self.utf8Preview(from: data))")
    }

    private static func utf8Preview(from data: Data, limit: Int = 2_000) -> String {
        guard !data.isEmpty else { return "<empty>" }
        let text = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        if text.count <= limit {
            return text
        }
        return "\(text.prefix(limit))… <truncated \(text.count - limit) chars>"
    }

    private static func describeDecodingError(_ error: Error) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                return "keyNotFound(\(key.stringValue)) path=\(codingPathDescription(context.codingPath)) \(context.debugDescription)"
            case .typeMismatch(let type, let context):
                return "typeMismatch(\(type)) path=\(codingPathDescription(context.codingPath)) \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                return "valueNotFound(\(type)) path=\(codingPathDescription(context.codingPath)) \(context.debugDescription)"
            case .dataCorrupted(let context):
                return "dataCorrupted path=\(codingPathDescription(context.codingPath)) \(context.debugDescription)"
            @unknown default:
                return "\(decodingError)"
            }
        }
        return String(describing: error)
    }

    private static func codingPathDescription(_ codingPath: [CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "<root>" }
        return codingPath.map(\.stringValue).joined(separator: ".")
    }

    private func decodeNoticeList(from data: Data) throws -> [SystemNotice] {
        if let array = try? MyMPSUBackendSystem.jsonDecoder.decode([SystemNotice].self, from: data) {
            return array
        }
        if let response = try? MyMPSUBackendSystem.jsonDecoder.decode(AdminSystemNoticesResponse.self, from: data) {
            return response.notices
        }
        throw APIServiceError.invalidResponse
    }

    private func validate(response: URLResponse, data: Data, operation: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            log("\(operation) HTTP \(httpResponse.statusCode), body: \(body ?? "<non-utf8 body>")")
            throw APIServiceError.httpStatusWithBody(httpResponse.statusCode, body)
        }
    }

    private func makeMyMPSURequest(path: String, method: String, authorized: Bool) throws -> URLRequest {
        guard let url = URL(string: "\(myMPSUBaseURL)\(path)") else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authorized, let token = KeychainHelper.read(AuthSessionManager.sessionTokenKey), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    func fetchSchedule(for groupId: String, date: Date, examOnly: Bool = false) async -> [ScheduleItem] {
        lastScheduleConnectionError = false
        guard !groupId.isEmpty,
              let groupIDInt = await resolveGroupID(from: groupId) else {
            log("fetchSchedule: could not resolve group id from '\(groupId)'")
            return []
        }

        let calendar = Calendar(identifier: .gregorian)
        let startDate = examOnly ? (calendar.date(byAdding: .day, value: -120, to: date) ?? date) : date
        let endDate = examOnly ? (calendar.date(byAdding: .day, value: 120, to: date) ?? date) : date
        return await fetchScheduleInternal(
            groupIDInt: groupIDInt,
            startDate: startDate,
            endDate: endDate,
            examOnly: examOnly
        )
    }

    func fetchScheduleRange(for groupId: String, startDate: Date, endDate: Date, examOnly: Bool = false) async -> [ScheduleItem] {
        lastScheduleConnectionError = false
        guard !groupId.isEmpty,
              let groupIDInt = await resolveGroupID(from: groupId) else {
            log("fetchScheduleRange: could not resolve group id from '\(groupId)'")
            return []
        }
        return await fetchScheduleInternal(
            groupIDInt: groupIDInt,
            startDate: startDate,
            endDate: endDate,
            examOnly: examOnly
        )
    }

    private func resolveGroupID(from rawValue: String) async -> Int? {
        if let direct = Int(rawValue) {
            return direct
        }

        let normalized = normalizeGroupName(rawValue)
        if let cached = groupNameToIDCache[normalized] {
            return cached
        }

        let groups = await fetchGroups()
        guard !groups.isEmpty else { return nil }

        // Build cache for quick lookups on next requests.
        var resolved: Int?
        for group in groups {
            let key = normalizeGroupName(group.name)
            groupNameToIDCache[key] = group.id
            if key == normalized {
                resolved = group.id
            }
        }
        return resolved
    }

    private func normalizeGroupName(_ value: String) -> String {
        value.mympsuNormalizedGroupKey
    }

    private func fetchScheduleInternal(groupIDInt: Int, startDate: Date, endDate: Date, examOnly: Bool) async -> [ScheduleItem] {
        let startDateString = Self.requestDateFormatter.string(from: startDate)
        let endDateString = Self.requestDateFormatter.string(from: endDate)
        var components = URLComponents(string: "\(baseURL)/schedule")
        components?.queryItems = [
            URLQueryItem(name: "group_id", value: String(groupIDInt)),
            URLQueryItem(name: "start_date", value: startDateString),
            URLQueryItem(name: "end_date", value: endDateString),
            URLQueryItem(name: "exam_only", value: examOnly ? "true" : "false"),
        ]

        guard let url = components?.url else {
            log("fetchSchedule: invalid URL")
            return []
        }
        log("fetchSchedule URL: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse {
                    let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                    log("fetchSchedule HTTP \(httpResponse.statusCode), body: \(body)")
                } else {
                    log("fetchSchedule invalid response type")
                }
                return []
            }

            let lessons: [ScheduleResponseDTO]
            do {
                lessons = try MyMPSUBackendSystem.jsonDecoder.decode([ScheduleResponseDTO].self, from: data)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                log("fetchSchedule decode error: \(error)")
                log("fetchSchedule response body: \(body)")
                return []
            }
            let teacherIDs = Array(Set(lessons.compactMap(\.teacherID))).sorted()
            let roomIDs = Array(Set(lessons.compactMap(\.roomID))).sorted()

            async let teachersTask = fetchTeachers(teacherIDs: teacherIDs)
            async let roomsTask = fetchRooms(roomIDs: roomIDs)
            let teachers = await teachersTask
            let rooms = await roomsTask

            let buildingIDs = Array(Set(rooms.compactMap(\.buildingID))).sorted()
            let buildings = await fetchBuildings(buildingIDs: buildingIDs)

            let teacherNamesByID = Dictionary(uniqueKeysWithValues: teachers.map { ($0.id, $0.name) })
            let roomByID = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })
            let buildingNameByID = Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0.name) })

            return lessons.map { lesson in
                let startText = formatTime(from: lesson.startTime)
                let endText = formatTime(from: lesson.endTime)
                let timeText = "\(startText)-\(endText)"
                let sessionDayText = examOnly ? formatDay(from: lesson.startTime) : ""
                let teacherName = lesson.teacherID.flatMap { teacherNamesByID[$0] } ?? ""
                let roomName = lesson.roomID.flatMap { roomByID[$0]?.name } ?? ""
                let addressName = lesson.roomID
                    .flatMap { roomByID[$0]?.buildingID }
                    .flatMap { buildingNameByID[$0] } ?? ""

                return ScheduleItem(
                    sortDateISO: lesson.startTime,
                    endDateISO: lesson.endTime,
                    time: timeText,
                    title: lesson.name,
                    teacher: teacherName,
                    lessonType: lesson.type,
                    address: addressName,
                    subgroup: lesson.subGroupID.map(String.init),
                    period: sessionDayText,
                    room: roomName,
                    classURL: lesson.classURL
                )
            }
        } catch {
            lastScheduleConnectionError = isConnectionError(error)
            log("fetchSchedule network error: \(error)")
            return []
        }
    }

    func fetchInstitutesWithGroups() async -> [Institute] {
        async let facultiesTask = fetchFaculties()
        async let groupsTask = fetchGroups()

        let faculties = await facultiesTask
        let groups = await groupsTask

        guard !groups.isEmpty else {
            let cached = readInstitutesCacheFromDisk()
            if !cached.isEmpty {
                log("fetchInstitutesWithGroups: using cached institutes/groups (\(cached.count) institutes)")
                return cached
            }
            return []
        }

        let facultyByID: [Int: String] = Dictionary(
            uniqueKeysWithValues: faculties.map { ($0.id, $0.name) }
        )

        let grouped = Dictionary(grouping: groups, by: { $0.facultyID })

        let institutes: [Institute] = grouped.map { facultyID, facultyGroups in
            let instituteName = facultyByID[facultyID] ?? "Институт \(facultyID)"
            let mappedGroups = facultyGroups
                .map { MyGroup(id: String($0.id), name: $0.name) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            return Institute(
                id: String(facultyID),
                name: instituteName,
                groups: mappedGroups
            )
        }
        .sorted { (lhs: Institute, rhs: Institute) in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        writeInstitutesCacheToDisk(institutes)
        return institutes
    }

    func fetchCachedInstitutesWithGroups() -> [Institute] {
        readInstitutesCacheFromDisk()
    }

    func refreshInstitutesWithGroupsCache() async {
        _ = await fetchInstitutesWithGroups()
    }

    private func institutesCacheURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return dir.appendingPathComponent(institutesCacheFileName)
    }

    private func writeInstitutesCacheToDisk(_ institutes: [Institute]) {
        guard let url = institutesCacheURL(),
              let data = try? JSONEncoder().encode(institutes) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private func readInstitutesCacheFromDisk() -> [Institute] {
        guard let url = institutesCacheURL(),
              let data = try? Data(contentsOf: url),
              let cache = try? MyMPSUBackendSystem.jsonDecoder.decode([Institute].self, from: data) else {
            return []
        }
        return cache
    }

    private func fetchDTOArray<T: Decodable>(from url: URL, context: String) async -> [T] {
        log("\(context) URL: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse {
                    let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                    log("\(context) HTTP \(httpResponse.statusCode), body: \(body)")
                }
                return []
            }

            return try MyMPSUBackendSystem.jsonDecoder.decode([T].self, from: data)
        } catch {
            log("\(context) error: \(error)")
            return []
        }
    }

    private func fetchGroups() async -> [GroupDTO] {
        guard let url = URL(string: "\(baseURL)/groups") else {
            log("fetchGroups: invalid URL")
            return []
        }
        return await fetchDTOArray(from: url, context: "fetchGroups")
    }

    private func fetchFaculties() async -> [FacultyDTO] {
        guard let url = URL(string: "\(baseURL)/faculties") else {
            log("fetchFaculties: invalid URL")
            return []
        }
        return await fetchDTOArray(from: url, context: "fetchFaculties")
    }

    private func fetchTeachers(teacherIDs: [Int]) async -> [TeacherDTO] {
        let query = teacherIDs.map(String.init).joined(separator: ",")
        var components = URLComponents(string: "\(baseURL)/teachers")
        if !query.isEmpty {
            components?.queryItems = [URLQueryItem(name: "teacher_ids", value: query)]
        }
        guard let url = components?.url else {
            log("fetchTeachers: invalid URL")
            return []
        }
        return await fetchDTOArray(from: url, context: "fetchTeachers")
    }

    private func fetchRooms(roomIDs: [Int]) async -> [RoomDTO] {
        let query = roomIDs.map(String.init).joined(separator: ",")
        var components = URLComponents(string: "\(baseURL)/rooms")
        if !query.isEmpty {
            components?.queryItems = [URLQueryItem(name: "room_ids", value: query)]
        }
        guard let url = components?.url else {
            log("fetchRooms: invalid URL")
            return []
        }
        return await fetchDTOArray(from: url, context: "fetchRooms")
    }

    private func fetchBuildings(buildingIDs: [Int]) async -> [BuildingDTO] {
        let query = buildingIDs.map(String.init).joined(separator: ",")
        var components = URLComponents(string: "\(baseURL)/buildings")
        if !query.isEmpty {
            components?.queryItems = [URLQueryItem(name: "building_ids", value: query)]
        }
        guard let url = components?.url else {
            log("fetchBuildings: invalid URL")
            return []
        }
        return await fetchDTOArray(from: url, context: "fetchBuildings")
    }

    private func formatTime(from isoString: String) -> String {
        if let date = Self.iso8601DateFormatter.date(from: isoString)
            ?? Self.fallbackISO8601DateFormatter.date(from: isoString) {
            return Self.timeFormatter.string(from: date)
        }

        return String(isoString.prefix(5))
    }
    
    private func formatDay(from isoString: String) -> String {
        if let date = Self.iso8601DateFormatter.date(from: isoString)
            ?? Self.fallbackISO8601DateFormatter.date(from: isoString) {
            return Self.sessionDayFormatter.string(from: date)
        }
        return ""
    }
}

private struct AppleSignInRequest: Encodable {
    let identityToken: String
    let authorizationCode: String?
    let appleUserID: String
    let fullName: String?
    let email: String?
    let deviceId: String
    let deviceName: String?
    let platform: String
    let appVersion: String?
}

private struct AuthDeviceMetadata {
    let deviceId: String
    let deviceName: String?
    let platform: String
    let appVersion: String?
}

private struct AccountSessionsResponse: Decodable {
    let sessions: [AccountSession]?
    let activeSessions: [AccountSession]?
    let devices: [AccountSession]?
    let data: [AccountSession]?

    private enum CodingKeys: String, CodingKey {
        case sessions
        case activeSessions
        case snakeActiveSessions = "active_sessions"
        case devices
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessions = try container.decodeIfPresent([AccountSession].self, forKey: .sessions)
        activeSessions = try container.decodeIfPresent([AccountSession].self, forKey: .activeSessions)
            ?? container.decodeIfPresent([AccountSession].self, forKey: .snakeActiveSessions)
        devices = try container.decodeIfPresent([AccountSession].self, forKey: .devices)
        data = try container.decodeIfPresent([AccountSession].self, forKey: .data)
    }

    func resolvedSessions() throws -> [AccountSession] {
        if let sessions { return sessions }
        if let activeSessions { return activeSessions }
        if let devices { return devices }
        if let data { return data }
        throw APIServiceError.invalidResponse
    }
}

private struct RoleRequestsResponse: Decodable {
    let requests: [RoleRequest]
}

private struct AdminSystemNoticesResponse: Decodable {
    let notices: [SystemNotice]
}

private struct ProfileUserResponse: Decodable {
    let user: AppleUser?
    let profile: AppleUser?

    var resolvedUser: AppleUser {
        get throws {
            if let user {
                return user
            }
            if let profile {
                return profile
            }
            throw APIServiceError.invalidResponse
        }
    }
}

private struct ProfileUpdateRequest: Encodable {
    let name: String
}

private struct PasswordSetupRequest: Encodable {
    let password: String
}

private struct PasswordLoginRequest: Encodable {
    let email: String
    let password: String
    let deviceId: String
    let deviceName: String?
    let platform: String
    let appVersion: String?
}

private struct PasswordSignupRequest: Encodable {
    let email: String
    let password: String
    let displayName: String
    let deviceId: String
    let deviceName: String?
    let platform: String
    let appVersion: String?
}

private struct PasswordSignupResponse: Decodable {
    let status: String
    let email: String
}

private struct PasswordSignupVerificationRequest: Encodable {
    let email: String
    let code: String
    let deviceId: String
    let deviceName: String?
    let platform: String
    let appVersion: String?
}

private struct PasswordChangeRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

private struct PasswordResetRequest: Encodable {
    let email: String
}

private struct PasswordResetConfirmationRequest: Encodable {
    let code: String
    let newPassword: String
}

private struct AccountEmailChangeRequest: Encodable {
    let email: String
}

private struct AccountEmailConfirmationRequest: Encodable {
    let code: String
}

private struct ContactEmailRequest: Encodable {
    let email: String
}

enum APIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case httpStatusWithBody(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid API response."
        case .httpStatus(let statusCode):
            return "API request failed with HTTP \(statusCode)."
        case .httpStatusWithBody(let statusCode, let body):
            if let body, !body.isEmpty {
                return "API request failed with HTTP \(statusCode): \(body)"
            }
            return "API request failed with HTTP \(statusCode)."
        }
    }
}

private struct ScheduleResponseDTO: Decodable, Sendable {
    let id: Int
    let startTime: String
    let endTime: String
    let groupID: Int
    let subGroupID: Int?
    let name: String
    let isExam: Bool
    let note: String?
    let type: String
    let teacherID: Int?
    let roomID: Int?
    let classURL: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case groupID = "group_id"
        case subGroupID = "sub_group_id"
        case name
        case isExam = "is_exam"
        case note
        case type
        case teacherID = "teacher_id"
        case roomID = "room_id"
        case classURL = "class_url"
    }
}

private struct GroupDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let facultyID: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case facultyID = "faculty_id"
    }
}

private struct FacultyDTO: Decodable, Sendable {
    let id: Int
    let name: String
}

private struct TeacherDTO: Decodable, Sendable {
    let id: Int
    let name: String
}

private struct RoomDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let buildingID: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case buildingID = "building_id"
    }
}

private struct BuildingDTO: Decodable, Sendable {
    let id: Int
    let name: String
}
