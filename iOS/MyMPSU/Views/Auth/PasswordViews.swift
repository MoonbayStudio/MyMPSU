import SwiftUI

struct EmailPasswordLoginView: View {
    let activeTheme: AppTheme
    let isSigningIn: Bool
    let onLogin: (String, String) -> Void
    var onSignupVerified: (() -> Void)? = nil

    @StateObject private var authSession = AuthSessionManager.shared
    @State private var mode: EmailAuthMode = .login
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var repeatedPassword = ""
    @State private var verificationCode = ""
    @State private var pendingSignupEmail: String?
    @State private var isSigningUp = false
    @State private var signupMessage: String?
    @State private var signupErrorMessage: String?
    @State private var showPasswordReset = false

    private var canSubmit: Bool {
        !email.mympsuTrimmed.isEmpty && !password.isEmpty && !isSigningIn
    }

    private var trimmedSignupCode: String {
        verificationCode.mympsuTrimmed
    }

    private var canRequestSignup: Bool {
        displayName.mympsuTrimmed.count >= 2
        && email.mympsuTrimmed.contains("@")
        && email.mympsuTrimmed.contains(".")
        && password.count >= 8
        && password == repeatedPassword
        && !isBusy
    }

    private var canVerifySignup: Bool {
        pendingSignupEmail != nil
        && trimmedSignupCode.count == 6
        && trimmedSignupCode.allSatisfy(\.isNumber)
        && !isBusy
    }

    private var isBusy: Bool {
        isSigningIn || isSigningUp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $mode) {
                Text("Вход").tag(EmailAuthMode.login)
                Text("Регистрация").tag(EmailAuthMode.signup)
            }
            .pickerStyle(.segmented)
            .disabled(isBusy)

            if mode == .login {
                Text("Войти по email")
                    .font(.subheadline.weight(.semibold))
                emailField(title: "Email", text: $email)
                passwordField(title: "Пароль", text: $password)

                Button {
                    onLogin(email.mympsuTrimmed, password)
                } label: {
                    authActionLabel(title: "Войти", systemImage: "key.fill", isLoading: isSigningIn)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.55)

                Button("Забыли пароль?") {
                    showPasswordReset = true
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            } else {
                Text(pendingSignupEmail == nil ? "Создать аккаунт" : "Подтвердите почту")
                    .font(.subheadline.weight(.semibold))

                if pendingSignupEmail == nil {
                    textInputField(title: "Имя", placeholder: "Как вас показывать", text: $displayName)
                    emailField(title: "Почта", text: $email)
                    passwordField(title: "Пароль", text: $password)
                    passwordField(title: "Повторите пароль", text: $repeatedPassword)

                    Button {
                        requestSignup()
                    } label: {
                        authActionLabel(title: "Зарегистрироваться", systemImage: "person.badge.plus.fill", isLoading: isSigningUp)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRequestSignup)
                    .opacity(canRequestSignup ? 1 : 0.55)
                } else {
                    Text("Мы отправили 6-значный код на \(pendingSignupEmail ?? email.mympsuTrimmed).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .mympsuTextSelectionEnabled()
                    codeField
                    Button {
                        verifySignup()
                    } label: {
                        authActionLabel(title: "Подтвердить", systemImage: "checkmark.seal.fill", isLoading: isSigningUp)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canVerifySignup)
                    .opacity(canVerifySignup ? 1 : 0.55)
                }

                if let signupMessage {
                    Text(signupMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let signupErrorMessage {
                    Text(signupErrorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .mympsuDefaultSurface()
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView(activeTheme: activeTheme, initialEmail: email.mympsuTrimmed)
        }
    }

    private func textInputField(title: String, placeholder: String, text: Binding<String>) -> some View {
        outlinedInputField(title: title) {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .disabled(isBusy || pendingSignupEmail != nil)
        }
    }

    private func emailField(title: String, text: Binding<String>) -> some View {
        outlinedInputField(title: title) {
            TextField("почта", text: text)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .mympsuEmailTextContentType()
#if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
#endif
                .autocorrectionDisabled(true)
                .disabled(isBusy || pendingSignupEmail != nil)
        }
    }

    private func passwordField(title: String, text: Binding<String>) -> some View {
        outlinedInputField(title: title) {
            SecureField(title, text: text)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .disabled(isBusy || pendingSignupEmail != nil)
                .mympsuNewPasswordTextContentType()
        }
    }

    private var codeField: some View {
        outlinedInputField(title: "Код подтверждения") {
            TextField("123456", text: $verificationCode)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .textContentType(.oneTimeCode)
                .disabled(isBusy)
#if os(iOS)
                .keyboardType(.numberPad)
#endif
                .onChange(of: verificationCode) { value in
                    verificationCode = String(value.filter(\.isNumber).prefix(6))
                }
        }
    }

    private func outlinedInputField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.mympsuHeaderCapsuleFill.opacity(0.28))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.mympsuSurfaceStrokeBase.opacity(0.24), lineWidth: 0.8)
                )
        }
    }

