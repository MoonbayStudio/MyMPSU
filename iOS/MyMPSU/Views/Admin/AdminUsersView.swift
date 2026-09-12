import SwiftUI
internal import Combine

@MainActor
final class AdminUsersViewModel: ObservableObject {
    @Published var users: [AdminUserDTO] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selectedUser: AdminUserDTO?
    @Published var processingRole: String?
    @Published var pendingRoleRequests: [RoleRequestDTO] = []
    @Published var isLoadingRoleRequests = false
    @Published var processingRoleRequestId: String?
    @Published var availableBadges: [UserBadge] = []
    @Published var isLoadingBadges = false
    @Published var processingBadgeCode: String?

    var filteredUsers: [AdminUserDTO] {
        let query = searchText.mympsuTrimmed.lowercased()
        guard !query.isEmpty else { return users }
        return users.filter { user in
            user.displayName.lowercased().contains(query)
            || (user.email ?? "").lowercased().contains(query)
            || user.tier.lowercased().contains(query)
            || user.roles.contains { role in
                role.type.lowercased().contains(query) || role.title.lowercased().contains(query)
            }
            || user.pendingRoleRequests.contains { $0.requestedRole.lowercased().contains(query) }
        }
    }

    func loadUsers() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            users = try await APIService.shared.fetchAdminUsers()
            refreshSelectedUser()
        } catch {
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    func loadAll() async {
        await loadUsers()
        await loadBadges()
    }

    func loadBadges() async {
        guard !isLoadingBadges else { return }
        isLoadingBadges = true
        errorMessage = nil
        do {
            availableBadges = UserBadge.sortedForAdministration(try await APIService.shared.fetchAdminBadges())
        } catch {
            errorMessage = Self.message(for: error)
        }
        isLoadingBadges = false
    }

    func loadPendingRoleRequests() async {
        guard !isLoadingRoleRequests else { return }
        isLoadingRoleRequests = true
        errorMessage = nil
        do {
            pendingRoleRequests = try await APIService.shared.fetchAdminRoleRequests(status: "pending")
        } catch {
            errorMessage = Self.message(for: error)
        }
        isLoadingRoleRequests = false
    }

    func setRole(_ role: String, enabled: Bool, for user: AdminUserDTO) async {
        guard processingRole == nil else { return }
        processingRole = role
        errorMessage = nil
        successMessage = nil

        do {
            let updatedUser: AdminUserDTO
            if enabled {
                updatedUser = try await APIService.shared.grantRole(userId: user.id, role: role)
            } else {
                updatedUser = try await APIService.shared.revokeRole(userId: user.id, role: role)
            }
            applyUpdatedUser(updatedUser)
            refreshSelectedUser()
            successMessage = enabled ? "Роль выдана." : "Роль снята."
        } catch {
            errorMessage = Self.message(for: error)
        }

        processingRole = nil
    }

    func setBadge(_ badge: UserBadge, enabled: Bool, note: String?, for user: AdminUserDTO) async {
        guard processingBadgeCode == nil else { return }
        processingBadgeCode = badge.code
        errorMessage = nil
        successMessage = nil

        do {
            let updatedUser: AdminUserDTO
            if enabled {
                updatedUser = try await APIService.shared.grantBadge(
                    userId: user.id,
                    badgeCode: badge.code,
                    note: note?.mympsuTrimmed.isEmpty == false ? note?.mympsuTrimmed : nil
                )
            } else {
                updatedUser = try await APIService.shared.revokeBadge(userId: user.id, badgeCode: badge.code)
            }
            applyUpdatedUser(updatedUser)
            refreshSelectedUser()
            successMessage = enabled ? "Значок выдан." : "Значок снят."
        } catch {
            errorMessage = Self.message(for: error)
        }

        processingBadgeCode = nil
    }

    func approve(_ request: RoleRequestDTO) async {
        await processRoleRequest(request) {
            try await APIService.shared.approveAdminRoleRequest(id: request.id)
        }
    }

    func reject(_ request: RoleRequestDTO) async {
        await processRoleRequest(request) {
            try await APIService.shared.rejectAdminRoleRequest(id: request.id)
        }
    }

    private func processRoleRequest(_ request: RoleRequestDTO, action: () async throws -> Void) async {
        guard processingRoleRequestId == nil else { return }
        processingRoleRequestId = request.id
        errorMessage = nil
        successMessage = nil

        do {
            try await action()
            pendingRoleRequests.removeAll { $0.id == request.id }
            users = try await APIService.shared.fetchAdminUsers()
            await refreshCurrentUserIfNeeded(changedUserId: nil)
            refreshSelectedUser()
            successMessage = "Заявка обработана."
        } catch {
            errorMessage = Self.message(for: error)
        }

        processingRoleRequestId = nil
    }

    private func refreshSelectedUser() {
        guard let selectedUser else { return }
        self.selectedUser = users.first { $0.id == selectedUser.id }
    }

    private func applyUpdatedUser(_ updatedUser: AdminUserDTO) {
        if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
            users[index] = updatedUser
        } else {
            users.append(updatedUser)
        }

        guard let currentUser = AuthSessionManager.shared.currentUser,
              currentUser.matchesAdminUser(updatedUser) else {
            return
        }
        AuthSessionManager.shared.updateCurrentUser(currentUser.applyingAdminSnapshot(updatedUser))
    }

    private func refreshCurrentUserIfNeeded(changedUserId: String?) async {
        guard let currentUser = AuthSessionManager.shared.currentUser else { return }
        let changedAdminUser = changedUserId.flatMap { id in users.first { $0.id == id } }
        let changedCurrentUser = changedAdminUser.map { currentUser.matchesAdminUser($0) } ?? (changedUserId == nil)
        guard changedCurrentUser else { return }

        if let currentUser = AuthSessionManager.shared.currentUser,
           let adminSnapshot = users.first(where: { currentUser.matchesAdminUser($0) }) {
            AuthSessionManager.shared.updateCurrentUser(currentUser.applyingAdminSnapshot(adminSnapshot))
        }

        do {
            let user = try await APIService.shared.refreshCurrentUser()
            if let adminSnapshot = users.first(where: { user.matchesAdminUser($0) }), user.roles.isEmpty || user.roleTypes != adminSnapshot.roleTypes {
                AuthSessionManager.shared.updateCurrentUser(user.applyingAdminSnapshot(adminSnapshot))
            } else {
                AuthSessionManager.shared.updateCurrentUser(user)
            }
        } catch {
            print("[AdminUsersViewModel] current user refresh after role change failed: \(error)")
        }
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Проверьте подключение и попробуйте ещё раз."
        }

        if case APIServiceError.httpStatusWithBody(let statusCode, let body) = error {
            if statusCode == 403, body?.contains("Cannot revoke admin role from owner") == true {
                return "Нельзя снять роль администратора с владельца проекта."
            }
            if statusCode == 403, body?.contains("Cannot revoke roles from owner") == true {
                return "Backend сейчас запрещает снимать роли с владельца проекта."
            }
            if statusCode == 400, body?.contains("Invalid role") == true {
                return "Backend не принял ключ роли."
            }
            return message(forHTTPStatus: statusCode)
        }

        if case APIServiceError.httpStatus(let statusCode) = error {
            return message(forHTTPStatus: statusCode)
        }

        return "Не удалось выполнить действие. Попробуйте ещё раз."
    }

    private static func message(forHTTPStatus statusCode: Int) -> String {
            switch statusCode {
            case 401, 403:
                return "Недостаточно прав для админки."
            case 404:
                return "Админский endpoint пока недоступен."
            default:
                return "Backend вернул ошибку \(statusCode)."
            }
    }
}

