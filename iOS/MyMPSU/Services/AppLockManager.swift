import Foundation
#if os(iOS)
internal import Combine
import CryptoKit
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    private static let passcodeHashKey = "mympsu_app_lock_passcode_hash"
    private let lockEnabledKey = "appLockEnabled"
    private let biometryEnabledKey = "appLockBiometryEnabled"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isBiometryEnabled: Bool
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var isPrivacyCoverVisible = false
    private var lockSuppressionCount = 0

    private init() {
        let defaults = UserDefaults.standard
        let hasStoredPasscode = KeychainHelper.read(Self.passcodeHashKey) != nil
        let storedIsEnabled = defaults.bool(forKey: lockEnabledKey) && hasStoredPasscode
        isEnabled = storedIsEnabled
        isBiometryEnabled = defaults.bool(forKey: biometryEnabledKey)
        isUnlocked = !storedIsEnabled
        if !hasStoredPasscode {
            defaults.set(false, forKey: lockEnabledKey)
            defaults.set(false, forKey: biometryEnabledKey)
        }
    }

    var shouldShowLockScreen: Bool {
        isEnabled && !isLockSuppressed && !isUnlocked
    }

    var shouldShowPrivacyCover: Bool {
        isEnabled && !isLockSuppressed && isPrivacyCoverVisible && isUnlocked
    }

    var isLockSuppressed: Bool {
        lockSuppressionCount > 0
    }

    var hasPasscode: Bool {
        KeychainHelper.read(Self.passcodeHashKey) != nil
    }

    var canUseBiometry: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometryTitle: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "биометрию"
        }
    }

    func setPasscode(_ passcode: String) throws {
        try KeychainHelper.save(Self.hash(passcode), for: Self.passcodeHashKey)
        isEnabled = true
        isUnlocked = true
        UserDefaults.standard.set(true, forKey: lockEnabledKey)
    }

    func disable() {
        KeychainHelper.delete(Self.passcodeHashKey)
        isEnabled = false
        isBiometryEnabled = false
        isUnlocked = true
        UserDefaults.standard.set(false, forKey: lockEnabledKey)
        UserDefaults.standard.set(false, forKey: biometryEnabledKey)
    }

    func setBiometryEnabled(_ isEnabled: Bool) {
        isBiometryEnabled = isEnabled && canUseBiometry
        UserDefaults.standard.set(isBiometryEnabled, forKey: biometryEnabledKey)
    }

    func lockIfNeeded() {
        guard isEnabled, !isLockSuppressed else { return }
        isPrivacyCoverVisible = false
        isUnlocked = false
    }

    func showPrivacyCoverIfNeeded() {
        guard isEnabled, !isLockSuppressed, isUnlocked else { return }
        isPrivacyCoverVisible = true
    }

    func hidePrivacyCover() {
        isPrivacyCoverVisible = false
    }

    func beginExternalAuthentication() {
        lockSuppressionCount += 1
        isPrivacyCoverVisible = false
    }

    func endExternalAuthentication() {
        lockSuppressionCount = max(0, lockSuppressionCount - 1)
        isPrivacyCoverVisible = false
    }

    func unlock(with passcode: String) -> Bool {
        guard let savedHash = KeychainHelper.read(Self.passcodeHashKey), savedHash == Self.hash(passcode) else {
            return false
        }
        isPrivacyCoverVisible = false
        isUnlocked = true
        return true
    }

    func authenticateWithBiometry() async -> Bool {
        guard isEnabled, isBiometryEnabled else { return false }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Разблокировать MyMPSU"
            )
            if success {
                isPrivacyCoverVisible = false
                isUnlocked = true
            }
            return success
        } catch {
            return false
        }
    }

    private static func hash(_ passcode: String) -> String {
        let digest = SHA256.hash(data: Data(passcode.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
#endif