    private func authActionLabel(title: String, systemImage: String, isLoading: Bool) -> some View {
        HStack {
            Spacer(minLength: 0)
            if isLoading {
                ProgressView()
            } else {
                Label(title, systemImage: systemImage)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 44)
        .background(Color.mympsuHeaderCapsuleFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func requestSignup() {
        guard canRequestSignup else { return }
        isSigningUp = true
        signupMessage = nil
        signupErrorMessage = nil
        Task {
            do {
                let email = try await APIService.shared.signUpWithPassword(
                    email: email.mympsuTrimmed,
                    password: password,
                    displayName: displayName.mympsuTrimmed
                )
                pendingSignupEmail = email
                signupMessage = "Код отправлен на почту."
            } catch {
                signupErrorMessage = signupRequestErrorMessage(for: error)
            }
            isSigningUp = false
        }
    }

    private func verifySignup() {
        guard canVerifySignup, let pendingSignupEmail else { return }
        isSigningUp = true
        signupMessage = nil
        signupErrorMessage = nil
        Task {
            do {
                let response = try await APIService.shared.verifyPasswordSignup(
                    email: pendingSignupEmail,
                    code: trimmedSignupCode
                )
                try authSession.apply(response)
                let currentUser = try await APIService.shared.fetchCurrentUser()
                authSession.updateCurrentUser(currentUser)
                await UserSettingsSyncService.syncRemoteSettingsIfAuthenticated()
                signupMessage = "Аккаунт подтверждён."
                onSignupVerified?()
            } catch {
                signupErrorMessage = signupVerificationErrorMessage(for: error)
            }
            isSigningUp = false
        }
    }

    private func signupRequestErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Проверьте подключение и попробуйте ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            if statusCode == 409 {
                return "Эта почта уже занята."
            }
            if statusCode == 422 {
                return "Проверьте почту и сложность пароля."
            }
        }
        return "Не удалось создать аккаунт. Попробуйте ещё раз."
    }

    private func signupVerificationErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Код не сброшен, попробуйте ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error,
           [400, 404, 410, 422].contains(statusCode) {
            return "Код неверный или истёк."
        }
        return "Не удалось подтвердить аккаунт. Попробуйте ещё раз."
    }

    private enum EmailAuthMode {
        case login
        case signup
    }
}

struct PasswordSetupView: View {
    let activeTheme: AppTheme
    let mode: PasswordEditorMode
    let onBack: () -> Void
    let onSuccess: (AppleUser) -> Void

    @StateObject private var authSession = AuthSessionManager.shared
    @State private var currentPassword = ""
    @State private var password = ""
    @State private var repeatedPassword = ""
    @State private var contactEmail = ""
    @State private var isSaving = false
    @State private var isSendingContactEmail = false
    @State private var errorMessage: String?
    @State private var contactEmailMessage: String?
    @State private var contactEmailErrorMessage: String?
    @State private var didSucceed = false

    private var title: String {
        mode == .setup ? "Создать пароль" : "Изменить пароль"
    }

