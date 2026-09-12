import SwiftUI

struct RoleRequestSection: View {
    var showsContainer = true
    @AppStorage("selectedGroupId") private var selectedGroupIdString = ""
    @AppStorage("selectedGroupName") private var selectedGroupName = ""
    @StateObject private var authSession = AuthSessionManager.shared
    @State private var requests: [RoleRequest] = []
    @State private var isLoading = false
    @State private var actionRoleType: String?
    @State private var message: String?
    @State private var errorMessage: String?

    private var selectedGroupId: Int? {
        Int(selectedGroupIdString)
    }

    private var selectedGroupTitle: String {
        selectedGroupName.mympsuTrimmed.isEmpty ? selectedGroupIdString : selectedGroupName
    }

    private var hasSelectedGroup: Bool {
        selectedGroupId != nil
    }

    private var hasPendingLeaderRequest: Bool {
        guard let selectedGroupId else { return false }
        return requests.contains { request in
            request.roleType == "group_leader"
                && request.groupId == selectedGroupId
                && request.status.lowercased() == "pending"
        }
    }

    private var hasPendingModeratorRequest: Bool {
        requests.contains { request in
            request.roleType == "moderator" && request.status.lowercased() == "pending"
        }
    }

    private var canRequestGroupLeader: Bool {
        guard let selectedGroupId else { return false }
        return authSession.currentUser?.isGroupLeader(for: selectedGroupId) != true
    }

    private var canRequestModerator: Bool {
        guard let user = authSession.currentUser else { return false }
        return !user.isModerator && !user.isAdmin
    }

