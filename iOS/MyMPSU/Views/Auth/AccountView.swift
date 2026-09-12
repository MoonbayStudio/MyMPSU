import SwiftUI
import AuthenticationServices
#if os(iOS) || os(macOS)
import GoogleSignIn
#endif
#if os(macOS)
import Cocoa
#endif

struct AccountView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @AppStorage("appleUserID") private var appleUserID = ""
    @AppStorage("selectedGroupId") private var selectedGroupId = ""
    @AppStorage("selectedGroupName") private var selectedGroupName = ""
    @StateObject private var authSession = AuthSessionManager.shared
#if os(iOS)
    @StateObject private var appLockManager = AppLockManager.shared
#endif
    @State private var internalShowPremiumScreen = false
    private let externalShowPremiumScreen: Binding<Bool>?
    @State private var signInErrorMessage: String?
    @State private var profileErrorMessage: String?
    @State private var showsProfileSaveError = false
    @State private var isSigningIn = false
    @State private var isSavingProfile = false
    @State private var testerRoleRequests: [RoleRequestDTO] = []
    @State private var isLoadingTesterRoleRequests = false
    @State private var isProcessingTesterRoleRequest = false
    @State private var testerRoleRequestMessage: String?
    @State private var testerRoleRequestErrorMessage: String?
    @State private var isResendingContactEmail = false
    @State private var contactEmailMessage: String?
    @State private var contactEmailErrorMessage: String?
    @State private var isLinkingGoogleProvider = false
    @State private var providerLinkMessage: String?
    @State private var providerLinkErrorMessage: String?
#if os(iOS)
    @State private var showsAppLockSetup = false