    private var validationMessage: String? {
        if mode == .change && currentPassword.isEmpty {
            return nil
        }
        guard !password.isEmpty || !repeatedPassword.isEmpty else { return nil }
        if password.count < 8 {
            return "Минимум 8 символов."
        }
        if password != repeatedPassword {
            return "Пароли не совпадают."
        }
        return nil
    }

    private var currentUser: AppleUser? {
        authSession.currentUser
    }

    private var requiresContactEmailBeforePassword: Bool {
        mode == .setup && currentUser?.needsPasswordContactEmail == true
    }

    private var requiresContactEmailVerificationBeforePassword: Bool {
        guard mode == .setup, let currentUser else { return false }
        return !currentUser.needsPasswordContactEmail && !currentUser.passwordContactEmailIsVerified
    }

    private var canEditPasswordFields: Bool {
        mode == .change || currentUser?.canCreatePassword == true
    }

    private var canSubmit: Bool {
        validationMessage == nil
        && password.count >= 8
        && password == repeatedPassword
        && (mode == .setup || !currentPassword.isEmpty)
        && canEditPasswordFields
        && !isSaving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: title) {
                onBack()
            }
            .disabled(isSaving)
#endif

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if didSucceed {
                        successCard
                    }

                    if mode == .setup {
                        contactEmailPrerequisiteCard
                    }

                    MyMPSUSettingsCard {
                        if mode == .setup {
                            Text(passwordSetupPrompt)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if mode == .change {
                            passwordField(title: "Текущий пароль", placeholder: "Текущий пароль", text: $currentPassword, usesNewPasswordContentType: false)
                        }
                        passwordField(title: mode == .setup ? "Пароль" : "Новый пароль", placeholder: "Пароль", text: $password, usesNewPasswordContentType: true)
                        passwordField(title: mode == .setup ? "Повторите пароль" : "Повторите новый пароль", placeholder: "Повторите пароль", text: $repeatedPassword, usesNewPasswordContentType: true)
                    }
                    .disabled(!canEditPasswordFields || isSendingContactEmail)
                    .opacity(canEditPasswordFields ? 1 : 0.55)

                    if let validationMessage {
                        message(validationMessage, color: .red)
                    } else if let errorMessage {
                        message(errorMessage, color: .red)
                    }

                    Color.clear.frame(height: 96)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuBottomInset {
            submitButton
                .padding(.horizontal, 16)
                .padding(.bottom, bottomPadding)
        }
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
        .onAppear {
            if contactEmail.isEmpty {
                contactEmail = currentUser?.passwordContactEmail
                    ?? currentUser?.accountEmail
                    ?? ""
            }
        }
    }

    private var passwordSetupPrompt: String {
        if currentUser?.canCreatePassword == true {
            return "Почта подтверждена. Создайте пароль, чтобы входить по email и паролю."
        }
        return "Чтобы создать пароль, сначала укажите и подтвердите контактную почту."
    }

    @ViewBuilder
    private var contactEmailPrerequisiteCard: some View {
        if requiresContactEmailBeforePassword {
            MyMPSUSettingsCard {
                Label("Контактная почта", systemImage: "envelope.badge.fill")
                    .font(.subheadline.weight(.semibold))
                Text("Укажите email, на который отправим письмо подтверждения. После подтверждения можно будет создать пароль.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Email", text: $contactEmail)
                    .textFieldStyle(.plain)
                    .mympsuEmailTextContentType()
#if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled(true)
                    .disabled(isSendingContactEmail)
                Button {
                    requestContactEmailVerification()
                } label: {
                    contactEmailActionLabel("Отправить письмо")
                }
                .disabled(contactEmail.mympsuTrimmed.isEmpty || isSendingContactEmail)
                .mympsuInteractiveButtonStyle()
                contactEmailStatusMessages
            }
        } else if requiresContactEmailVerificationBeforePassword {
            MyMPSUSettingsCard {
                Label("Подтвердите почту", systemImage: "envelope.badge.fill")
                    .font(.subheadline.weight(.semibold))
                Text(currentUser?.passwordContactEmail ?? currentUser?.pendingPasswordContactEmail ?? "Письмо уже отправлено")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .mympsuTextSelectionEnabled()
                Button {
                    resendContactEmailVerification()
                } label: {
                    contactEmailActionLabel("Отправить письмо ещё раз")
                }
                .disabled(isSendingContactEmail)
                .mympsuInteractiveButtonStyle()
                contactEmailStatusMessages
            }
        }
    }

