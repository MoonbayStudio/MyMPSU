#if os(iOS)
import AuthenticationServices
import SwiftUI
import GoogleSignIn

struct MyMPSUOnboardingView: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    let onFinish: () -> Void

    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @AppStorage("accessibilityHighContrast") private var highContrast = false
    @AppStorage("accessibilityLargerText") private var largerText = false
    @AppStorage("offlineScheduleEnabled") private var offlineScheduleEnabled = true
    @AppStorage("offlineScheduleWeeks") private var offlineScheduleWeeks = 1
    @StateObject private var authSession = AuthSessionManager.shared
    @State private var step = 0
    @State private var isCompleting = false

    private let stepCount = 5

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                OnboardingAuthPage(
                    activeTheme: activeTheme,
                    onExistingAccountReady: completeAfterExistingAccountLogin,
                    onContinue: goNext
                )
                .tag(0)

                OnboardingGroupPage(
                    scheduleViewModel: scheduleViewModel,
                    activeTheme: activeTheme,
                    onContinue: goNext
                )
                .tag(1)

                OnboardingAccessibilityPage(
                    highContrast: $highContrast,
                    largerText: $largerText,
                    onContinue: goNext
                )
                .tag(2)

                OnboardingCachePage(
                    offlineScheduleEnabled: $offlineScheduleEnabled,
                    offlineScheduleWeeks: $offlineScheduleWeeks,
                    onContinue: goNext
                )
                .tag(3)

                OnboardingDonePage(isCompleting: isCompleting) {
                    completeOnboarding()
                }
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: step)

            onboardingBottomBar
        }
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .task {
            await handleAlreadyAuthenticatedUserIfNeeded()
        }
    }

    private var onboardingBottomBar: some View {
        HStack {
            if step > 0 && step < stepCount - 1 {
                Button {
                    step -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .frame(width: 52, height: 52)
                        .background(Color.mympsuHeaderCapsuleFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 52, height: 52)
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.accentColor : Color.secondary.opacity(0.28))
                        .frame(width: index == step ? 22 : 8, height: 8)
                }
            }

            Spacer()

            if step > 0 && step < stepCount - 1 {
                Button {
                    goNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .frame(width: 52, height: 52)
                        .background(Color.mympsuHeaderCapsuleFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 52, height: 52)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
    }

    private func goNext() {
        step = min(step + 1, stepCount - 1)
    }

    private func completeAfterExistingAccountLogin() {
        Task {
            await UserSettingsSyncService.syncRemoteSettingsIfAuthenticated()
            await MainActor.run {
                if Self.hasDefaultGroup {
                    completeOnboarding()
                } else {
                    goNext()
                }
            }
        }
    }

    private func handleAlreadyAuthenticatedUserIfNeeded() async {
        guard authSession.isAuthenticated, step == 0 else { return }
        await UserSettingsSyncService.syncRemoteSettingsIfAuthenticated()
        await MainActor.run {
            if Self.hasDefaultGroup {
                completeOnboarding()
            } else {
                goNext()
            }
        }
    }

    private func completeOnboarding() {
        guard !isCompleting else { return }
        isCompleting = true
        Task {
            _ = await UserSettingsSyncService.pushLocalSettingsIfAuthenticated()
            await MainActor.run {
                onFinish()
            }
        }
    }

    private static var hasDefaultGroup: Bool {
        let sharedValue = UserDefaults(suiteName: "group.mympsu.shared")?.string(forKey: "selectedGroupId")
        let value = sharedValue ?? UserDefaults.standard.string(forKey: "selectedGroupId") ?? ""
        return !value.mympsuTrimmed.isEmpty
    }
}

private struct OnboardingAuthPage: View {
    let activeTheme: AppTheme
    let onExistingAccountReady: () -> Void
    let onContinue: () -> Void

    @StateObject private var authSession = AuthSessionManager.shared
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 24)

                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundColor(.accentColor)

                Text("Ваш аккаунт")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Войдите, чтобы взять группу и настройки из аккаунта, или продолжите настройку на этом устройстве.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    ZStack {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
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

                    Button {
                        handleGoogleSignIn()
                    } label: {
                        HStack(spacing: 12) {
                            Image("ios_neutral_rd_na")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            Text("Вход с Google")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white)
                        .foregroundColor(.black.opacity(0.84))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.black.opacity(0.10), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningIn)
                }

                EmailPasswordLoginView(
                    activeTheme: activeTheme,
                    isSigningIn: isSigningIn,
                    onLogin: { email, password in
                        handlePasswordLogin(email: email, password: password)
                    },
                    onSignupVerified: {
                        onContinue()
                    }
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button("Пропустить") {
                    onContinue()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
    }

    private func handlePasswordLogin(email: String, password: String) {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        Task {
            do {
                let response = try await APIService.shared.loginWithPassword(email: email, password: password)
                try authSession.apply(response)
                let currentUser = try await APIService.shared.fetchCurrentUser()
                authSession.updateCurrentUser(currentUser)
                await UserSettingsSyncService.syncRemoteSettingsIfAuthenticated()
                await MainActor.run {
                    onExistingAccountReady()
                }
            } catch {
                errorMessage = authErrorMessage(for: error)
            }
            isSigningIn = false
        }
    }

    private func handleGoogleSignIn() {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        Task {
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
                await MainActor.run {
                    onExistingAccountReady()
                }
            } catch {
                let nsError = error as NSError
                if nsError.domain != kGIDSignInErrorDomain || nsError.code != -5 {
                    errorMessage = authErrorMessage(for: error)
                }
            }
            isSigningIn = false
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = string(from: credential.identityToken) else {
                errorMessage = "Не удалось прочитать ответ Apple ID."
                return
            }
            isSigningIn = true
            errorMessage = nil
            Task {
                do {
                    let response = try await APIService.shared.signInWithApple(
                        identityToken: identityToken,
                        authorizationCode: string(from: credential.authorizationCode),
                        appleUserID: credential.user,
                        fullName: formattedName(from: credential.fullName),
                        email: credential.email
                    )
                    try authSession.apply(response)
                    let currentUser = try await APIService.shared.fetchCurrentUser()
                    authSession.updateCurrentUser(currentUser)
                    await UserSettingsSyncService.syncRemoteSettingsIfAuthenticated()
                    await MainActor.run {
                        onExistingAccountReady()
                    }
                } catch {
                    errorMessage = authErrorMessage(for: error)
                }
                isSigningIn = false
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            errorMessage = "Не удалось войти через Apple. Попробуйте ещё раз."
        }
    }

    private func authErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Проверьте подключение и попробуйте ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            if statusCode == 401 {
                return "Не удалось войти. Проверьте данные и попробуйте ещё раз."
            }
            if statusCode == 403 {
                return "Сначала подтвердите email."
            }
        }
        return "Не удалось войти. Попробуйте ещё раз."
    }

    private func string(from data: Data?) -> String? {
        guard let data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let name = formatter.string(from: components).mympsuTrimmed
        return name.isEmpty ? nil : name
    }
}

