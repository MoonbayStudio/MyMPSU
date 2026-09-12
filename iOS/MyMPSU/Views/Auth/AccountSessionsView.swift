import SwiftUI
internal import Combine

@MainActor
final class AccountSessionsViewModel: ObservableObject {
    @Published var sessions: [AccountSession] = []
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let loadedSessions = try await APIService.shared.fetchAccountSessions()
            sessions = loadedSessions.filter { !$0.isRevoked }
            print("[AccountSessionsViewModel] Loaded account sessions: total=\(loadedSessions.count), active=\(sessions.count)")
        } catch {
            print("[AccountSessionsViewModel] Failed to load account sessions: \(String(describing: error))")
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    func revoke(_ session: AccountSession) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        do {
            try await APIService.shared.revokeAccountSession(id: session.id)
            if session.isCurrent {
                AuthSessionManager.shared.signOut()
            } else {
                sessions.removeAll { $0.id == session.id }
                await load()
            }
            successMessage = "Сеанс завершён."
            isProcessing = false
            return session.isCurrent
        } catch {
            errorMessage = Self.message(for: error)
            isProcessing = false
            return false
        }
    }

    func logoutOthers() async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        do {
            try await APIService.shared.logoutOtherAccountSessions()
            await load()
            successMessage = "Другие сеансы завершены."
        } catch {
            errorMessage = Self.message(for: error)
        }
        isProcessing = false
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Попробуйте ещё раз."
        }
        if case APIServiceError.httpStatusWithBody(let statusCode, _) = error {
            return message(forHTTPStatus: statusCode)
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            return message(forHTTPStatus: statusCode)
        }
        return "Не удалось загрузить сеансы."
    }

    private static func message(forHTTPStatus statusCode: Int) -> String {
        switch statusCode {
        case 401: return "Нужно снова войти в аккаунт."
        case 403: return "Недостаточно прав для этого действия."
        case 404: return "Endpoint сеансов пока недоступен."
        default: return "Backend вернул ошибку \(statusCode)."
        }
    }
}

struct AccountSessionsView: View {
    let activeTheme: AppTheme
    let onBack: () -> Void

    @StateObject private var viewModel = AccountSessionsViewModel()
    @State private var pendingRevoke: AccountSession?
    @State private var showLogoutOthersConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Устройства") {
                onBack()
            }
#endif

            statusArea

            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.isLoading || viewModel.isProcessing)

                Button {
                    showLogoutOthersConfirmation = true
                } label: {
                    Label("Выйти на других", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .foregroundColor(.red)
                .disabled(viewModel.isProcessing || viewModel.sessions.filter { !$0.isCurrent && !$0.isRevoked }.isEmpty)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .padding(.horizontal, 4)

            sessionsContent
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuTask {
            await viewModel.load()
        }
        .alert(isPresented: revokeAlertBinding) {
            Alert(
                title: Text("Завершить сеанс?"),
                message: Text(pendingRevoke?.isCurrent == true ? "Текущий вход будет завершён и приложение выйдет из аккаунта." : "Этот вход больше не сможет использовать аккаунт."),
                primaryButton: .destructive(Text("Завершить")) {
                    guard let pendingRevoke else { return }
                    self.pendingRevoke = nil
                    Task { _ = await viewModel.revoke(pendingRevoke) }
                },
                secondaryButton: .cancel(Text("Отмена")) {
                    pendingRevoke = nil
                }
            )
        }
        .alert(isPresented: $showLogoutOthersConfirmation) {
            Alert(
                title: Text("Выйти на других устройствах?"),
                message: Text("Текущий сеанс останется активным, остальные устройства будут отключены."),
                primaryButton: .destructive(Text("Завершить")) {
                    Task { await viewModel.logoutOthers() }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        if viewModel.isLoading && viewModel.sessions.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                Text("Загружаем активные сеансы")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 4)
        }
        if let successMessage = viewModel.successMessage {
            Label(successMessage, systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.green)
                .padding(.horizontal, 4)
        }
        if let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.red)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var sessionsContent: some View {
        if !viewModel.isLoading && viewModel.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.accentColor)
                Text("Активных сеансов нет.")
                    .font(.headline)
                Text("Когда backend вернёт список устройств, они появятся здесь.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .mympsuAdaptiveGlassCard(cornerRadius: 22)
            .padding(.horizontal, 4)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.sessions) { session in
                        AccountSessionCard(
                            session: session,
                            isProcessing: viewModel.isProcessing,
                            onRevoke: {
                                if session.isCurrent {
                                    pendingRevoke = session
                                } else {
                                    Task { _ = await viewModel.revoke(session) }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 24)
            }
        }
    }

    private var revokeAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingRevoke != nil },
            set: { isPresented in
                if !isPresented { pendingRevoke = nil }
            }
        )
    }
}

struct AccountSessionCard: View {
    let session: AccountSession
    var isProcessing: Bool = false
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(session.isCurrent ? .accentColor : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(deviceTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if session.isCurrent {
                            Text("Текущее")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(detailsText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if let lastSeenText {
                Label("Последняя активность: \(lastSeenText)", systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let revokedAt = session.revokedAt, !revokedAt.isEmpty {
                Label("Завершён: \(revokedAt)", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button(action: onRevoke) {
                    Label(session.isCurrent ? "Завершить текущий сеанс" : "Завершить сеанс", systemImage: "xmark.circle.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.red)
                .disabled(isProcessing)
            }
        }
        .mympsuDefaultSurface(cornerRadius: 22, padding: 12)
    }

    private var deviceTitle: String {
        let name = session.deviceName?.mympsuTrimmed ?? ""
        return name.isEmpty ? "Неизвестное устройство" : name
    }

    private var detailsText: String {
        [platformText, session.appVersion.map { "версия \($0)" }, session.safeIpText]
            .compactMap { $0?.mympsuTrimmed }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private var platformText: String? {
        guard let platform = session.platform?.mympsuTrimmed, !platform.isEmpty else { return nil }
        switch platform.lowercased() {
        case "ios":
            return "iOS"
        case "macos":
            return "macOS"
        case "android":
            return "Android"
        case "web":
            return "Web"
        case "unknown":
            return nil
        default:
            return platform
        }
    }

    private var lastSeenText: String? {
        guard let value = session.lastSeenAt?.mympsuTrimmed, !value.isEmpty else { return nil }
        guard let date = Self.iso8601WithFractionalSeconds.date(from: value)
            ?? Self.iso8601WithoutFractionalSeconds.date(from: value)
            ?? Self.backendDateFormatter.date(from: value) else {
            return value.replacingOccurrences(of: "T", with: " ")
        }
        return Self.displayDateFormatter.string(from: date)
    }

    private var symbolName: String {
        let platform = session.platform?.lowercased() ?? ""
        if platform.contains("mac") { return "laptopcomputer" }
        if platform.contains("ipad") { return "ipad" }
        if platform.contains("web") { return "globe" }
        return "iphone"
    }

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601WithoutFractionalSeconds = ISO8601DateFormatter()

    private static let backendDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = .current
        formatter.dateFormat = "d MMMM yyyy HH:mm"
        return formatter
    }()
}