struct AdminUsersView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @StateObject private var viewModel = AdminUsersViewModel()
    @State private var currentScreen: AdminScreen = .root
    @State private var previousScreen: AdminScreen = .root
    @State private var adminScreenDragOffset: CGFloat = 0
    var onBack: (() -> Void)? = nil
    var toolbarTitle: Binding<String>? = nil
    var toolbarShowsBackButton: Binding<Bool>? = nil
    var toolbarBackRequest: Binding<Int>? = nil
    var toolbarShowsRefreshButton: Binding<Bool>? = nil
    var toolbarRefreshRequest: Binding<Int>? = nil
    @ObservedObject var scheduleViewModel: ScheduleViewModel

    private enum AdminScreen: Equatable {
        case root
        case roleEditor
        case moderation
        case settings
        case notices
    }

    private struct BackSwipeConfig {
        let edgeWidth: CGFloat
        let triggerRatio: CGFloat
        let predictedTriggerRatio: CGFloat
        let completeResponse: CGFloat
        let completeDamping: CGFloat
        let cancelResponse: CGFloat
        let cancelDamping: CGFloat

        static let `default` = BackSwipeConfig(
            edgeWidth: 28,
            triggerRatio: 0.28,
            predictedTriggerRatio: 0.4,
            completeResponse: 0.24,
            completeDamping: 0.9,
            cancelResponse: 0.28,
            cancelDamping: 0.88
        )
    }

    private let backSwipeConfig = BackSwipeConfig.default

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
        ZStack {
            if adminScreenDragOffset > 0 {
                adminBackDestinationView
            }

            adminCurrentScreenView
                .offset(x: max(0, adminScreenDragOffset))
                .transition(adminScreenTransition)
        }
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .overlay(
            Group {
                if currentScreen != .root {
                    Color.clear
                        .frame(width: backSwipeConfig.edgeWidth)
                        .contentShape(Rectangle())
                        .highPriorityGesture(interactiveAdminBackGesture)
                }
            },
            alignment: .leading
        )
        .animation(.easeInOut(duration: 0.18), value: currentScreen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mympsuTask {
            syncToolbarNavigationState()
            await viewModel.loadAll()
        }
        .onChange(of: currentScreen) { _ in
            syncToolbarNavigationState()
        }
        .onChange(of: toolbarRefreshRequest?.wrappedValue ?? 0) { _ in
            guard toolbarRefreshRequest != nil, currentScreen == .root else { return }
            Task { await viewModel.loadAll() }
        }
        .onChange(of: toolbarBackRequest?.wrappedValue ?? 0) { _ in
            guard toolbarBackRequest != nil else { return }
            if currentScreen == .root {
                close()
            } else {
                triggerAdminBackNavigation()
            }
        }
    }

    private var rootContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            searchBar
            statusArea
            adminManagementEntries
            legacyModerationEntry
            usersContent
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .alert(isPresented: adminAlertIsPresented) {
            Alert(
                title: Text("Админка"),
                message: Text(viewModel.successMessage ?? viewModel.errorMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    viewModel.successMessage = nil
                    viewModel.errorMessage = nil
                }
            )
        }
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
    }

    @ViewBuilder
    private var adminCurrentScreenView: some View {
        switch currentScreen {
        case .root:
            rootContent
        case .roleEditor:
            if let user = viewModel.selectedUser {
                UserRoleEditorView(viewModel: viewModel, user: user, onBack: triggerAdminBackNavigation)
            } else {
                rootContent
            }
        case .moderation:
            ModerationRoleRequestsView(
                onBack: triggerAdminBackNavigation,
                toolbarRefreshRequest: toolbarRefreshRequest
            )
        case .settings:
            AdminRuntimeSettingsView(
                activeTheme: activeTheme,
                scheduleViewModel: scheduleViewModel,
                onBack: triggerAdminBackNavigation,
                toolbarRefreshRequest: toolbarRefreshRequest
            )
        case .notices:
            AdminSystemNoticesView(
                activeTheme: activeTheme,
                onBack: triggerAdminBackNavigation,
                toolbarRefreshRequest: toolbarRefreshRequest
            )
        }
    }

    @ViewBuilder
    private var adminBackDestinationView: some View {
        rootContent
    }

    private var adminScreenTransition: AnyTransition {
        let oldLevel = adminScreenLevel(previousScreen)
        let newLevel = adminScreenLevel(currentScreen)

        if newLevel < oldLevel {
            return .asymmetric(insertion: .identity, removal: .move(edge: .trailing))
        } else {
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .opacity
            )
        }
    }

    private func adminScreenLevel(_ screen: AdminScreen) -> Int {
        switch screen {
        case .root:
            return 0
        case .roleEditor, .moderation, .settings, .notices:
            return 1
        }
    }

    private var adminAlertIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.successMessage != nil || viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.successMessage = nil
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    @ViewBuilder
    private var header: some View {
#if os(iOS)
        HStack(spacing: 10) {
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Админка") {
                close()
            }

            Spacer(minLength: 0)

            ThemedChrome(shape: activeTheme.headerShape) {
                Button {
                    Task {
                        await viewModel.loadAll()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .disabled(viewModel.isLoading || viewModel.isLoadingRoleRequests)
                .accessibilityLabel("Обновить")
            }
        }
#else
        EmptyView()
#endif
    }

    private var adminManagementEntries: some View {
        VStack(spacing: 10) {
            Button {
                openAdminScreen(.settings)
            } label: {
                HStack {
                    Label("Дебаг", systemImage: "ladybug.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()

            Button {
                openAdminScreen(.notices)
            } label: {
                HStack {
                    Label("Уведомления / Техработы", systemImage: "megaphone.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
        }
        .padding(.horizontal, 4)
    }

    private var legacyModerationEntry: some View {
        Button {
            openAdminScreen(.moderation)
        } label: {
            HStack {
                Label("Модерация ролей", systemImage: "person.badge.shield.checkmark")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .mympsuDefaultSurface()
        }
        .mympsuInteractiveButtonStyle()
        .padding(.horizontal, 4)
    }

    private func close() {
        if let onBack {
            onBack()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func openAdminScreen(_ screen: AdminScreen) {
        previousScreen = currentScreen
        adminScreenDragOffset = 0
        withAnimation(.easeInOut(duration: 0.18)) {
            currentScreen = screen
            syncToolbarNavigationState(screen)
        }
    }

    private func triggerAdminBackNavigation() {
        guard currentScreen != .root else {
            close()
            return
        }

        let sourceScreen = currentScreen
        withAnimation(.interactiveSpring(response: backSwipeConfig.completeResponse,
                                         dampingFraction: backSwipeConfig.completeDamping)) {
            adminScreenDragOffset = currentDisplayWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                previousScreen = .root
                currentScreen = .root
                adminScreenDragOffset = 0
                if sourceScreen == .roleEditor {
                    viewModel.selectedUser = nil
                }
            }
            withAnimation(.easeInOut(duration: 0.18)) {
                syncToolbarNavigationState(.root)
            }
        }
    }

    private func syncToolbarNavigationState(_ screen: AdminScreen? = nil) {
        let current = screen ?? currentScreen
        toolbarTitle?.wrappedValue = toolbarTitle(for: current)
        toolbarShowsBackButton?.wrappedValue = true
        toolbarShowsRefreshButton?.wrappedValue = current != .roleEditor
    }

    private func toolbarTitle(for screen: AdminScreen) -> String {
        switch screen {
        case .root:
            return "Админка"
        case .roleEditor:
            return "Роли"
        case .moderation:
            return "Модерация ролей"
        case .settings:
            return "Дебаг"
        case .notices:
            return "Уведомления"
        }
    }

    private var interactiveAdminBackGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard currentScreen != .root else { return }
                adminScreenDragOffset = max(0, value.translation.width)
            }
            .onEnded { value in
                guard currentScreen != .root else { return }
                let predicted = value.predictedEndTranslation.width
                let shouldClose = adminScreenDragOffset > currentDisplayWidth * backSwipeConfig.triggerRatio
                    || predicted > currentDisplayWidth * backSwipeConfig.predictedTriggerRatio

                if shouldClose {
                    triggerAdminBackNavigation()
                } else {
                    withAnimation(.interactiveSpring(response: backSwipeConfig.cancelResponse,
                                                     dampingFraction: backSwipeConfig.cancelDamping)) {
                        adminScreenDragOffset = 0
                    }
                }
            }
    }

    private var currentDisplayWidth: CGFloat {
#if os(iOS)
        return UIScreen.main.bounds.width
#elseif os(macOS)
        return NSScreen.main?.frame.width ?? 800
#else
        return 800
#endif
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Поиск по имени, email или роли", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
        }
        .mympsuDefaultSurface(cornerRadius: 14, padding: 12)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var statusArea: some View {
        if viewModel.isLoading && viewModel.users.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                Text("Загружаем пользователей")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
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
    private var usersContent: some View {
        if !viewModel.isLoading, viewModel.filteredUsers.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredUsers) { user in
                        Button {
                            viewModel.selectedUser = user
                            openAdminScreen(.roleEditor)
                        } label: {
                            AdminUserRowView(user: user)
                        }
                        .buttonStyle(.plain)
                        .mympsuInteractiveButtonStyle()
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.accentColor)
            Text(viewModel.searchText.mympsuTrimmed.isEmpty ? "Пользователей пока нет." : "Ничего не найдено.")
                .font(.headline)
            Text("Попробуйте обновить список или изменить поиск.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .mympsuAdaptiveGlassCard(cornerRadius: 16)
        .padding(.horizontal, 4)
    }
}

private struct AdminUserRowView: View {
    let user: AdminUserDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: user.isAdmin ? "crown.fill" : "person.crop.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(user.isAdmin ? Color(red: 0.95, green: 0.68, blue: 0.28) : .accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        UserBadgeInlineStackView(badges: user.badges)
                    }
                    Text(user.email ?? "email не указан")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(user.tier)
                        .font(.caption.weight(.semibold))
                    Text(user.remainingTodayText)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }

            AdminRoleChipStack(roles: user.sortedRoles)

            if !user.pendingRoleRequests.isEmpty {
                AdminPendingRequestChipStack(requests: user.pendingRoleRequests)
            }
        }
        .mympsuDefaultSurface(cornerRadius: 16, padding: 12)
    }
}

private struct AdminRoleRequestCard: View {
    let request: RoleRequestDTO
    let isProcessing: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                AdminRoleChip(role: UserRole(type: request.requestedRole))
                Spacer(minLength: 0)
                Text(request.createdAt)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(request.userEmail ?? request.userName ?? "Пользователь")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if let message = request.message, !message.mympsuTrimmed.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button("Одобрить", action: onApprove)
                    .disabled(isProcessing)
                Button("Отклонить", action: onReject)
                    .foregroundColor(.red)
                    .disabled(isProcessing)
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.75)
                }
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(10)
        .mympsuAdaptiveGlassCard(cornerRadius: 14)
    }
}