private struct OnboardingGroupPage: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    let activeTheme: AppTheme
    let onContinue: () -> Void

    @State private var institutes: [Institute] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var message: String?
    @State private var submittingGroupId: String?
    @State private var pendingGroup: MyGroup?
    @State private var showsGroupWarning = false
    @AppStorage("selectedGroupId") private var defaultGroupId = ""

    private var filteredGroups: [MyGroup] {
        let allGroups = institutes.flatMap(\.groups)
        let query = searchText.mympsuTrimmed
        guard !query.isEmpty else { return allGroups }
        return allGroups.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ваша группа")
                    .font(.largeTitle.weight(.bold))
                Text("Выберите группу для домашки, участников и первого расписания.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            TextField("Найти группу", text: $searchText)
                .textFieldStyle(.plain)
                .padding(12)
                .mympsuDefaultSurface(cornerRadius: 14, padding: 0)
                .padding(.horizontal, 24)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 28)
            }

            Group {
                if isLoading && institutes.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Загружаем группы")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredGroups.isEmpty {
                    Text("Группы не найдены")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredGroups) { group in
                        Button {
                            select(group)
                        } label: {
                            HStack {
                                Text(group.name)
                                    .font(.body.weight(.semibold))
                                Spacer()
                                if submittingGroupId == group.id {
                                    ProgressView()
                                        .scaleEffect(0.75)
                                } else if scheduleViewModel.savedGroupId == group.id || defaultGroupId == group.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(submittingGroupId != nil)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await loadGroups()
        }
        .alert("Группа по умолчанию", isPresented: $showsGroupWarning) {
            Button("Отмена", role: .cancel) {
                pendingGroup = nil
            }
            Button("Понял") {
                confirmPendingGroup()
            }
        } message: {
            Text("Эта группа будет привязана к аккаунту. По ней будут показываться домашка и участники. Позже сменить её можно будет только через заявку модератору.")
        }
    }

    private func loadGroups() async {
        guard institutes.isEmpty else { return }
        isLoading = true
        let cached = APIService.shared.fetchCachedInstitutesWithGroups()
        if !cached.isEmpty {
            institutes = cached
        }
        let loaded = await APIService.shared.fetchInstitutesWithGroups()
        if !loaded.isEmpty {
            institutes = loaded
        }
        isLoading = false
    }

    private func select(_ group: MyGroup) {
        guard submittingGroupId == nil else { return }
        message = nil
        if defaultGroupId.mympsuTrimmed.isEmpty {
            pendingGroup = group
            showsGroupWarning = true
        } else {
            applyScheduleGroup(group)
            onContinue()
        }
    }

    private func confirmPendingGroup() {
        guard let group = pendingGroup else { return }
        pendingGroup = nil
        submittingGroupId = group.id
        Task {
            let result = await UserSettingsSyncService.updateRemoteSelectedGroupIfAuthenticated(group)
            await MainActor.run {
                submittingGroupId = nil
                switch result {
                case .applied:
                    applyScheduleGroup(group)
                    onContinue()
                case .changeRequestCreated:
                    message = "Заявка на смену группы отправлена модератору."
                case .authenticationRequired:
                    message = "Чтобы сменить группу, войдите в аккаунт."
                case .failed:
                    message = "Не удалось обновить группу. Попробуйте ещё раз."
                }
            }
        }
    }

    private func applyScheduleGroup(_ group: MyGroup) {
        scheduleViewModel.savedGroupId = group.id
        UserDefaults.standard.set(group.name, forKey: "scheduleGroupName")
        UserDefaults(suiteName: "group.mympsu.shared")?.set(group.name, forKey: "scheduleGroupName")
    }
}

