import Foundation
#if os(iOS) || os(macOS)
import GoogleSignIn
#endif
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS) || os(macOS)
struct GoogleSignInCredential {
    let idToken: String
    let accessToken: String
    let userID: String?
    let email: String?
    let fullName: String?
}

@MainActor
final class GoogleSignInService {
    static let shared = GoogleSignInService()

    private init() {}

    func signIn() async throws -> GoogleSignInCredential {
        try configureIfNeeded()
#if os(iOS)
        let presentingViewController = try Self.presentingViewController()
        let result = try await performSignIn(with: presentingViewController)
#elseif os(macOS)
        let presentingWindow = try Self.presentingWindow()
        let result = try await performSignIn(with: presentingWindow)
#endif

        guard let idToken = result.user.idToken?.tokenString, !idToken.isEmpty else {
            throw GoogleSignInServiceError.missingIDToken
        }

        return GoogleSignInCredential(
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString,
            userID: result.user.userID,
            email: result.user.profile?.email,
            fullName: result.user.profile?.name
        )
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    func handleIncomingURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    private func configureIfNeeded() throws {
        if GIDSignIn.sharedInstance.configuration != nil { return }
        guard let clientID = Self.googleServiceValue(for: "CLIENT_ID") else {
            throw GoogleSignInServiceError.missingClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

#if os(iOS)
    private func performSignIn(with presentingViewController: UIViewController) async throws -> GIDSignInResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                Self.resumeGoogleSignIn(continuation, result: result, error: error)
            }
        }
    }
#elseif os(macOS)
    private func performSignIn(with presentingWindow: NSWindow) async throws -> GIDSignInResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow) { result, error in
                Self.resumeGoogleSignIn(continuation, result: result, error: error)
            }
        }
    }
#endif

    nonisolated private static func resumeGoogleSignIn(
        _ continuation: CheckedContinuation<GIDSignInResult, Error>,
        result: GIDSignInResult?,
        error: Error?
    ) {
        if let error {
            continuation.resume(throwing: error)
            return
        }

        guard let result else {
            continuation.resume(throwing: GoogleSignInServiceError.missingResult)
            return
        }

        continuation.resume(returning: result)
    }

    private static func googleServiceValue(for key: String) -> String? {
        for plist in googleServicePlists() {
            guard let value = plist[key] as? String else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private static func googleServicePlists() -> [NSDictionary] {
        let resourceURLs = Bundle.main.urls(forResourcesWithExtension: "plist", subdirectory: nil) ?? []
        return resourceURLs.compactMap { url in
            guard let plist = NSDictionary(contentsOf: url),
                  plist["CLIENT_ID"] is String,
                  plist["REVERSED_CLIENT_ID"] is String else {
                return nil
            }
            return plist
        }
    }

#if os(iOS)
    private static func presentingViewController() throws -> UIViewController {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        guard let rootViewController = keyWindow?.rootViewController else {
            throw GoogleSignInServiceError.missingPresentingViewController
        }
        return topViewController(from: rootViewController)
    }

    private static func topViewController(from rootViewController: UIViewController) -> UIViewController {
        if let presented = rootViewController.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigationController = rootViewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return topViewController(from: visibleViewController)
        }
        if let tabBarController = rootViewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return topViewController(from: selectedViewController)
        }
        return rootViewController
    }
#elseif os(macOS)
    private static func presentingWindow() throws -> NSWindow {
        if let keyWindow = NSApplication.shared.keyWindow {
            return keyWindow
        }
        if let visibleWindow = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            return visibleWindow
        }
        throw GoogleSignInServiceError.missingPresentingViewController
    }
#endif
}

enum GoogleSignInServiceError: LocalizedError {
    case missingClientID
    case missingPresentingViewController
    case missingResult
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "GoogleService-Info.plist is missing CLIENT_ID."
        case .missingPresentingViewController:
            return "No view controller is available to present Google Sign-In."
        case .missingResult:
            return "Google Sign-In did not return a result."
        case .missingIDToken:
            return "Google Sign-In did not return an ID token."
        }
    }
}
#endif