private struct AdminPendingRequestChipStack: View {
    let requests: [RoleRequestDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(requests.filter { $0.status.lowercased() == "pending" }) { request in
                Label("Запросил \(request.requestedRole)", systemImage: "clock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.10))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct UserRoleEditorView: View {
    @ObservedObject var viewModel: AdminUsersViewModel
    let user: AdminUserDTO
    let onBack: () -> Void
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @State private var rolePendingAdminConfirmation: String?
    @State private var badgeNote = ""

    private let manageableRoles = UserRole.manageableTypes.map { UserRole(type: $0) }

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    private var currentUser: AdminUserDTO {
        viewModel.users.first { $0.id == user.id } ?? user
    }

    private var badgesForAdministration: [UserBadge] {
        let assignedByCode = Dictionary(currentUser.badges.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
        let availableByCode = Dictionary(viewModel.availableBadges.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
        let allCodes = Set(assignedByCode.keys).union(availableByCode.keys)
        return UserBadge.sortedForAdministration(allCodes.compactMap { code in
            availableByCode[code] ?? assignedByCode[code]
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Роли") {
                onBack()
            }
#endif

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(currentUser.displayName)
                                .font(.headline)
                            UserBadgeInlineStackView(badges: currentUser.badges, iconSize: 20)
                        }
                        Text(currentUser.email ?? currentUser.id)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .mympsuTextSelectionEnabled()
                    }
                    .padding(.horizontal, 4)

                    MyMPSUSettingsCard {
                        HStack {
                            Label("Тариф", systemImage: "sparkles")
                            Spacer()
                            Text(currentUser.tier)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Label("Осталось сегодня", systemImage: "message.badge")
                            Spacer()
                            Text(currentUser.remainingTodayText)
                                .foregroundColor(.secondary)
                        }
                    }

                    AdminUserSessionsSection(userId: currentUser.id)

                    MyMPSUSettingsCard {
                        ForEach(manageableRoles) { role in
                            Toggle(isOn: binding(for: role.type)) {
                                HStack(spacing: 8) {
                                    AdminRoleChip(role: role)
                                    if viewModel.processingRole == role.type {
                                        ProgressView()
                                            .scaleEffect(0.75)
                                    }
                                }
                            }
                            .disabled(viewModel.processingRole != nil)
                        }
                    }

                    adminBadgesSection

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                    }

                    if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.bottom, 12)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .alert(isPresented: adminConfirmationBinding) {
            Alert(
                title: Text("Снять роль admin у этого пользователя?"),
                message: Text("Если backend запретит действие, роль останется без изменений."),
                primaryButton: .destructive(Text("Снять")) {
                    let role = rolePendingAdminConfirmation ?? "admin"
                    rolePendingAdminConfirmation = nil
                    Task {
                        await viewModel.setRole(role, enabled: false, for: currentUser)
                    }
                },
                secondaryButton: .cancel(Text("Отмена")) {
                    rolePendingAdminConfirmation = nil
                }
            )
        }
    }

    private var adminBadgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Значки", systemImage: "seal.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if viewModel.isLoadingBadges {
                    ProgressView()
                        .scaleEffect(0.75)
                }
            }
            .padding(.horizontal, 4)

            TextField("Заметка для выдачи", text: $badgeNote)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .mympsuDefaultSurface(cornerRadius: 12, padding: 0)
                .disabled(viewModel.processingBadgeCode != nil)
                .accessibilityLabel("Заметка для выдачи значка")

            MyMPSUSettingsCard {
                if badgesForAdministration.isEmpty {
                    Text(viewModel.isLoadingBadges ? "Загружаем значки" : "Значки не найдены")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(badgesForAdministration) { badge in
                        Toggle(isOn: badgeBinding(for: badge)) {
                            AdminBadgeToggleLabel(
                                badge: badge,
                                isProcessing: viewModel.processingBadgeCode == badge.code
                            )
                        }
                        .disabled(viewModel.processingBadgeCode != nil)
                    }
                }
            }
        }
    }

    private func binding(for role: String) -> Binding<Bool> {
        Binding(
            get: { currentUser.roleTypes.contains(role) },
            set: { isEnabled in
                if role == "admin", !isEnabled {
                    rolePendingAdminConfirmation = role
                } else {
                    Task {
                        await viewModel.setRole(role, enabled: isEnabled, for: currentUser)
                    }
                }
            }
        )
    }

    private var adminConfirmationBinding: Binding<Bool> {
        Binding(
            get: { rolePendingAdminConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    rolePendingAdminConfirmation = nil
                }
            }
        )
    }

    private func badgeBinding(for badge: UserBadge) -> Binding<Bool> {
        Binding(
            get: { currentUser.badges.contains { $0.code == badge.code } },
            set: { isEnabled in
                Task {
                    await viewModel.setBadge(badge, enabled: isEnabled, note: badgeNote, for: currentUser)
                }
            }
        )
    }
}