    var body: some View {
        if authSession.isAuthenticated {
            Group {
                if showsContainer {
                    content
                        .mympsuDefaultSurface()
                        .padding(.horizontal, 4)
                } else {
                    content
                }
            }
            .mympsuTask {
                await loadRequestsIfNeeded()
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Запросить роль", systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if canRequestGroupLeader {
                groupLeaderRequestContent
            }

            if canRequestModerator {
                moderatorRequestContent
            }

            if !canRequestGroupLeader && !canRequestModerator {
                Text("Доступные роли уже активны.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private var groupLeaderRequestContent: some View {
        if !hasSelectedGroup {
            Label("Сначала выберите группу", systemImage: "person.3.fill")
                .font(.caption)
                .foregroundColor(.secondary)
        } else if hasPendingLeaderRequest {
            Label("Заявка на старосту ожидает проверки", systemImage: "clock.fill")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Button {
                createRequest(roleType: "group_leader")
            } label: {
                HStack {
                    Label("Стать старостой моей группы", systemImage: "star.fill")
                    Spacer()
                    if actionRoleType == "group_leader" {
                        ProgressView()
                    } else if !selectedGroupTitle.isEmpty {
                        Text(selectedGroupTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .mympsuDefaultSurface(cornerRadius: 14, padding: 12)
            }
            .disabled(actionRoleType != nil)
            .mympsuInteractiveButtonStyle()
        }
    }

    @ViewBuilder
    private var moderatorRequestContent: some View {
        if hasPendingModeratorRequest {
            Label("Заявка на модератора ожидает проверки", systemImage: "clock.fill")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Button {
                createRequest(roleType: "moderator")
            } label: {
                HStack {
                    Label("Стать модератором", systemImage: "shield.lefthalf.filled")
                    Spacer()
                    if actionRoleType == "moderator" {
                        ProgressView()
                    }
                }
                .mympsuDefaultSurface(cornerRadius: 14, padding: 12)
            }
            .disabled(actionRoleType != nil)
            .mympsuInteractiveButtonStyle()
        }
    }

    private func loadRequestsIfNeeded() async {
        guard requests.isEmpty, !isLoading else { return }
        await loadRequests()
    }

    private func loadRequests() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await APIService.shared.fetchLegacyMyRoleRequests()
            withAnimation(.easeInOut(duration: 0.2)) {
                requests = loaded
            }
        } catch {
            print("[RoleRequestSection] failed to load role requests: \(error)")
            errorMessage = "Не удалось загрузить заявки."
        }
        isLoading = false
    }

    private func createRequest(roleType: String) {
        guard actionRoleType == nil else { return }
        guard roleType != "group_leader" || selectedGroupId != nil else {
            message = "Сначала выберите группу"
            return
        }

        actionRoleType = roleType
        message = nil
        errorMessage = nil
        Task {
            do {
                let request = try await APIService.shared.createRoleRequest(
                    roleType: roleType,
                    groupId: roleType == "group_leader" ? selectedGroupId : nil,
                    groupName: roleType == "group_leader" ? selectedGroupTitle : nil,
                    comment: nil
                )
                withAnimation(.easeInOut(duration: 0.2)) {
                    requests.insert(request, at: 0)
                    message = "Заявка ожидает проверки"
                }
            } catch {
                print("[RoleRequestSection] failed to create role request: \(error)")
                errorMessage = "Не удалось отправить заявку."
            }
            actionRoleType = nil
        }
    }
}

struct RoleRequestView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    var onBack: (() -> Void)? = nil

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Запрос роли") {
                if let onBack {
                    onBack()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
#endif

            RoleRequestSection(showsContainer: false)

            Spacer(minLength: 0)
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
}

struct MyRoleRequestsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    var onBack: (() -> Void)? = nil

    @State private var requests: [RoleRequest] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Мои заявки") {
                if let onBack {
                    onBack()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
#endif

            if isLoading && requests.isEmpty {
                stateCard(systemImage: "hourglass", title: "Загружаем заявки", subtitle: nil)
            } else if let errorMessage, requests.isEmpty {
                stateCard(systemImage: "exclamationmark.triangle.fill", title: errorMessage, subtitle: nil)
                retryButton
            } else if requests.isEmpty {
                stateCard(systemImage: "tray.fill", title: "Заявок пока нет", subtitle: "Когда вы запросите роль, статус появится здесь.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(requests) { request in
                            MyRoleRequestCard(request: request)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuTask {
            await loadRequestsIfNeeded()
        }
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
    }

    private var retryButton: some View {
        Button {
            Task { await loadRequests() }
        } label: {
            Label("Повторить", systemImage: "arrow.clockwise")
        }
        .mympsuInteractiveButtonStyle()
    }

    private func stateCard(systemImage: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .mympsuDefaultSurface()
        .padding(.horizontal, 4)
    }

    private func loadRequestsIfNeeded() async {
        guard requests.isEmpty, !isLoading else { return }
        await loadRequests()
    }

    private func loadRequests() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await APIService.shared.fetchLegacyMyRoleRequests()
            withAnimation(.easeInOut(duration: 0.2)) {
                requests = loaded
            }
        } catch {
            print("[MyRoleRequestsView] failed to load role requests: \(error)")
            errorMessage = "Не удалось загрузить заявки."
        }
        isLoading = false
    }
}

private struct MyRoleRequestCard: View {
    let request: RoleRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: statusSystemImage)
                    .foregroundColor(statusColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(roleTitle(for: request.requestedRole))
                        .font(.subheadline.weight(.semibold))
                    if let groupText {
                        Text(groupText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(statusColor)
            }

            if let message = request.message ?? request.comment, !message.mympsuTrimmed.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let reviewComment = request.reviewComment, !reviewComment.mympsuTrimmed.isEmpty {
                Label(reviewComment, systemImage: "text.bubble.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Создана: \(displayDate(from: request.createdAt))")
                .font(.caption2)
                .foregroundColor(.secondary)

            if let reviewedAt = request.reviewedAt, !reviewedAt.mympsuTrimmed.isEmpty {
                Text("Проверена: \(displayDate(from: reviewedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .mympsuDefaultSurface()
    }

    private var groupText: String? {
        if let groupName = request.groupName, !groupName.mympsuTrimmed.isEmpty {
            return groupName
        }
        if let groupId = request.groupId {
            return "Группа \(groupId)"
        }
        return nil
    }

    private var normalizedStatus: String {
        request.status.lowercased()
    }

    private var statusTitle: String {
        switch normalizedStatus {
        case "pending":
            return "На проверке"
        case "approved":
            return "Одобрена"
        case "rejected":
            return "Отклонена"
        case "cancelled", "canceled":
            return "Отменена"
        default:
            return request.status
        }
    }

    private var statusSystemImage: String {
        switch normalizedStatus {
        case "approved":
            return "checkmark.circle.fill"
        case "rejected":
            return "xmark.circle.fill"
        case "cancelled", "canceled":
            return "minus.circle.fill"
        default:
            return "clock.fill"
        }
    }

    private var statusColor: Color {
        switch normalizedStatus {
        case "approved":
            return .green
        case "rejected":
            return .red
        case "cancelled", "canceled":
            return .secondary
        default:
            return .accentColor
        }
    }

    private func roleTitle(for roleType: String) -> String {
        switch roleType {
        case "admin":
            return "Админ"
        case "moderator":
            return "Модератор"
        case "group_leader":
            return "Староста"
        case "tester":
            return "Тестировщик"
        default:
            return roleType
        }
    }

    private func displayDate(from value: String) -> String {
        let trimmed = value.mympsuTrimmed
        guard !trimmed.isEmpty else { return "не указана" }
        guard let date = Self.iso8601WithFractionalSeconds.date(from: trimmed)
            ?? Self.iso8601WithoutFractionalSeconds.date(from: trimmed)
            ?? Self.backendDateFormatter.date(from: trimmed) else {
            return trimmed.replacingOccurrences(of: "T", with: " ")
        }
        return Self.displayDateFormatter.string(from: date)
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

struct ModerationRoleRequestsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    var onBack: (() -> Void)? = nil
    var toolbarRefreshRequest: Binding<Int>? = nil
    @StateObject private var authSession = AuthSessionManager.shared
    @State private var requests: [RoleRequest] = []
    @State private var groupChangeRequests: [GroupChangeRequestDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var processingRequestId: String?
    @State private var rejectionCommentById: [String: String] = [:]

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    private var canModerateRoles: Bool {
        authSession.currentUser?.isAdmin == true || authSession.currentUser?.isModerator == true
    }

    private var pendingRequests: [RoleRequest] {
        requests.filter { $0.status.lowercased() == "pending" }
    }

    private var pendingGroupChangeRequests: [GroupChangeRequestDTO] {
        groupChangeRequests.filter { $0.status.lowercased() == "pending" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !canModerateRoles {
                stateCard(systemImage: "lock.fill", title: "Нет доступа", subtitle: "Модерация ролей доступна администраторам и модераторам.")
            } else if isLoading && requests.isEmpty {
                stateCard(systemImage: "hourglass", title: "Загружаем заявки", subtitle: nil)
            } else if let errorMessage, requests.isEmpty {
                stateCard(systemImage: "exclamationmark.triangle.fill", title: errorMessage, subtitle: nil)
                retryButton
            } else if pendingRequests.isEmpty && pendingGroupChangeRequests.isEmpty {
                stateCard(systemImage: "checkmark.seal.fill", title: "Нет заявок на проверку", subtitle: nil)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(pendingGroupChangeRequests) { request in
                            groupChangeModerationCard(for: request)
                        }
                        ForEach(pendingRequests) { request in
                            moderationCard(for: request)
                        }
                    }
                    .padding(.bottom, 16)
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
        .mympsuTask {
            await loadRequestsIfNeeded()
        }
        .onChange(of: toolbarRefreshRequest?.wrappedValue ?? 0) { _ in
            guard toolbarRefreshRequest != nil, canModerateRoles else { return }
            Task { await loadRequests() }
        }
    }

    @ViewBuilder
    private var header: some View {
#if os(iOS)
        HStack(spacing: 10) {
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Модерация ролей") {
                if let onBack {
                    onBack()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }

            Spacer()

            if canModerateRoles {
                ThemedChrome(shape: activeTheme.headerShape) {
                    Button {
                        Task { await loadRequests() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                }
                .disabled(isLoading)
                .accessibilityLabel("Обновить заявки")
            }
        }
#else
        EmptyView()
#endif
    }

    private var retryButton: some View {
        Button {
            Task { await loadRequests() }
        } label: {
            Label("Повторить", systemImage: "arrow.clockwise")
        }
        .mympsuInteractiveButtonStyle()
    }

    private func stateCard(systemImage: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .mympsuDefaultSurface()
    }

    private func moderationCard(for request: RoleRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: roleSystemImage(for: request.requestedRole))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.userDisplayName?.mympsuTrimmed.isEmpty == false ? request.userDisplayName ?? request.userId : request.userId)
                        .font(.subheadline.weight(.semibold))
                    if let email = request.userEmail, !email.mympsuTrimmed.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(roleTitle(for: request.requestedRole))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            if let groupText = groupText(for: request) {
                Label(groupText, systemImage: "person.3.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let message = request.message ?? request.comment, !message.mympsuTrimmed.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let reviewComment = request.reviewComment, !reviewComment.mympsuTrimmed.isEmpty {
                Label(reviewComment, systemImage: "text.bubble.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(displayDate(from: request.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)

            TextField("Комментарий к отказу", text: rejectionCommentBinding(for: request.id))
                .textFieldStyle(.roundedBorder)
                .disabled(processingRequestId != nil)

            HStack(spacing: 10) {
                Button {
                    approve(request)
                } label: {
                    Label("Одобрить", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(processingRequestId != nil)

                Button {
                    reject(request)
                } label: {
                    Label("Отклонить", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(processingRequestId != nil)
            }
            .buttonStyle(.bordered)

            if processingRequestId == request.id {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Обновляем заявку")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .mympsuDefaultSurface()
    }

    private func groupChangeModerationCard(for request: GroupChangeRequestDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.userName?.mympsuTrimmed.isEmpty == false ? request.userName ?? request.userId : request.userId)
                        .font(.subheadline.weight(.semibold))
                    if let email = request.userEmail, !email.mympsuTrimmed.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("Смена группы")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Label(groupChangeText(for: request), systemImage: "arrow.right.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)

            if let comment = request.comment, !comment.mympsuTrimmed.isEmpty {
                Text(comment)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(displayDate(from: request.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)

            TextField("Комментарий к отказу", text: rejectionCommentBinding(for: "group-\(request.id)"))
                .textFieldStyle(.roundedBorder)
                .disabled(processingRequestId != nil)

            HStack(spacing: 10) {
                Button {
                    approveGroupChange(request)
                } label: {
                    Label("Одобрить", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(processingRequestId != nil)

                Button {
                    rejectGroupChange(request)
                } label: {
                    Label("Отклонить", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(processingRequestId != nil)
            }
            .buttonStyle(.bordered)

            if processingRequestId == "group-\(request.id)" {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Обновляем заявку")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .mympsuDefaultSurface()
    }

    private func loadRequestsIfNeeded() async {
        guard requests.isEmpty, !isLoading, canModerateRoles else { return }
        await loadRequests()
    }

    private func loadRequests() async {
        guard canModerateRoles else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let roleRequests = APIService.shared.fetchModerationRoleRequests()
            async let groupRequests = APIService.shared.fetchModerationGroupChangeRequests()
            let loadedRoles = try await roleRequests
            let loadedGroups = try await groupRequests
            withAnimation(.easeInOut(duration: 0.2)) {
                requests = loadedRoles
                groupChangeRequests = loadedGroups
            }
        } catch {
            print("[ModerationRoleRequestsView] failed to load role requests: \(error)")
            errorMessage = "Не удалось загрузить заявки."
        }
        isLoading = false
    }

    private func approve(_ request: RoleRequest) {
        process(request) {
            try await APIService.shared.approveRoleRequest(id: request.id)
        }
    }

    private func reject(_ request: RoleRequest) {
        let comment = rejectionCommentById[request.id]?.mympsuTrimmed
        process(request) {
            try await APIService.shared.rejectRoleRequest(
                id: request.id,
                comment: comment?.isEmpty == false ? comment : nil
            )
        }
    }

    private func approveGroupChange(_ request: GroupChangeRequestDTO) {
        processGroupChange(request) {
            try await APIService.shared.approveGroupChangeRequest(id: request.id)
        }
    }

    private func rejectGroupChange(_ request: GroupChangeRequestDTO) {
        let comment = rejectionCommentById["group-\(request.id)"]?.mympsuTrimmed
        processGroupChange(request) {
            try await APIService.shared.rejectGroupChangeRequest(
                id: request.id,
                comment: comment?.isEmpty == false ? comment : nil
            )
        }
    }

    private func process(_ request: RoleRequest, action: @escaping () async throws -> Void) {
        guard processingRequestId == nil else { return }
        processingRequestId = request.id
        errorMessage = nil
        Task {
            do {
                try await action()
                await loadRequests()
            } catch {
                print("[ModerationRoleRequestsView] failed to process role request: \(error)")
                errorMessage = "Не удалось обновить заявку."
            }
            processingRequestId = nil
        }
    }

    private func processGroupChange(_ request: GroupChangeRequestDTO, action: @escaping () async throws -> Void) {
        guard processingRequestId == nil else { return }
        processingRequestId = "group-\(request.id)"
        errorMessage = nil
        Task {
            do {
                try await action()
                await loadRequests()
            } catch {
                print("[ModerationRoleRequestsView] failed to process group change request: \(error)")
                errorMessage = "Не удалось обновить заявку."
            }
            processingRequestId = nil
        }
    }

    private func rejectionCommentBinding(for id: String) -> Binding<String> {
        Binding(
            get: { rejectionCommentById[id] ?? "" },
            set: { rejectionCommentById[id] = $0 }
        )
    }

    private func groupText(for request: RoleRequest) -> String? {
        if let groupName = request.groupName, !groupName.mympsuTrimmed.isEmpty {
            return groupName
        }
        if let groupId = request.groupId {
            return "Группа \(groupId)"
        }
        return nil
    }

    private func groupChangeText(for request: GroupChangeRequestDTO) -> String {
        let current = request.currentGroupName?.mympsuTrimmed.isEmpty == false
            ? request.currentGroupName ?? ""
            : request.currentGroupId.map { "Группа \($0)" } ?? "Группа не выбрана"
        let requested = request.requestedGroupName?.mympsuTrimmed.isEmpty == false
            ? request.requestedGroupName ?? ""
            : "Группа \(request.requestedGroupId)"
        return "\(current) -> \(requested)"
    }

    private func roleTitle(for roleType: String) -> String {
        switch roleType {
        case "admin":
            return "Админ"
        case "moderator":
            return "Модератор"
        case "group_leader":
            return "Староста"
        case "student":
            return "Студент"
        default:
            return roleType
        }
    }

    private func roleSystemImage(for roleType: String) -> String {
        switch roleType {
        case "admin":
            return "crown.fill"
        case "moderator":
            return "shield.lefthalf.filled"
        case "group_leader":
            return "star.fill"
        case "student":
            return "person.fill"
        default:
            return "tag.fill"
        }
    }

    private func displayDate(from value: String) -> String {
        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFallback = ISO8601DateFormatter()

        guard let date = isoWithFractional.date(from: value) ?? isoFallback.date(from: value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