    private func contactEmailActionLabel(_ title: String) -> some View {
        HStack {
            Label(title, systemImage: "paperplane.fill")
            Spacer(minLength: 0)
            if isSendingContactEmail {
                ProgressView()
            }
        }
        .mympsuDefaultSurface()
    }

    @ViewBuilder
    private var contactEmailStatusMessages: some View {
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
    }

    private var successCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(mode == .setup ? "Пароль создан." : "Пароль изменён.")
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .mympsuDefaultSurface()
    }

    private func passwordField(title: String, placeholder: String, text: Binding<String>, usesNewPasswordContentType: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if usesNewPasswordContentType {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                    .mympsuNewPasswordTextContentType()
                    .disabled(isSaving)
            } else {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                    .textContentType(.password)
                    .disabled(isSaving)
            }
        }
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 4)
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: mode == .setup ? "key.fill" : "arrow.triangle.2.circlepath")
                    Text(title)
                }
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .frame(height: 50)
            .background(Color.mympsuHeaderCapsuleFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.55)
    }

    private var bottomPadding: CGFloat {
#if os(iOS)
        92
#else
        16
#endif
    }

    private func requestContactEmailVerification() {
        let email = contactEmail.mympsuTrimmed
        guard !email.isEmpty, !isSendingContactEmail else { return }
        isSendingContactEmail = true
        contactEmailMessage = nil
        contactEmailErrorMessage = nil
        Task {
            do {
                try await APIService.shared.requestContactEmailVerification(email: email)
                let user = try await APIService.shared.refreshCurrentUser()
                onSuccess(user)
                contactEmailMessage = "Письмо отправлено. Подтвердите email и вернитесь сюда."
            } catch {
                print("[PasswordSetupView] contact email request failed: \(error)")
                contactEmailErrorMessage = contactEmailErrorMessage(for: error)
            }
            isSendingContactEmail = false
        }
    }

    private func resendContactEmailVerification() {
        guard !isSendingContactEmail else { return }
        isSendingContactEmail = true
        contactEmailMessage = nil
        contactEmailErrorMessage = nil
        Task {
            do {
                try await APIService.shared.resendContactEmailVerification()
                let user = try await APIService.shared.refreshCurrentUser()
                onSuccess(user)
                contactEmailMessage = "Письмо отправлено ещё раз."
            } catch {
                print("[PasswordSetupView] contact email resend failed: \(error)")
                contactEmailErrorMessage = contactEmailErrorMessage(for: error)
            }
            isSendingContactEmail = false
        }
    }

    private func contactEmailErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Проверьте подключение и попробуйте ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            if statusCode == 401 {
                return "Сессия истекла. Войдите снова."
            }
            if statusCode == 422 || statusCode == 400 {
                return "Backend не принял email. Проверьте адрес."
            }
        }
        return "Не удалось отправить письмо. Попробуйте ещё раз."
    }

    private func submit() {
        guard canSubmit else { return }
        isSaving = true
        errorMessage = nil
        didSucceed = false
        Task {
            do {
                let user: AppleUser
                switch mode {
                case .setup:
                    user = try await APIService.shared.createPassword(password: password)
                case .change:
                    user = try await APIService.shared.changePassword(currentPassword: currentPassword, newPassword: password)
                }
                onSuccess(user)
                currentPassword = ""
                password = ""
                repeatedPassword = ""
                didSucceed = true
            } catch {
                print("[PasswordSetupView] password operation failed")
                errorMessage = passwordErrorMessage(for: error)
            }
            isSaving = false
        }
    }

    private func passwordErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Проверьте подключение и попробуйте ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error {
            if statusCode == 401 {
                return mode == .change ? "Текущий пароль неверный." : "Сессия истекла. Войдите снова."
            }
            if statusCode == 403 {
                return "Сначала подтвердите контактную почту."
            }
            if [400, 422].contains(statusCode) {
                return "Пароль не принят. Используйте более надёжный пароль."
            }
        }
        return "Не удалось сохранить пароль. Проверьте данные и попробуйте ещё раз."
    }
}