private struct AdminBadgeToggleLabel: View {
    let badge: UserBadge
    let isProcessing: Bool

    var body: some View {
        HStack(spacing: 9) {
            if badge.hasKnownAsset {
                UserBadgeIconView(badge: badge, size: 24)
            } else {
                Image(systemName: "seal.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title.mympsuTrimmed.isEmpty ? badge.code : badge.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("\(badge.rarity.localizedTitle) • \(badge.code)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if isProcessing {
                ProgressView()
                    .scaleEffect(0.75)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.title), \(badge.rarity.localizedTitle), код \(badge.code)")
    }
}

private struct AdminRoleChipStack: View {
    let roles: [UserRole]

    var body: some View {
        if roles.isEmpty {
            Text("Ролей нет")
                .font(.caption)
                .foregroundColor(.secondary)
        } else if #available(iOS 16.0, macOS 13.0, *) {
            AdminRoleFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(roles) { role in
                    AdminRoleChip(role: role)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(roles) { role in
                    AdminRoleChip(role: role)
                }
            }
        }
    }
}

private struct AdminRoleChip: View {
    let role: UserRole

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(tint)
            Text(role.title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 0.8))
    }

    private var symbolName: String {
        switch role.type {
        case "admin":
            return "crown.fill"
        case "moderator":
            return "shield.lefthalf.filled"
        case "group_leader":
            return "star.fill"
        case "tester":
            return "testtube.2"
        case "premium":
            return "sparkles"
        case "plus":
            return "plus.circle.fill"
        case "free":
            return "circle"
        case "student":
            return "graduationcap.fill"
        default:
            return "tag.fill"
        }
    }