private struct OnboardingAccessibilityPage: View {
    @Binding var highContrast: Bool
    @Binding var largerText: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "textformat.size")
                .font(.system(size: 72, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("Удобство")
                .font(.largeTitle.weight(.bold))
            VStack(spacing: 10) {
                Toggle("Увеличенный шрифт", isOn: $largerText)
                Toggle("Высокий контраст", isOn: $highContrast)
            }
            .mympsuDefaultSurface()
            .padding(.horizontal, 24)

            Button("Готово") {
                onContinue()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

private struct OnboardingCachePage: View {
    @Binding var offlineScheduleEnabled: Bool
    @Binding var offlineScheduleWeeks: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 72, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("Офлайн доступ")
                .font(.largeTitle.weight(.bold))
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Сохранять расписание", isOn: $offlineScheduleEnabled)
                if offlineScheduleEnabled {
                    Stepper(value: $offlineScheduleWeeks, in: 1...4) {
                        Text("Кэшировать на \(offlineScheduleWeeks) нед.")
                    }
                }
            }
            .mympsuDefaultSurface()
            .padding(.horizontal, 24)

            Button("Продолжить") {
                onContinue()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

private struct OnboardingDonePage: View {
    let isCompleting: Bool
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96, weight: .semibold))
                .foregroundColor(.green)
            Text("Всё готово")
                .font(.largeTitle.weight(.bold))
            Text("Можно начинать.")
                .font(.body)
                .foregroundColor(.secondary)
            Button {
                onFinish()
            } label: {
                HStack {
                    Spacer()
                    if isCompleting {
                        ProgressView()
                    } else {
                        Text("Начать пользоваться")
                            .font(.headline)
                    }
                    Spacer()
                }
                .frame(height: 54)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCompleting)
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}
#endif
