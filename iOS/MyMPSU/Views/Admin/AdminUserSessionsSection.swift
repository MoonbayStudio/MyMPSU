import SwiftUI
internal import Combine

@MainActor
final class AdminUserSessionsViewModel: ObservableObject {
    @Published var sessions: [AccountSession] = []
    @Published var isLoading = false
    @Published var processingSessionId: String?
    @Published var errorMessage: String?

    func load(userId: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            sessions = try await APIService.shared.fetchAdminUserSessions(userId: userId)
        } catch {
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    func revoke(_ session: AccountSession, userId: String) async {
        guard processingSessionId == nil else { return }
        processingSessionId = session.id
        errorMessage = nil
        do {
            try await APIService.shared.revokeAdminSession(id: session.id)
            await load(userId: userId)
        } catch {
            errorMessage = Self.message(for: error)
        }
        processingSessionId = nil
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна."
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
        case 401, 403: return "Недостаточно прав."
        case 404: return "Endpoint сеансов пользователя недоступен."
        default: return "Backend вернул ошибку \(statusCode)."
        }
    }
}

struct AdminUserSessionsSection: View {
    let userId: String
    @StateObject private var viewModel = AdminUserSessionsViewModel()
    @State private var pendingRevoke: AccountSession?

    var body: some View {
        MyMPSUSettingsCard {
            HStack {
                Label("Активные сессии пользователя", systemImage: "desktopcomputer.and.macbook")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Button {
                    Task { await viewModel.load(userId: userId) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }

            if viewModel.isLoading && viewModel.sessions.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Загружаем сеансы")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            } else if viewModel.sessions.isEmpty {
                Text("Активных сеансов нет.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.sessions) { session in
                        AccountSessionCard(
                            session: session,
                            isProcessing: viewModel.processingSessionId == session.id,
                            onRevoke: { pendingRevoke = session }
                        )
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .mympsuTask {
            await viewModel.load(userId: userId)
        }
        .alert(isPresented: revokeAlertBinding) {
            Alert(
                title: Text("Отозвать сессию?"),
                message: Text("Пользователь будет вынужден войти снова на этом устройстве."),
                primaryButton: .destructive(Text("Отозвать")) {
                    guard let pendingRevoke else { return }
                    self.pendingRevoke = nil
                    Task { await viewModel.revoke(pendingRevoke, userId: userId) }
                },
                secondaryButton: .cancel(Text("Отмена")) {
                    pendingRevoke = nil
                }
            )
        }
    }

    private var revokeAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingRevoke != nil },
            set: { if !$0 { pendingRevoke = nil } }
        )
    }
}