    private var tint: Color {
        switch role.type {
        case "admin":
            return Color(red: 0.95, green: 0.68, blue: 0.28)
        case "moderator":
            return Color(red: 0.63, green: 0.56, blue: 0.86)
        case "group_leader":
            return Color(red: 0.38, green: 0.66, blue: 0.95)
        case "tester":
            return Color(red: 0.42, green: 0.72, blue: 0.96)
        case "premium":
            return Color(red: 0.88, green: 0.55, blue: 0.93)
        case "plus":
            return Color(red: 0.34, green: 0.72, blue: 0.76)
        case "free":
            return Color.secondary
        case "student":
            return Color(red: 0.44, green: 0.72, blue: 0.50)
        default:
            return Color.secondary
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
private struct AdminRoleFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + verticalSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = makeRows(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private func makeRows(proposal: ProposedViewSize, subviews: Subviews) -> [AdminRoleFlowRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [AdminRoleFlowRow] = []
        var currentItems: [AdminRoleFlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + horizontalSpacing + size.width

            if nextWidth > maxWidth, !currentItems.isEmpty {
                rows.append(AdminRoleFlowRow(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = [AdminRoleFlowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(AdminRoleFlowItem(index: index, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(AdminRoleFlowRow(items: currentItems, width: currentWidth, height: currentHeight))
        }

        return rows
    }
}

private struct AdminRoleFlowRow {
    let items: [AdminRoleFlowItem]
    let width: CGFloat
    let height: CGFloat
}

private struct AdminRoleFlowItem {
    let index: Int
    let size: CGSize
}