struct PasswordResetView: View {
    let activeTheme: AppTheme

    @Environment(\.presentationMode) private var presentationMode
    @State private var email: String
    @State private var code = ""
    @State private var newPassword = ""
    @State private var repeatedPassword = ""
    @State private var didRequestCode = false
    @State private var didResetPassword = false
    @State private var isSendingCode = false
    @State private var isConfirming = false
    @State private var errorMessage: String?

    init(activeTheme: AppTheme, initialEmail: String) {
        self.activeTheme = activeTheme
        self._email = State(initialValue: initialEmail)
    }

    private var trimmedEmail: String {
        email.mympsuTrimmed
    }

    private var trimmedCode: String {
        code.mympsuTrimmed
    }

    private var isBusy: Bool {
        isSendingCode || isConfirming
    }

    private var passwordValidationMessage: String? {
        guard !newPassword.isEmpty || !repeatedPassword.isEmpty else { return nil }
        if newPassword.count < 8 {
            return "Минимум 8 символов."
        }
        if newPassword != repeatedPassword {
            return "Пароли не совпадают."
        }
        return nil
    }

    private var canRequestCode: Bool {
        trimmedEmail.contains("@") && trimmedEmail.contains(".") && !isBusy
    }

    private var canConfirm: Bool {
        didRequestCode
        && trimmedCode.count == 6
        && trimmedCode.allSatisfy(\.isNumber)
        && passwordValidationMessage == nil
        && newPassword.count >= 8
        && newPassword == repeatedPassword
        && !isBusy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Сброс пароля") {
                presentationMode.wrappedValue.dismiss()
            }
            .disabled(isBusy)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if didResetPassword {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Пароль изменён. Войдите по новому паролю.")
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .mympsuDefaultSurface()
                    }

                    MyMPSUSettingsCard {
                        loginEmailField

                        if didRequestCode {
                            resetCodeField
                            newPasswordField(title: "Новый пароль", placeholder: "Новый пароль", text: $newPassword)
                            newPasswordField(title: "Повторите пароль", placeholder: "Повторите пароль", text: $repeatedPassword)
                        }
                    }

                    if let passwordValidationMessage {
                        message(passwordValidationMessage)
                    } else if let errorMessage {
                        message(errorMessage)
                    }

                    Color.clear.frame(height: 96)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuBottomInset {
            actionButton
                .padding(.horizontal, 16)
                .padding(.bottom, bottomPadding)
        }
    }

    private var loginEmailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Почта")
                .font(.caption)
                .foregroundColor(.secondary)
            ZStack(alignment: .leading) {
                if email.isEmpty {
                    Text("почта")
                        .font(.body.weight(.medium))
                        .foregroundColor(.secondary)
                        .allowsHitTesting(false)
                }
                TextField("", text: $email)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                    .textContentType(.username)
                    .disabled(isBusy || didResetPassword)
#if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled(true)
            }
        }
    }

    private var resetCodeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Код")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("123456", text: $code)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .textContentType(.oneTimeCode)
                .disabled(isBusy || didResetPassword)
#if os(iOS)
                .keyboardType(.numberPad)
