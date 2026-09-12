import Foundation
internal import Combine

final class AuthSessionManager: ObservableObject {
    static let shared = AuthSessionManager()
    static let sessionTokenKey = "mympsu_session_token"

    @Published private(set) var currentUser: AppleUser?
    @Published private(set) var isAuthenticated: Bool

    private let cachedUserKey = "mympsu_cached_user"

    private init() {
        let token = KeychainHelper.read(Self.sessionTokenKey)
        isAuthenticated = token?.isEmpty == false
        currentUser = Self.readCachedUser(key: cachedUserKey)
    }

    func apply(_ response: AppleSignInResponse) throws {
        try KeychainHelper.save(response.token, for: Self.sessionTokenKey)
        updateCurrentUser(response.user)
        isAuthenticated = true
    }

    func updateCurrentUser(_ user: AppleUser) {
        currentUser = user
        if let data = try? MyMPSUBackendSystem.jsonEncoder.encode(user) {
            UserDefaults.standard.set(data, forKey: cachedUserKey)
        }
    }

    func signOut() {
        KeychainHelper.delete(Self.sessionTokenKey)
        UserDefaults.standard.removeObject(forKey: cachedUserKey)
        currentUser = nil
        isAuthenticated = false
    }

    private static func readCachedUser(key: String) -> AppleUser? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? MyMPSUBackendSystem.jsonDecoder.decode(AppleUser.self, from: data)
    }
}