#endif
    @State private var accountScreen: AccountScreen = .root
    @State private var previousAccountScreen: AccountScreen = .root
    @State private var accountScreenDragOffset: CGFloat = 0
    private let externalNestedScreenPresented: Binding<Bool>?
    private let externalToolbarTitle: Binding<String>?
    private let externalToolbarShowsBackButton: Binding<Bool>?
    private let externalToolbarBackRequest: Binding<Int>?
    private let externalToolbarShowsRefreshButton: Binding<Bool>?
    private let externalToolbarRefreshRequest: Binding<Int>?

    private enum AccountScreen: Equatable {
        case root
        case premium
        case profileEditor
        case roleRequest
        case myRoleRequests
        case adminUsers
        case security
        case devices
        case myGroup
        case passwordSetup
        case passwordChange
        case emailChange
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

    init(scheduleViewModel: ScheduleViewModel,
         showPremiumScreen: Binding<Bool>? = nil,
         nestedScreenPresented: Binding<Bool>? = nil,
         toolbarTitle: Binding<String>? = nil,
         toolbarShowsBackButton: Binding<Bool>? = nil,
         toolbarBackRequest: Binding<Int>? = nil,
         toolbarShowsRefreshButton: Binding<Bool>? = nil,
         toolbarRefreshRequest: Binding<Int>? = nil) {
        self.scheduleViewModel = scheduleViewModel
        self.externalShowPremiumScreen = showPremiumScreen
        self.externalNestedScreenPresented = nestedScreenPresented
        self.externalToolbarTitle = toolbarTitle
        self.externalToolbarShowsBackButton = toolbarShowsBackButton
        self.externalToolbarBackRequest = toolbarBackRequest
        self.externalToolbarShowsRefreshButton = toolbarShowsRefreshButton
        self.externalToolbarRefreshRequest = toolbarRefreshRequest
    }

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    private var premiumScreenBinding: Binding<Bool> {
        Binding(
            get: { externalShowPremiumScreen?.wrappedValue ?? internalShowPremiumScreen },
            set: { newValue in
                if let externalShowPremiumScreen {
                    externalShowPremiumScreen.wrappedValue = newValue
                } else {
                    internalShowPremiumScreen = newValue
                }
            }
        )
    }

    private var isPremiumScreenPresented: Bool {
        premiumScreenBinding.wrappedValue
    }

    private var isSignedIn: Bool {
        authSession.isAuthenticated
    }

    private var isNestedScreenPresented: Bool {
        accountScreen != .root
    }

    private var accountBottomPadding: CGFloat {
#if os(iOS)
        return 104
#else
        return 16
#endif
    }

    private var displayName: String {
        authSession.currentUser?.displayNameForProfile ?? "Пользователь"
    }

    private var defaultGroupRole: UserRole? {
        guard isSignedIn else { return nil }
        let groupTitle = selectedGroupName.mympsuTrimmed
        let groupId = selectedGroupId.mympsuTrimmed
        if !groupTitle.isEmpty {
            return UserRole(type: "group", title: groupTitle)
        }
        if !groupId.isEmpty {
            return UserRole(type: "group", title: "Группа \(groupId)")
        }
        return nil
    }

    private var accountHeaderBadges: [UserRole] {
        rolesWithDefaultGroup(authSession.currentUser?.sortedRoles ?? [])
    }

    private func rolesWithDefaultGroup(_ roles: [UserRole]) -> [UserRole] {
        guard let defaultGroupRole else { return roles }
        var result = roles.filter { $0.type != defaultGroupRole.type }
        result.append(defaultGroupRole)
        return result.sorted { lhs, rhs in
            let lhsPriority = UserRole.roleOrder[lhs.type] ?? 999
            let rhsPriority = UserRole.roleOrder[rhs.type] ?? 999
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    var body: some View {
        ZStack {
            if accountScreenDragOffset > 0 {
                accountBackDestinationView
            }

            accountCurrentScreenView
                .offset(x: max(0, accountScreenDragOffset))
                .transition(accountScreenTransition)
        }
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .overlay(
            Group {
                if accountScreen != .root && accountScreen != .adminUsers {
                    Color.clear
                        .frame(width: backSwipeConfig.edgeWidth)
                        .contentShape(Rectangle())
                        .highPriorityGesture(interactiveAccountBackGesture)
                }
            },
            alignment: .leading
        )
        .animation(.easeInOut(duration: 0.18), value: accountScreen)
#if os(iOS)
        .sheet(isPresented: $showsAppLockSetup) {
            AppLockSetupView(lockManager: appLockManager) {
                showsAppLockSetup = false
            }
        }
#endif
        .onAppear {
            syncToolbarNavigationState()
            if isPremiumScreenPresented, accountScreen == .root {
                openAccountScreen(.premium)
            }
        }
        .onChange(of: accountScreen) { _ in
            syncToolbarNavigationState()
        }
        .onChange(of: externalToolbarBackRequest?.wrappedValue ?? 0) { _ in
            guard externalToolbarBackRequest != nil else { return }
            guard accountScreen != .adminUsers else { return }
            triggerAccountBackNavigation()
        }
        .onChange(of: isPremiumScreenPresented) { isPresented in
            if isPresented, accountScreen == .root {
                openAccountScreen(.premium)
            } else if !isPresented, accountScreen == .premium {
                resetAccountScreen()
            }
        }
    }

    @ViewBuilder
    private var accountCurrentScreenView: some View {
        switch accountScreen {
        case .root:
            content
        case .premium:
            PremiumView(onBack: triggerAccountBackNavigation)
        case .profileEditor:
            profileEditor
        case .roleRequest:
            RoleRequestView(onBack: triggerAccountBackNavigation)
        case .myRoleRequests:
            MyRoleRequestsView(onBack: triggerAccountBackNavigation)
        case .adminUsers:
            AdminUsersView(onBack: triggerAccountBackNavigation,
                           toolbarTitle: externalToolbarTitle,
                           toolbarShowsBackButton: externalToolbarShowsBackButton,
                           toolbarBackRequest: externalToolbarBackRequest,
                           toolbarShowsRefreshButton: externalToolbarShowsRefreshButton,
                           toolbarRefreshRequest: externalToolbarRefreshRequest,
                           scheduleViewModel: scheduleViewModel)
        case .security:
            securityScreen
        case .devices:
            AccountSessionsView(activeTheme: activeTheme, onBack: triggerAccountBackNavigation)
        case .myGroup:
            myGroupScreen
        case .passwordSetup:
            passwordEditor(mode: .setup)
        case .passwordChange:
            passwordEditor(mode: .change)
        case .emailChange:
            emailEditor
        }
    }

    @ViewBuilder
    private var accountBackDestinationView: some View {
        accountView(for: targetAccountBackScreen)
    }

    @ViewBuilder
    private func accountView(for screen: AccountScreen) -> some View {
        switch screen {
        case .root:
            content
        case .premium:
            PremiumView(onBack: triggerAccountBackNavigation)
        case .profileEditor:
            profileEditor
        case .roleRequest:
            RoleRequestView(onBack: triggerAccountBackNavigation)
        case .myRoleRequests:
            MyRoleRequestsView(onBack: triggerAccountBackNavigation)
        case .adminUsers:
            AdminUsersView(onBack: triggerAccountBackNavigation,
                           toolbarTitle: externalToolbarTitle,
                           toolbarShowsBackButton: externalToolbarShowsBackButton,
                           toolbarBackRequest: externalToolbarBackRequest,
                           toolbarShowsRefreshButton: externalToolbarShowsRefreshButton,
                           toolbarRefreshRequest: externalToolbarRefreshRequest,
                           scheduleViewModel: scheduleViewModel)
        case .security:
            securityScreen
        case .devices:
            AccountSessionsView(activeTheme: activeTheme, onBack: triggerAccountBackNavigation)
        case .myGroup:
            myGroupScreen
        case .passwordSetup:
            passwordEditor(mode: .setup)
        case .passwordChange:
            passwordEditor(mode: .change)
        case .emailChange:
            emailEditor
        }
    }

    private var targetAccountBackScreen: AccountScreen {
        switch accountScreen {
        case .passwordSetup, .passwordChange, .emailChange, .devices:
            return .security
        case .roleRequest, .myRoleRequests:
            return previousAccountScreen == .profileEditor ? .profileEditor : .root
        default:
            return .root
        }
    }

    private var accountScreenTransition: AnyTransition {
        let oldLevel = accountScreenLevel(previousAccountScreen)
        let newLevel = accountScreenLevel(accountScreen)

        if newLevel < oldLevel {
            return .asymmetric(insertion: .identity, removal: .move(edge: .trailing))
        } else {
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .opacity
            )
        }
    }

    private func accountScreenLevel(_ screen: AccountScreen) -> Int {
        switch screen {
        case .root:
            return 0
        case .premium, .profileEditor, .roleRequest, .myRoleRequests, .adminUsers, .security, .myGroup:
            return 1
        case .passwordSetup, .passwordChange, .emailChange, .devices:
            return 2
        }
    }

    private func openAccountScreen(_ screen: AccountScreen) {
        previousAccountScreen = accountScreen
        accountScreenDragOffset = 0
        withAnimation(.easeInOut(duration: 0.18)) {
            accountScreen = screen
            syncToolbarNavigationState(screen)
        }
        if screen == .premium {
            premiumScreenBinding.wrappedValue = true
        }
        syncNestedScreenState()
    }

    private func resetAccountScreen() {
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            previousAccountScreen = .root
            accountScreen = .root
            accountScreenDragOffset = 0
            premiumScreenBinding.wrappedValue = false
        }
        syncNestedScreenState()
        syncToolbarNavigationState(.root)
    }

    private func triggerAccountBackNavigation() {
        guard accountScreen != .root else { return }
        let targetScreen = targetAccountBackScreen
        let sourceScreen = accountScreen

        withAnimation(.interactiveSpring(response: backSwipeConfig.completeResponse,
                                         dampingFraction: backSwipeConfig.completeDamping)) {
            accountScreenDragOffset = currentDisplayWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                previousAccountScreen = targetScreen
                accountScreen = targetScreen
                accountScreenDragOffset = 0
                if sourceScreen == .premium {
                    premiumScreenBinding.wrappedValue = false
                }
            }
            profileErrorMessage = nil
            syncNestedScreenState()
            withAnimation(.easeInOut(duration: 0.18)) {
                syncToolbarNavigationState(targetScreen)
            }
        }
    }

    private func syncToolbarNavigationState(_ screen: AccountScreen? = nil) {
        let currentScreen = screen ?? accountScreen
        externalToolbarTitle?.wrappedValue = toolbarTitle(for: currentScreen)
        externalToolbarShowsBackButton?.wrappedValue = currentScreen != .root
        if currentScreen != .adminUsers {
            externalToolbarShowsRefreshButton?.wrappedValue = false
        }
    }

    private func toolbarTitle(for screen: AccountScreen) -> String {
        switch screen {
        case .root:
            return "Аккаунт"
        case .premium:
            return "Мой МПГУ Плюс/Премиум"
        case .profileEditor:
            return "Профиль"
        case .roleRequest:
            return "Запрос роли"
        case .myRoleRequests:
            return "Мои заявки"
        case .adminUsers:
            return "Админка"
        case .security:
            return "Безопасность"
        case .devices:
            return "Устройства"
        case .myGroup:
            return "Моя группа"
        case .passwordSetup:
            return "Пароль"
        case .passwordChange:
            return "Сменить пароль"
        case .emailChange:
            return "Сменить почту"
        }
    }

    private var interactiveAccountBackGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard accountScreen != .root else { return }
                accountScreenDragOffset = max(0, value.translation.width)
            }
            .onEnded { value in
                guard accountScreen != .root else { return }
                let predicted = value.predictedEndTranslation.width
                let shouldClose = accountScreenDragOffset > currentDisplayWidth * backSwipeConfig.triggerRatio
                    || predicted > currentDisplayWidth * backSwipeConfig.predictedTriggerRatio

                if shouldClose {
                    triggerAccountBackNavigation()
                } else {
                    withAnimation(.interactiveSpring(response: backSwipeConfig.cancelResponse,
                                                     dampingFraction: backSwipeConfig.cancelDamping)) {
                        accountScreenDragOffset = 0
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

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            ThemedChrome(shape: activeTheme.headerShape) {
                Text("Аккаунт")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .frame(height: 44)
                    .background(Color.clear)
            }
#endif

            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(isSignedIn ? displayName : "Войдите в аккаунт")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if isSignedIn {
                            UserBadgeInlineStackView(badges: authSession.currentUser?.badges ?? [])
                        }
                    }
                    if !accountHeaderBadges.isEmpty {
                        RoleBadgeStackView(roles: accountHeaderBadges)
                    }
                    if !isSignedIn {
                        Text("Войдите через Apple или Google, чтобы подключить аккаунт к серверу.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if isSignedIn {
                    Button {
                        profileErrorMessage = nil
                        openAccountScreen(.profileEditor)
                    } label: {
                        ThemedChrome(shape: activeTheme.headerShape) {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color.clear)
                                .contentShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSavingProfile)
                    .accessibilityLabel("Редактировать профиль")
                }
            }
            .mympsuDefaultSurface(cornerRadius: 16, padding: 10)
            .padding(.horizontal, 4)

            if let profileErrorMessage, isSignedIn {
                Text(profileErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }

            if isSavingProfile {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Сохраняем профиль")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }

            if !isSignedIn {
                authSection
            }

            if canViewAdminPanel {
                adminSection
            }

            if isSignedIn {
                securityEntrySection
            }

            if isSignedIn {
                myGroupEntrySection
            }

            if canShowTesterRoleRequestPlaceholder {
                testerRoleRequestSection
            }

            if isSignedIn {
                Button {
                    openAccountScreen(.premium)
                } label: {
                    HStack {
                        Label("Мой МПГУ Плюс/Премиум", systemImage: "crown.fill")
                        Spacer()
                    }
                    .mympsuDefaultSurface()
                }
                .mympsuInteractiveButtonStyle()
                .padding(.horizontal, 4)
            }

            if isSignedIn {
                authSection
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, accountBottomPadding)
        .alert(isPresented: $showsProfileSaveError) {
            Alert(
                title: Text("Не удалось сохранить профиль"),
                message: Text(profileErrorMessage ?? "Попробуйте ещё раз."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            validateAppleCredentialIfNeeded()
            refreshBackendUserIfNeeded()
            loadTesterRoleRequestsIfNeeded()
            syncNestedScreenState()
        }
        .onDisappear {
            if !isNestedScreenPresented {
                externalNestedScreenPresented?.wrappedValue = false
            }
        }
        .onChange(of: isNestedScreenPresented) { _ in
            syncNestedScreenState()
        }
    }

    private func syncNestedScreenState() {
        externalNestedScreenPresented?.wrappedValue = isNestedScreenPresented
    }

    private var canViewAdminPanel: Bool {
        authSession.currentUser?.canViewAdminPanel == true
    }

    private var canShowTesterRoleRequestPlaceholder: Bool {
        guard let user = authSession.currentUser else { return false }
        return !user.isAdmin && !user.isTester && !hasApprovedTesterRoleRequest
    }

    private var pendingTesterRoleRequest: RoleRequestDTO? {
        testerRoleRequests.first { request in
            request.requestedRole == "tester" && request.status.lowercased() == "pending"
        }
    }

    private var hasApprovedTesterRoleRequest: Bool {
        testerRoleRequests.contains { request in
            request.requestedRole == "tester" && request.status.lowercased() == "approved"
        }
    }

    private var profileEditor: some View {
        ProfileEditorView(
            activeTheme: activeTheme,
            initialName: authSession.currentUser?.editableProfileName ?? "",
            accountDisplayName: authSession.currentUser?.displayNameForProfile ?? "Пользователь",
            email: authSession.currentUser?.accountEmail,
            badges: authSession.currentUser?.badges ?? [],
            roles: authSession.currentUser?.sortedRoles ?? [],
            defaultGroupRole: defaultGroupRole,
            initialGroupId: selectedGroupId,
            initialGroupName: selectedGroupName,
            isSaving: isSavingProfile,
            errorMessage: profileErrorMessage,
            onBack: {
                triggerAccountBackNavigation()
                profileErrorMessage = nil
            },
            onOpenRoleRequest: {
                openAccountScreen(.roleRequest)
            },
            onOpenMyRoleRequests: {
                openAccountScreen(.myRoleRequests)
            },
            onSave: { name, groupId, groupName in
                saveProfile(name: name, groupIdString: groupId, groupName: groupName)
            }
        )
    }

    private func passwordEditor(mode: PasswordEditorMode) -> some View {
        PasswordSetupView(
            activeTheme: activeTheme,
            mode: mode,
            onBack: {
                triggerAccountBackNavigation()
            },
            onSuccess: { user in
                authSession.updateCurrentUser(user)
            }
        )
    }

    private var emailEditor: some View {
        EmailChangeView(
            activeTheme: activeTheme,
            currentEmail: authSession.currentUser?.accountEmail,
            pendingEmail: authSession.currentUser?.pendingAccountEmail,
            onBack: {
                triggerAccountBackNavigation()
            },
            onSuccess: { user in
                authSession.updateCurrentUser(user)
            }
        )
    }

    private var securityScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Безопасность") {
                triggerAccountBackNavigation()
            }
#endif

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    accountEmailSection
                    accountConnectionsSection
                    passwordSecuritySection
                    accountSessionsEntrySection

                    Color.clear.frame(height: 32)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
    }

    private var myGroupScreen: some View {
        MyGroupMembersScreen(
            activeTheme: activeTheme,
            groupId: selectedGroupId,
            groupName: selectedGroupName,
            onBack: triggerAccountBackNavigation
        )
    }

    private var securityEntrySection: some View {
        Button {
            openAccountScreen(.security)
        } label: {
            HStack {
                Label("Безопасность", systemImage: "lock.shield.fill")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .mympsuDefaultSurface()
        }
        .mympsuInteractiveButtonStyle()
        .padding(.horizontal, 4)
    }

    private var myGroupEntrySection: some View {
        Button {
            openAccountScreen(.myGroup)
        } label: {
            HStack {
                Label("Моя группа", systemImage: "person.3.fill")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .mympsuDefaultSurface()
        }
        .mympsuInteractiveButtonStyle()
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var accountEmailSection: some View {
        if let user = authSession.currentUser {
            MyMPSUSettingsCard {
                Label("Почта аккаунта", systemImage: "envelope.badge.fill")
                    .font(.subheadline.weight(.semibold))

                accountEmailContent(for: user)
            }
            .padding(.horizontal, 4)
        }
    }

    private func accountEmailContent(for user: AppleUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: user.accountEmailIsVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.accountEmailIsVerified ? "Почта подтверждена" : "Почта не подтверждена")
                        .font(.subheadline.weight(.semibold))
                    Text(user.accountEmail ?? "Не указана")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .mympsuTextSelectionEnabled()
                }
                Spacer(minLength: 0)
            }

            if let pendingEmail = user.pendingAccountEmail {
                Label("Ожидает подтверждения: \(pendingEmail)", systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .mympsuTextSelectionEnabled()
            }

            if !user.accountEmailIsVerified {
                Button {
                    resendContactEmailVerification()
                } label: {
                    HStack {
                        Label("Отправить письмо подтверждения", systemImage: "paperplane.fill")
                        Spacer(minLength: 0)
                        if isResendingContactEmail {
                            ProgressView()
                        }
                    }
                    .mympsuDefaultSurface()
                }
                .disabled(isResendingContactEmail)
                .mympsuInteractiveButtonStyle()
            }

            if let contactEmailMessage {
                Text(contactEmailMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let contactEmailErrorMessage {
                Text(contactEmailErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button {
                openAccountScreen(.emailChange)
            } label: {
                HStack {
                    Label("Изменить почту", systemImage: "envelope.arrow.triangle.branch")
                    Spacer(minLength: 0)
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
        }
    }

    @ViewBuilder
    private var accountConnectionsSection: some View {
        if let user = authSession.currentUser {
            MyMPSUSettingsCard {
                Label("Привязки", systemImage: "link.circle.fill")
                    .font(.subheadline.weight(.semibold))

                if user.hasAppleProvider {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                        Text("Apple ID привязан")
                            .font(.caption.weight(.semibold))
                        Spacer(minLength: 0)
                    }
                    .mympsuDefaultSurface()
                } else {
                    HStack {
                        Label("Apple ID не привязан", systemImage: "apple.logo")
                            .foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }
                    .mympsuDefaultSurface()
                }

#if os(iOS)
                if user.hasGoogleProvider {
                    HStack(spacing: 10) {
                        googleBrandMark
                        Text("Google привязан")
                            .font(.caption.weight(.semibold))
                        Spacer(minLength: 0)
                    }
                    .mympsuDefaultSurface()
                } else {
                    googleAuthButton(title: "Привязать Google", isLoading: isLinkingGoogleProvider) {
                        handleGoogleProviderLink()
                    }
                    .disabled(isLinkingGoogleProvider || isSigningIn)
                }

                if let providerLinkMessage {
                    Text(providerLinkMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let providerLinkErrorMessage {
                    Text(providerLinkErrorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
#endif
            }
            .padding(.horizontal, 4)
        }
    }

    private var accountSessionsEntrySection: some View {
        MyMPSUSettingsCard {
            Button {
                openAccountScreen(.devices)
            } label: {
                HStack {
                    Label("Устройства и активные сеансы", systemImage: "iphone.and.arrow.forward")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
        }
        .padding(.horizontal, 4)
    }

    private var passwordSecuritySection: some View {
        MyMPSUSettingsCard {
            Label("Пароли и вход", systemImage: "key.fill")
                .font(.subheadline.weight(.semibold))

            if authSession.currentUser?.hasPassword == true {
                Button {
                    openAccountScreen(.passwordChange)
                } label: {
                    HStack {
                        Label("Изменить пароль", systemImage: "key.fill")
                        Spacer(minLength: 0)
                    }
                    .mympsuDefaultSurface()
                }
                .mympsuInteractiveButtonStyle()
            } else {
                Text("Создайте пароль, чтобы входить по email и паролю.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    openAccountScreen(.passwordSetup)
                } label: {
                    HStack {
                        Label("Создать пароль", systemImage: "key.fill")
                        Spacer(minLength: 0)
                    }
                    .mympsuDefaultSurface()
                }
                .mympsuInteractiveButtonStyle()
            }

#if os(iOS)
            Toggle(isOn: appLockEnabledBinding) {
                Label("Код приложения", systemImage: "lock.fill")
            }

            if appLockManager.isEnabled {
                Button {
                    showsAppLockSetup = true
                } label: {
                    HStack {
                        Label("Изменить код", systemImage: "number.square.fill")
                        Spacer(minLength: 0)
                    }
                    .mympsuDefaultSurface(cornerRadius: 22, padding: 12)
                }
                .mympsuInteractiveButtonStyle()

                Toggle(isOn: appLockBiometryBinding) {
                    Label(appLockManager.biometryTitle, systemImage: appLockManager.biometryTitle == "Face ID" ? "faceid" : "touchid")
                }
                .disabled(!appLockManager.canUseBiometry)
            }
#endif
        }
        .padding(.horizontal, 4)
    }

#if os(iOS)
    private var appLockEnabledBinding: Binding<Bool> {
        Binding(
            get: { appLockManager.isEnabled },
            set: { isEnabled in
                if isEnabled {
                    showsAppLockSetup = true
                } else {
                    appLockManager.disable()
                }
            }
        )
    }

    private var appLockBiometryBinding: Binding<Bool> {
        Binding(
            get: { appLockManager.isBiometryEnabled },
            set: { appLockManager.setBiometryEnabled($0) }
        )
    }
#endif

    @ViewBuilder
    private var adminSection: some View {
        Button {
            openAccountScreen(.adminUsers)
        } label: {
            HStack {
                Label("Админка", systemImage: "person.3.sequence.fill")
                Spacer()
            }
            .mympsuDefaultSurface()
        }
        .mympsuInteractiveButtonStyle()
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var testerRoleRequestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingTesterRoleRequests {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Проверяем заявки")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            } else if let pendingTesterRoleRequest {
                HStack(spacing: 10) {
                    Label("Заявка на тестера отправлена", systemImage: "clock.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Button("Отменить") {
                        cancelTesterRoleRequest(pendingTesterRoleRequest)
                    }
                    .disabled(isProcessingTesterRoleRequest)
                }
                .mympsuDefaultSurface()
            } else {
                Button {
                    createTesterRoleRequest()
                } label: {
                    HStack {
                        Label("Запросить роль тестера", systemImage: "testtube.2")
                        Spacer()
                        if isProcessingTesterRoleRequest {
                            ProgressView()
                        }
                    }
                    .mympsuDefaultSurface()
                }
                .disabled(isProcessingTesterRoleRequest)
                .mympsuInteractiveButtonStyle()
            }

            if let testerRoleRequestMessage {
                Text(testerRoleRequestMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let testerRoleRequestErrorMessage {
                Text(testerRoleRequestErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 4)
    }

    private func loadTesterRoleRequestsIfNeeded() {
        guard isSignedIn, canShowTesterRoleRequestPlaceholder, testerRoleRequests.isEmpty else { return }
        loadTesterRoleRequests()
    }

    private func loadTesterRoleRequests() {
        guard !isLoadingTesterRoleRequests else { return }
        isLoadingTesterRoleRequests = true
        testerRoleRequestErrorMessage = nil
        Task {
            do {
                testerRoleRequests = try await APIService.shared.fetchMyRoleRequests()
            } catch {
                print("[AccountView] tester role requests load failed: \(error)")
                testerRoleRequestErrorMessage = "Не удалось проверить заявки."
            }
            isLoadingTesterRoleRequests = false
        }
    }

    private func createTesterRoleRequest() {
        guard !isProcessingTesterRoleRequest else { return }
        isProcessingTesterRoleRequest = true
        testerRoleRequestMessage = nil
        testerRoleRequestErrorMessage = nil
        Task {
            do {
                let request = try await APIService.shared.createRoleRequest(
                    role: "tester",
                    message: "Хочу тестировать AI-функции MyMPSU"
                )
                testerRoleRequests.insert(request, at: 0)
                testerRoleRequestMessage = "Заявка отправлена."
            } catch {
                print("[AccountView] tester role request create failed: \(error)")
                testerRoleRequestErrorMessage = testerRoleRequestError(for: error)
            }
            isProcessingTesterRoleRequest = false
        }
    }

    private func cancelTesterRoleRequest(_ request: RoleRequestDTO) {
        guard !isProcessingTesterRoleRequest else { return }
        isProcessingTesterRoleRequest = true
        testerRoleRequestMessage = nil
        testerRoleRequestErrorMessage = nil
        Task {
            do {
                try await APIService.shared.cancelRoleRequest(id: request.id)
                testerRoleRequests.removeAll { $0.id == request.id }
                testerRoleRequestMessage = "Заявка отменена."
            } catch {
                print("[AccountView] tester role request cancel failed: \(error)")
                testerRoleRequestErrorMessage = testerRoleRequestError(for: error)
            }
            isProcessingTesterRoleRequest = false
        }
    }

    private func testerRoleRequestError(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Попробуйте ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            if statusCode == 409 {
                loadTesterRoleRequests()
                return "Заявка уже есть."
            }
            if statusCode == 401 || statusCode == 403 {
                return "Недостаточно прав для этого действия."
            }
        }
        return "Не удалось выполнить действие. Попробуйте позже."
    }

    @ViewBuilder
    private var authSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isSignedIn {
                Button {
                    signOut()
                } label: {
                    HStack {
                        Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer(minLength: 0)
                    }
                    .mympsuDefaultSurface()
                }
                .mympsuInteractiveButtonStyle()
            } else {
                HStack(spacing: 10) {
                    ZStack {
                        SignInWithAppleButton(.signIn) { request in
                            print("[AccountView] Apple Sign In request started")
#if os(iOS)
                            appLockManager.beginExternalAuthentication()
#endif
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            print("[AccountView] Apple Sign In completion received")
#if os(iOS)
                            appLockManager.endExternalAuthentication()
#endif
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .opacity(isSigningIn ? 0.55 : 1)
                        .disabled(isSigningIn)

                        if isSigningIn {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity)

#if os(iOS) || os(macOS)
                    googleAuthButton(title: "Вход с Google", isLoading: isSigningIn) {
                        handleGoogleSignIn()
                    }
                    .disabled(isSigningIn)
                    .frame(maxWidth: .infinity)
#endif
                }

                EmailPasswordLoginView(activeTheme: activeTheme, isSigningIn: isSigningIn) { email, password in
                    handlePasswordLogin(email: email, password: password)
                }
            }

            if let signInErrorMessage {
                Text(signInErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 4)
    }

    private func handlePasswordLogin(email: String, password: String) {
        isSigningIn = true
        signInErrorMessage = nil
        Task {
            do {
                let response = try await APIService.shared.loginWithPassword(email: email, password: password)
                try authSession.apply(response)
                let currentUser = try await APIService.shared.fetchCurrentUser()
                authSession.updateCurrentUser(currentUser)
                await UserSettingsSyncService.syncRemoteSettingsIfAuthenticated()
            } catch {
                print("[AccountView] Password login failed")
                signInErrorMessage = passwordLoginErrorMessage(for: error)
            }
            isSigningIn = false
        }
    }

    private func passwordLoginErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Проверьте подключение и попробуйте ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            if statusCode == 401 {
                return "Email или пароль указаны неверно."
            }
            if statusCode == 403 {
                return "Сначала подтвердите email."
            }
        }
        return "Не удалось войти по email. Проверьте данные и попробуйте ещё раз."
    }

#if os(iOS) || os(macOS)
    private var googleBrandMark: some View {
        Image(colorScheme == .dark ? "ios_dark_rd_na" : "ios_neutral_rd_na")
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
    }

    private var googleButtonBackground: Color {
        colorScheme == .dark
        ? Color(red: 0.075, green: 0.075, blue: 0.078)
        : Color(red: 0.949, green: 0.949, blue: 0.949)
    }

    private var googleButtonForeground: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.84)
    }

    private func googleAuthButton(title: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                googleBrandMark
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(googleButtonForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 48)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(googleButtonBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(colorScheme == .dark ? Color(red: 0.557, green: 0.569, blue: 0.561) : Color.black.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            .opacity(isLoading ? 0.68 : 1)
        }
        .buttonStyle(.plain)
    }

    private func handleGoogleProviderLink() {
        guard !isLinkingGoogleProvider else { return }
        isLinkingGoogleProvider = true
        providerLinkMessage = nil
        providerLinkErrorMessage = nil
        Task {
#if os(iOS)
            appLockManager.beginExternalAuthentication()
            defer { appLockManager.endExternalAuthentication() }
#endif
            do {
                let credential = try await GoogleSignInService.shared.signIn()
                let user = try await APIService.shared.linkGoogleProvider(
                    idToken: credential.idToken,
                    accessToken: credential.accessToken,
                    googleUserID: credential.userID,
                    fullName: credential.fullName,
                    email: credential.email
                )
                authSession.updateCurrentUser(user)
                providerLinkMessage = "Google привязан к аккаунту."
            } catch {
                print("[AccountView] Google provider link failed: \(error)")
                providerLinkErrorMessage = googleProviderLinkErrorMessage(for: error)
            }
            isLinkingGoogleProvider = false
        }
    }

    private func googleProviderLinkErrorMessage(for error: Error) -> String? {
        let nsError = error as NSError
        if nsError.domain == kGIDSignInErrorDomain, nsError.code == -5 {
            return nil
        }
        if case APIServiceError.httpStatus(409) = error {
            return "Этот Google уже привязан к другому аккаунту."
        }
        if case APIServiceError.httpStatus(401) = error {
            return "Сессия истекла. Войдите заново."
        }
        if error is GoogleSignInServiceError {
            return "Google Sign-In не настроен. Проверьте plist Google."
        }
        return "Не удалось привязать Google. Попробуйте ещё раз."
    }

    private func handleGoogleSignIn() {
        guard !isSigningIn else { return }
        isSigningIn = true
        signInErrorMessage = nil
        Task {
#if os(iOS)
            appLockManager.beginExternalAuthentication()
            defer { appLockManager.endExternalAuthentication() }
#endif
            do {
                let credential = try await GoogleSignInService.shared.signIn()
                let response = try await APIService.shared.signInWithGoogle(
                    idToken: credential.idToken,
                    accessToken: credential.accessToken,
                    googleUserID: credential.userID,
                    fullName: credential.fullName,
                    email: credential.email
                )
                try authSession.apply(response)
                let currentUser = try await APIService.shared.fetchCurrentUser()
                authSession.updateCurrentUser(currentUser)
                await UserSettingsSyncService.syncRemoteSettingsIfAuthenticated()
            } catch {
                print("[AccountView] Google login failed: \(error)")
                signInErrorMessage = googleSignInErrorMessage(for: error)
            }
            isSigningIn = false
        }
    }

    private func googleSignInErrorMessage(for error: Error) -> String? {
        let nsError = error as NSError
        if nsError.domain == kGIDSignInErrorDomain, nsError.code == -5 {
            return nil
        }
        if case APIServiceError.httpStatus(401) = error {
            return "Не удалось войти через Google. Попробуйте позже."
        }
        if error is GoogleSignInServiceError {
            return "Google Sign-In не настроен. Проверьте GoogleService-Info.plist."
        }
        return "Не удалось войти через Google. Попробуйте ещё раз."
    }
#endif

    private func resendContactEmailVerification() {
        guard !isResendingContactEmail else { return }
        isResendingContactEmail = true
        contactEmailMessage = nil
        contactEmailErrorMessage = nil
        Task {
            do {
                try await APIService.shared.resendContactEmailVerification()
                let user = try await APIService.shared.refreshCurrentUser()
                authSession.updateCurrentUser(user)
                contactEmailMessage = "Письмо отправлено ещё раз."
            } catch {
                print("[AccountView] contact email resend failed: \(error)")
                contactEmailErrorMessage = "Не удалось отправить письмо. Попробуйте ещё раз."
            }
            isResendingContactEmail = false
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            print("[AccountView] Apple authorization succeeded: credential=\(type(of: authorization.credential))")
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("[AccountView] Apple credential cast failed")
                signInErrorMessage = "Не удалось прочитать ответ Apple ID."
                return
            }
            guard let identityToken = string(from: credential.identityToken) else {
                print("[AccountView] Apple identity token missing")
                signInErrorMessage = "Apple не вернула токен входа."
                return
            }
            let authorizationCode = string(from: credential.authorizationCode)
            let fullName = formattedName(from: credential.fullName)
            let email = credential.email
            print("[AccountView] Apple credential parsed: hasAppleUserID=\(!credential.user.isEmpty), identityTokenLength=\(identityToken.count), authorizationCodeLength=\(authorizationCode?.count ?? 0), hasEmail=\(email != nil), hasFullName=\(fullName != nil)")

            isSigningIn = true
            signInErrorMessage = nil
            Task {
                do {
                    print("[AccountView] Sending Apple Sign In payload to backend")
                    let response = try await APIService.shared.signInWithApple(
                        identityToken: identityToken,
                        authorizationCode: authorizationCode,
                        appleUserID: credential.user,
                        fullName: fullName,
                        email: email
                    )
                    print("[AccountView] Backend Apple Sign In succeeded: userID=\(response.user.id), tokenLength=\(response.token.count)")
                    try authSession.apply(response)
                    print("[AccountView] Auth session applied: isAuthenticated=\(authSession.isAuthenticated)")
                    let currentUser = try await APIService.shared.fetchCurrentUser()
                    print("[AccountView] Current user fetched after Apple Sign In: userID=\(currentUser.id), roles=\(currentUser.roles.count)")
                    authSession.updateCurrentUser(currentUser)
                    await UserSettingsSyncService.syncRemoteSettingsIfAuthenticated()
                    appleUserID = credential.user
                    print("[AccountView] Apple Sign In completed and appleUserID stored")
                } catch {
                    print("[AccountView] Apple backend login failed: \(error)")
                    if case APIServiceError.httpStatus(401) = error {
                        signInErrorMessage = "Не удалось войти через Apple. Попробуйте позже."
                    } else {
                        signInErrorMessage = "Не удалось войти через Apple. Попробуйте ещё раз."
                    }
                }
                isSigningIn = false
                print("[AccountView] Apple Sign In loading state cleared")
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                print("[AccountView] Apple authorization canceled by user")
                return
            }
            print("[AccountView] Apple authorization failed: \(error)")
            signInErrorMessage = "Не удалось войти через Apple. Попробуйте ещё раз."
        }
    }

    private func string(from data: Data?) -> String? {
        guard let data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let name = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func validateAppleCredentialIfNeeded() {
        guard isSignedIn, !appleUserID.isEmpty else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserID) { state, error in
            if let error {
                print("[AccountView] Apple credential state check failed: \(error)")
                return
            }
            guard state == .revoked || state == .notFound else { return }
            DispatchQueue.main.async {
                signOut()
            }
        }
    }

    private func refreshBackendUserIfNeeded() {
        guard isSignedIn else { return }
        Task {
            do {
                let currentUser = try await APIService.shared.fetchCurrentUser()
                authSession.updateCurrentUser(currentUser)
            } catch {
                print("[AccountView] Backend /me refresh failed: \(error)")
                if case APIServiceError.httpStatus(401) = error {
                    signOut()
                }
            }
        }
    }

    private func saveProfile(name rawName: String, groupIdString rawGroupId: String, groupName rawGroupName: String) {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGroupId = rawGroupId.mympsuTrimmed
        let trimmedGroupName = rawGroupName.mympsuTrimmed
        guard trimmedName.count >= 2 else {
            profileErrorMessage = "Имя должно быть не короче 2 символов."
            return
        }
        guard trimmedName.count <= 40 else {
            profileErrorMessage = "Имя должно быть не длиннее 40 символов."
            return
        }
        let parsedGroupId: Int?
        if trimmedGroupId.isEmpty {
            parsedGroupId = nil
        } else if let groupId = Int(trimmedGroupId) {
            parsedGroupId = groupId
        } else {
            profileErrorMessage = "ID группы должен быть числом."
            return
        }

        isSavingProfile = true
        profileErrorMessage = nil
        Task {
            do {
                let updatedUser = try await APIService.shared.updateProfile(name: trimmedName)
                authSession.updateCurrentUser(updatedUser)

                var shouldCloseProfile = true
                if let parsedGroupId,
                   trimmedGroupId != selectedGroupId || trimmedGroupName != selectedGroupName {
                    let requestedGroupName = trimmedGroupName.isEmpty ? trimmedGroupId : trimmedGroupName
                    let groupUpdateResult = await UserSettingsSyncService.updateRemoteSelectedGroupIfAuthenticated(
                        MyGroup(id: String(parsedGroupId), name: requestedGroupName)
                    )
                    switch groupUpdateResult {
                    case .applied:
                        break
                    case .changeRequestCreated:
                        profileErrorMessage = "Заявка на смену группы отправлена модератору."
                        shouldCloseProfile = false
                    case .authenticationRequired:
                        profileErrorMessage = "Чтобы сменить группу, войдите в аккаунт."
                        shouldCloseProfile = false
                    case .failed:
                        profileErrorMessage = "Не удалось отправить заявку на смену группы."
                        showsProfileSaveError = true
                        shouldCloseProfile = false
                    }
                }

                if shouldCloseProfile {
                    resetAccountScreen()
                }
            } catch {
                print("[AccountView] Profile update failed: \(error)")
                if case APIServiceError.httpStatus(401) = error {
                    signOut()
                } else {
                    profileErrorMessage = "Не удалось сохранить профиль. Попробуйте ещё раз."
                    showsProfileSaveError = true
                }
            }
            isSavingProfile = false
        }
    }

    private func signOut() {
        authSession.signOut()
#if os(iOS)
        GoogleSignInService.shared.signOut()
#endif
        appleUserID = ""
        signInErrorMessage = nil
        profileErrorMessage = nil
        isSigningIn = false
        isSavingProfile = false
        testerRoleRequests = []
        testerRoleRequestMessage = nil
        testerRoleRequestErrorMessage = nil
        providerLinkMessage = nil
        providerLinkErrorMessage = nil
        isLinkingGoogleProvider = false
        isLoadingTesterRoleRequests = false
        isProcessingTesterRoleRequest = false
        isResendingContactEmail = false
        contactEmailMessage = nil
        contactEmailErrorMessage = nil
        resetAccountScreen()
    }
}

private struct MyGroupMembersScreen: View {
    let activeTheme: AppTheme
    let groupId: String
    let groupName: String
    let onBack: () -> Void

    @State private var users: [GroupUser] = []
    @State private var homeworks: [Homework] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var trimmedGroupId: String {
        groupId.mympsuTrimmed
    }

    private var groupTitle: String {
        let title = groupName.mympsuTrimmed
        if !title.isEmpty {
            return title
        }
        return trimmedGroupId.isEmpty ? "Группа не выбрана" : "Группа \(trimmedGroupId)"
    }

    private var groupRole: UserRole? {
        trimmedGroupId.isEmpty ? nil : UserRole(type: "group", title: groupTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Моя группа") {
                onBack()
            }
#endif

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MyMPSUSettingsCard {
                        Label(groupTitle, systemImage: "person.3.fill")
                            .font(.subheadline.weight(.semibold))

                        Text("Пользователи выбранной группы и их роли.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)

                    if trimmedGroupId.isEmpty {
                        groupStateCard(
                            icon: "person.3.fill",
                            title: "Группа не выбрана",
                            message: "Выберите группу по умолчанию в профиле."
                        )
                    } else if isLoading {
                        groupLoadingCard
                    } else if let errorMessage {
                        groupStateCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Не удалось загрузить группу",
                            message: errorMessage
                        )
                    } else if users.isEmpty {
                        groupStateCard(
                            icon: "person.3.sequence.fill",
                            title: "Пользователей пока нет",
                            message: "Backend вернул пустой список для этой группы."
                        )
                    } else {
                        sectionTitle("Участники")
                        LazyVStack(spacing: 10) {
                            ForEach(users) { user in
                                groupUserRow(user)
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    sectionTitle("Домашка")
                    if homeworks.isEmpty, !isLoading, errorMessage == nil, !trimmedGroupId.isEmpty {
                        groupStateCard(
                            icon: "doc.text",
                            title: "Домашки пока нет",
                            message: "Для выбранной группы ещё не добавляли домашку."
                        )
                    } else if !homeworks.isEmpty {
                        LazyVStack(spacing: 10) {
                            ForEach(homeworks) { homework in
                                homeworkRow(homework)
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    Color.clear.frame(height: 32)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuTask {
            await loadGroupData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mympsuHomeworksDidChange)) { _ in
            Task {
                await loadGroupData()
            }
        }
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
    }

    private var groupLoadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Загружаем пользователей")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .mympsuDefaultSurface()
        .padding(.horizontal, 4)
    }

    private func groupStateCard(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .mympsuDefaultSurface()
        .padding(.horizontal, 4)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
    }

    private func groupUserRow(_ user: GroupUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        UserBadgeInlineStackView(badges: user.badges)
                    }
                    if let email = user.email, !email.mympsuTrimmed.isEmpty {
                        Text(email)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            RoleBadgeStackView(roles: rolesForDisplay(user.sortedRoles))
        }
        .mympsuDefaultSurface()
    }

    private func rolesForDisplay(_ roles: [UserRole]) -> [UserRole] {
        guard let groupRole else { return roles }
        var result = roles.filter { $0.type != groupRole.type }
        result.append(groupRole)
        return result
    }

    private func homeworkRow(_ homework: Homework) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(homework.subject)
                        .font(.subheadline.weight(.semibold))
                    Text("\(homework.lessonDate) • \(homework.lessonTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }

            if let teacher = homework.teacher, !teacher.mympsuTrimmed.isEmpty {
                Label(teacher, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let room = homework.room, !room.mympsuTrimmed.isEmpty {
                Label(room, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(homework.text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .mympsuDefaultSurface()
    }

    private func loadGroupData() async {
        guard !trimmedGroupId.isEmpty, !isLoading else { return }
        guard let groupId = Int(trimmedGroupId) else {
            errorMessage = "Группа выбрана некорректно."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let users = APIService.shared.fetchGroupUsers(groupId: groupId)
            async let homeworks = APIService.shared.fetchGroupHomeworks(groupId: groupId, date: nil)
            self.users = try await users
            self.homeworks = try await homeworks
        } catch {
            errorMessage = message(for: error)
        }
        isLoading = false
    }

    private func message(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Проверьте подключение и попробуйте ещё раз."
        }
        if case APIServiceError.httpStatusWithBody(let statusCode, _) = error {
            if statusCode == 401 || statusCode == 403 {
                return "Недостаточно прав для просмотра пользователей группы."
            }
            if statusCode == 404 {
                return "Backend endpoint для пользователей группы пока недоступен."
            }
            return "Backend вернул ошибку \(statusCode)."
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            return "Backend вернул ошибку \(statusCode)."
        }
        return "Не удалось загрузить пользователей группы."
    }
}

private struct ProfileEditorView: View {
    let activeTheme: AppTheme
    let initialName: String
    let accountDisplayName: String
    let email: String?
    let badges: [UserBadge]
    let roles: [UserRole]
    let defaultGroupRole: UserRole?
    let initialGroupId: String
    let initialGroupName: String
    let isSaving: Bool
    let errorMessage: String?
    let onBack: () -> Void
    let onOpenRoleRequest: () -> Void
    let onOpenMyRoleRequests: () -> Void
    let onSave: (String, String, String) -> Void

    private enum ProfileSaveWarning: Identifiable {
        case initialGroupBinding
        case groupChangeRequest

        var id: String {
            switch self {
            case .initialGroupBinding:
                return "initialGroupBinding"
            case .groupChangeRequest:
                return "groupChangeRequest"
            }
        }

        var title: String {
            switch self {
            case .initialGroupBinding:
                return "Группа по умолчанию"
            case .groupChangeRequest:
                return "Смена группы по умолчанию"
            }
        }

        var message: String {
            switch self {
            case .initialGroupBinding:
                return "Эта группа будет привязана к аккаунту. По ней будут показываться домашка и участники. Позже сменить её можно будет только через заявку модератору."
            case .groupChangeRequest:
                return "Группа не поменяется сразу. Мы создадим заявку для модератора, и после одобрения к новой группе будут привязаны домашка и участники."
            }
        }
    }

    @State private var displayName: String
    @State private var groupId: String
    @State private var groupName: String
    @State private var groups: [MyGroup] = []
    @State private var groupSearchText = ""
    @State private var isNameEditorExpanded = false
    @State private var isGroupPickerExpanded = false
    @State private var isLoadingGroups = false
    @State private var profileSaveWarning: ProfileSaveWarning?
    @Environment(\.mympsuSurfaceStrokeOpacity) private var strokeOpacity

    init(
        activeTheme: AppTheme,
        initialName: String,
        accountDisplayName: String,
        email: String?,
        badges: [UserBadge],
        roles: [UserRole],
        defaultGroupRole: UserRole?,
        initialGroupId: String,
        initialGroupName: String,
        isSaving: Bool,
        errorMessage: String?,
        onBack: @escaping () -> Void,
        onOpenRoleRequest: @escaping () -> Void,
        onOpenMyRoleRequests: @escaping () -> Void,
        onSave: @escaping (String, String, String) -> Void
    ) {
        self.activeTheme = activeTheme
        self.initialName = initialName
        self.accountDisplayName = accountDisplayName
        self.email = email
        self.badges = badges
        self.roles = roles
        self.defaultGroupRole = defaultGroupRole
        self.initialGroupId = initialGroupId
        self.initialGroupName = initialGroupName
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onBack = onBack
        self.onOpenRoleRequest = onOpenRoleRequest
        self.onOpenMyRoleRequests = onOpenMyRoleRequests
        self.onSave = onSave
        self._displayName = State(initialValue: initialName)
        self._groupId = State(initialValue: initialGroupId)
        self._groupName = State(initialValue: initialGroupName)
    }

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedGroupId: String {
        groupId.mympsuTrimmed
    }

    private var trimmedGroupName: String {
        groupName.mympsuTrimmed
    }

    private var validationMessage: String? {
        guard !trimmedName.isEmpty else { return nil }
        if trimmedName.count < 2 {
            return "Минимум 2 символа."
        }
        if trimmedName.count > 40 {
            return "Максимум 40 символов."
        }
        if !trimmedGroupId.isEmpty && Int(trimmedGroupId) == nil {
            return "Выберите группу из списка."
        }
        return nil
    }

    private var canSave: Bool {
        validationMessage == nil && !trimmedName.isEmpty && !isSaving
    }

    private var normalizedInitialGroupId: String {
        initialGroupId.mympsuTrimmed
    }

    private var shouldWarnInitialGroupBinding: Bool {
        normalizedInitialGroupId.isEmpty && !trimmedGroupId.isEmpty
    }

    private var shouldWarnGroupChangeRequest: Bool {
        !normalizedInitialGroupId.isEmpty && !trimmedGroupId.isEmpty && trimmedGroupId != normalizedInitialGroupId
    }

    private var profileSurfaceFill: Color {
        activeTheme.usesCloudSurface ? activeTheme.cloudSurfaceFill : Color.mympsuHeaderCapsuleFill
    }

    private var profileSurfaceStroke: Color {
        activeTheme.usesCloudSurface
        ? activeTheme.cloudSurfaceStroke
        : Color.mympsuSurfaceStrokeBase.opacity(strokeOpacity + 0.12)
    }

    private var profileButtonStroke: Color {
        activeTheme.usesCloudSurface
        ? activeTheme.cloudSurfaceStroke
        : Color.mympsuSurfaceStrokeBase.opacity(strokeOpacity)
    }

    private func profileGroupButtonFill(isSelected: Bool) -> Color {
        if activeTheme.usesCloudSurface {
            return activeTheme.cloudSurfaceFill.opacity(isSelected ? 1 : 0.55)
        }
        return Color.mympsuHeaderCapsuleFill.opacity(isSelected ? 1 : 0.55)
    }

    private var profileBadges: [UserRole] {
        var displayRoles = roles
        if let defaultGroupRole {
            displayRoles.removeAll { $0.type == defaultGroupRole.type }
            displayRoles.append(defaultGroupRole)
        }
        return displayRoles.sorted { lhs, rhs in
            let lhsPriority = UserRole.roleOrder[lhs.type] ?? 999
            let rhsPriority = UserRole.roleOrder[rhs.type] ?? 999
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private var selectedGroupTitle: String {
        if !trimmedGroupName.isEmpty {
            return trimmedGroupName
        }
        if !trimmedGroupId.isEmpty {
            return "Выберите группу из списка"
        }
        return "Не выбрана"
    }

    private var profileNameTitle: String {
        if !trimmedName.isEmpty {
            return trimmedName
        }

        let fallbackName = accountDisplayName.mympsuTrimmed
        return fallbackName.isEmpty ? "Не указано" : fallbackName
    }

    private var isProfileNamePlaceholder: Bool {
        trimmedName.isEmpty && accountDisplayName.mympsuTrimmed.isEmpty
    }

    private var filteredGroups: [MyGroup] {
        let query = groupSearchText.mympsuTrimmed
        let source: [MyGroup]
        if query.isEmpty {
            source = groups
        } else {
            source = groups.filter { group in
                group.name.localizedCaseInsensitiveContains(query) || group.id.localizedCaseInsensitiveContains(query)
            }
        }
        return Array(source.prefix(40))
    }

    private var saveButtonBottomPadding: CGFloat {
#if os(iOS)
        16
#else
        16
#endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Профиль") {
                onBack()
            }
            .disabled(isSaving)
#endif

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    profileIdentitySection

                    UserBadgeGalleryView(badges: badges, showsEmptyState: true)
                        .padding(.horizontal, 4)

                    rolesSection

                    defaultGroupPicker

                    if let validationMessage {
                        profileMessage(validationMessage, color: .red)
                    } else if let errorMessage {
                        profileMessage(errorMessage, color: .red)
                    }

                    Color.clear.frame(height: 96)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuBottomInset {
            saveButton
                .padding(.horizontal, 16)
                .padding(.bottom, saveButtonBottomPadding)
        }
        .mympsuTask {
            await loadGroupsIfNeeded()
        }
        .alert(item: $profileSaveWarning) { warning in
            Alert(
                title: Text(warning.title),
                message: Text(warning.message),
                primaryButton: .default(Text("Понял")) {
                    profileSaveWarning = nil
                    submitProfile()
                },
                secondaryButton: .cancel(Text("Отмена")) {
                    profileSaveWarning = nil
                }
            )
        }
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
    }

    private var defaultGroupPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Группа по умолчанию")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedGroupTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                profileEditButton(accessibilityLabel: "Изменить группу по умолчанию") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isGroupPickerExpanded.toggle()
                    }
                }
            }
            .padding(.vertical, 4)

            if isGroupPickerExpanded {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск группы", text: $groupSearchText)
                        .textFieldStyle(.plain)
                        .disabled(isSaving)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled(true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(profileSurfaceFill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(profileButtonStroke, lineWidth: 0.8)
                )

                if isLoadingGroups {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Загружаем группы")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if filteredGroups.isEmpty {
                    Text(groups.isEmpty ? "Список групп пока недоступен." : "Группы не найдены.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredGroups) { group in
                                groupButton(group)
                            }
                        }
                    }
                    .frame(maxHeight: 224)
                }
            }

            Text("Используется для домашки и участников группы.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .mympsuDefaultSurface()
    }

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Роли")
                .font(.caption)
                .foregroundColor(.secondary)

            if !profileBadges.isEmpty {
                RoleBadgeStackView(roles: profileBadges)
            }

            Button {
                onOpenRoleRequest()
            } label: {
                HStack {
                    Label("Запросить роль", systemImage: "person.badge.plus")
                    Spacer(minLength: 0)
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()

            Button {
                onOpenMyRoleRequests()
            } label: {
                HStack {
                    Label("Мои заявки", systemImage: "list.bullet.rectangle")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
        }
        .mympsuDefaultSurface()
    }

    private func groupButton(_ group: MyGroup) -> some View {
        Button {
            groupId = group.id
            groupName = group.name
            groupSearchText = ""
            withAnimation(.easeInOut(duration: 0.18)) {
                isGroupPickerExpanded = false
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: group.id == trimmedGroupId ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(group.id == trimmedGroupId ? .accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(profileGroupButtonFill(isSelected: group.id == trimmedGroupId))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private var profileIdentitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileEmailField
            profileNameField
        }
        .mympsuDefaultSurface()
    }

    private var profileEmailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Text(email?.isEmpty == false ? email ?? "Не указан" : "Не указан")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func profileEditButton(accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        if activeTheme.usesCloudSurface {
            ThemedChrome(shape: activeTheme.headerShape) {
                Button(action: action) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 42, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .accessibilityLabel(accessibilityLabel)
        } else {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            Button(action: action) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 42, height: 34)
                    .background(profileSurfaceFill)
                    .clipShape(shape)
                    .overlay(
                        shape.stroke(profileSurfaceStroke, lineWidth: 0.8)
                    )
                    .contentShape(shape)
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var profileNameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Имя")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .foregroundColor(.accentColor)
                Text(profileNameTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isProfileNamePlaceholder ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)

                profileEditButton(accessibilityLabel: "Изменить имя") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isNameEditorExpanded.toggle()
                    }
                }
            }
            .padding(.vertical, 4)

            if isNameEditorExpanded {
                TextField("Имя", text: $displayName)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                    .disabled(isSaving)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(profileSurfaceFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(profileSurfaceStroke, lineWidth: 1)
                    )
            }
        }
    }

    private func profileMessage(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 4)
    }

    private var saveButton: some View {
        Button {
            handleSaveTap()
        } label: {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Сохранить")
                }
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .frame(height: 50)
            .background(profileSurfaceFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(profileButtonStroke, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.55)
    }

    private func handleSaveTap() {
        if shouldWarnInitialGroupBinding {
            profileSaveWarning = .initialGroupBinding
            return
        }
        if shouldWarnGroupChangeRequest {
            profileSaveWarning = .groupChangeRequest
            return
        }
        submitProfile()
    }

    private func submitProfile() {
        onSave(trimmedName, trimmedGroupId, trimmedGroupName)
    }

    private func loadGroupsIfNeeded() async {
        guard groups.isEmpty, !isLoadingGroups else { return }
        isLoadingGroups = true
        let institutes = await APIService.shared.fetchInstitutesWithGroups()
        let loadedGroups = institutes
            .flatMap(\.groups)
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        groups = loadedGroups
        isLoadingGroups = false
    }
}