#endif
                .onChange(of: code) { value in
                    code = String(value.filter(\.isNumber).prefix(6))
                }
        }
    }

    private func newPasswordField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .mympsuNewPasswordTextContentType()
                .disabled(isBusy || didResetPassword)
        }
    }

    private var actionButton: some View {
        Button {
            if didResetPassword {
                presentationMode.wrappedValue.dismiss()
            } else if didRequestCode {
                confirmReset()
            } else {
                requestReset()
            }
        } label: {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                if isBusy {
                    ProgressView()
                } else {
                    Image(systemName: didResetPassword ? "person.crop.circle.badge.checkmark" : didRequestCode ? "checkmark.seal.fill" : "paperplane.fill")
                    Text(didResetPassword ? "Вернуться ко входу" : didRequestCode ? "Подтвердить" : "Отправить код")
                }
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .frame(height: 50)
            .background(Color.mympsuHeaderCapsuleFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(didResetPassword ? false : didRequestCode ? !canConfirm : !canRequestCode)
        .opacity(didResetPassword || (didRequestCode ? canConfirm : canRequestCode) ? 1 : 0.55)
    }

    private func requestReset() {
        guard canRequestCode else { return }
        isSendingCode = true
        errorMessage = nil
        Task {
            do {
                try await APIService.shared.requestPasswordReset(email: trimmedEmail)
                didRequestCode = true
            } catch {
                print("[PasswordResetView] reset request failed")
                errorMessage = networkErrorMessage(for: error) ?? "Не удалось отправить код. Попробуйте ещё раз."
            }
            isSendingCode = false
        }
    }

    private func confirmReset() {
        guard canConfirm else { return }
        isConfirming = true
        errorMessage = nil
        Task {
            do {
                try await APIService.shared.confirmPasswordReset(code: trimmedCode, newPassword: newPassword)
                didResetPassword = true
            } catch {
                print("[PasswordResetView] reset confirmation failed")
                if let networkMessage = networkErrorMessage(for: error) {
                    errorMessage = networkMessage
                } else if case APIServiceError.httpStatus(let statusCode) = error,
                          [400, 404, 410, 422].contains(statusCode) {
                    errorMessage = statusCode == 422
                    ? "Код неверный или истёк, либо пароль слишком слабый."
                    : "Код неверный или истёк."
                } else {
                    errorMessage = "Не удалось сбросить пароль. Попробуйте ещё раз."
                }
            }
            isConfirming = false
        }
    }

    private func networkErrorMessage(for error: Error) -> String? {
        guard let urlError = error as? URLError, urlError.code != .cancelled else { return nil }
        return "Сеть недоступна. Введённые данные сохранены."
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal, 4)
    }

    private var bottomPadding: CGFloat {
#if os(iOS)
        92
#else
        16
#endif
    }
}

struct EmailChangeView: View {
    let activeTheme: AppTheme
    let currentEmail: String?
    let pendingEmail: String?
    let onBack: () -> Void
    let onSuccess: (AppleUser) -> Void

    @State private var newEmail = ""
    @State private var code = ""
    @State private var isSendingCode = false
    @State private var isConfirming = false
    @State private var showsCodeField: Bool
    @State private var errorMessage: String?

    init(
        activeTheme: AppTheme,
        currentEmail: String?,
        pendingEmail: String?,
        onBack: @escaping () -> Void,
        onSuccess: @escaping (AppleUser) -> Void
    ) {
        self.activeTheme = activeTheme
        self.currentEmail = currentEmail
        self.pendingEmail = pendingEmail
        self.onBack = onBack
        self.onSuccess = onSuccess
        self._showsCodeField = State(initialValue: pendingEmail?.mympsuTrimmed.isEmpty == false)
    }

    private var trimmedEmail: String {
        newEmail.mympsuTrimmed
    }

    private var trimmedCode: String {
        code.mympsuTrimmed
    }

    private var validationMessage: String? {
        guard !trimmedEmail.isEmpty else { return nil }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            return "Введите корректный email."
        }
        return nil
    }

    private var codeValidationMessage: String? {
        guard !trimmedCode.isEmpty else { return nil }
        guard trimmedCode.count == 6, trimmedCode.allSatisfy(\.isNumber) else {
            return "Введите 6-значный код."
        }
        return nil
    }

    private var canSendCode: Bool {
        validationMessage == nil
        && trimmedEmail.contains("@")
        && trimmedEmail.contains(".")
        && !isSendingCode
        && !isConfirming
    }

    private var canConfirm: Bool {
        showsCodeField
        && codeValidationMessage == nil
        && trimmedCode.count == 6
        && !isSendingCode
        && !isConfirming
    }

    private var isBusy: Bool {
        isSendingCode || isConfirming
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Сменить почту") {
                onBack()
            }
            .disabled(isBusy)
#endif

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MyMPSUSettingsCard {
                        Text("Текущая почта: \(currentEmail?.isEmpty == false ? currentEmail ?? "Не указана" : "Не указана")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        textField(title: "Новая почта", placeholder: "email@example.com", text: $newEmail)

                        if let pendingEmail, !pendingEmail.mympsuTrimmed.isEmpty {
                            Text("Ожидает подтверждения: \(pendingEmail)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .mympsuTextSelectionEnabled()
                        }

                        if showsCodeField {
                            codeField
                        }
                    }

                    if let validationMessage {
                        message(validationMessage, color: .red)
                    } else if let codeValidationMessage {
                        message(codeValidationMessage, color: .red)
                    } else if let errorMessage {
                        message(errorMessage, color: .red)
                    }

                    Color.clear.frame(height: 96)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuBottomInset {
            actionButton
                .padding(.horizontal, 16)
                .padding(.bottom, bottomPadding)
        }
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
    }

    private func textField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .disabled(isBusy)
#if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
#endif
                .autocorrectionDisabled(true)
        }
    }

    private var codeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Код подтверждения")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("123456", text: $code)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .disabled(isBusy)
#if os(iOS)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
#endif
                .onChange(of: code) { value in
                    code = String(value.filter(\.isNumber).prefix(6))
                }
        }
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 4)
    }

    private var actionButton: some View {
        Button {
            showsCodeField ? confirmCode() : sendCode()
        } label: {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                if isBusy {
                    ProgressView()
                } else {
                    Image(systemName: showsCodeField ? "checkmark.seal.fill" : "paperplane.fill")
                    Text(showsCodeField ? "Подтвердить" : "Отправить код")
                }
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .frame(height: 50)
            .background(Color.mympsuHeaderCapsuleFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(showsCodeField ? !canConfirm : !canSendCode)
        .opacity((showsCodeField ? canConfirm : canSendCode) ? 1 : 0.55)
    }

    private var bottomPadding: CGFloat {
#if os(iOS)
        92
#else
        16
#endif
    }

    private func sendCode() {
        guard canSendCode else { return }
        isSendingCode = true
        errorMessage = nil
        Task {
            do {
                let user = try await APIService.shared.requestEmailChange(newEmail: trimmedEmail)
                onSuccess(user)
                showsCodeField = true
            } catch {
                print("[EmailChangeView] email change request failed: \(error)")
                errorMessage = emailChangeRequestErrorMessage(for: error)
            }
            isSendingCode = false
        }
    }

    private func confirmCode() {
        guard canConfirm else { return }
        isConfirming = true
        errorMessage = nil
        Task {
            do {
                let user = try await APIService.shared.confirmEmailChange(code: trimmedCode)
                onSuccess(user)
                onBack()
            } catch {
                print("[EmailChangeView] email change confirmation failed")
                errorMessage = emailChangeConfirmationErrorMessage(for: error)
            }
            isConfirming = false
        }
    }

    private func emailChangeRequestErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Проверьте подключение и попробуйте ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error, statusCode == 409 {
            return "Эта почта уже занята. Укажите другую."
        }
        return "Не удалось отправить код. Проверьте почту и попробуйте ещё раз."
    }

    private func emailChangeConfirmationErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Код не сброшен, попробуйте ещё раз."
        }
        if case APIServiceError.httpStatus(let statusCode) = error,
           [400, 404, 410, 422].contains(statusCode) {
            return "Код неверный или истёк. Запросите новый код."
        }
        return "Не удалось подтвердить почту. Попробуйте ещё раз."
    }
}

enum PasswordEditorMode {
    case setup
    case change
}
