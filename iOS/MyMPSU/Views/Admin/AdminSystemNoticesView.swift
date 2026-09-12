import SwiftUI
internal import Combine

@MainActor
final class AdminSystemNoticesViewModel: ObservableObject {
    @Published var notices: [SystemNotice] = []
    @Published var isLoading = false
    @Published var processingId: Int?
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            notices = try await APIService.shared.fetchAdminSystemNotices()
        } catch {
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    func create(from draft: SystemNoticeDraft) async {
        await mutate(success: "Уведомление создано.") {
            _ = try await APIService.shared.createAdminSystemNotice(draft.payload)
        }
    }

    func update(id: Int, from draft: SystemNoticeDraft) async {
        await mutate(id: id, success: "Уведомление сохранено.") {
            _ = try await APIService.shared.updateAdminSystemNotice(id: id, payload: draft.payload)
        }
    }

    func delete(_ notice: SystemNotice) async {
        await mutate(id: notice.id, success: "Уведомление удалено.") {
            try await APIService.shared.deleteAdminSystemNotice(id: notice.id)
        }
    }

    func setActive(_ notice: SystemNotice, active: Bool) async {
        await mutate(id: notice.id, success: active ? "Уведомление активировано." : "Уведомление деактивировано.") {
            if active {
                try await APIService.shared.activateAdminSystemNotice(id: notice.id)
            } else {
                try await APIService.shared.deactivateAdminSystemNotice(id: notice.id)
            }
        }
    }

    private func mutate(id: Int? = nil, success: String, action: () async throws -> Void) async {
        guard processingId == nil else { return }
        processingId = id ?? -1
        errorMessage = nil
        successMessage = nil
        do {
            try await action()
            await load()
            await RuntimeConfigService.shared.refresh(force: true)
            successMessage = success
        } catch {
            errorMessage = Self.message(for: error)
        }
        processingId = nil
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
        return "Не удалось выполнить действие."
    }

    private static func message(forHTTPStatus statusCode: Int) -> String {
        switch statusCode {
        case 401, 403: return "Недостаточно прав для админки."
        case 422: return "Backend не принял данные уведомления."
        case 404: return "Endpoint уведомлений пока недоступен."
        default: return "Backend вернул ошибку \(statusCode)."
        }
    }
}

struct SystemNoticeDraft: Equatable {
    var title = ""
    var message = ""
    var type: SystemNoticeType = .info
    var showAs: SystemNoticePresentation = .banner
    var dismissible = true
    var startsAt = ""
    var endsAt = ""

    init() {}

    init(notice: SystemNotice) {
        title = notice.title
        message = notice.message
        type = notice.type
        showAs = notice.showAs
        dismissible = notice.dismissible
        startsAt = notice.startsAt ?? ""
        endsAt = notice.endsAt ?? ""
    }

    var payload: SystemNoticeMutationRequest {
        SystemNoticeMutationRequest(
            title: title.mympsuTrimmed,
            message: message.mympsuTrimmed,
            type: type,
            showAs: showAs,
            dismissible: dismissible,
            startsAt: startsAt.mympsuTrimmed.isEmpty ? nil : startsAt.mympsuTrimmed,
            endsAt: endsAt.mympsuTrimmed.isEmpty ? nil : endsAt.mympsuTrimmed
        )
    }

    var isValid: Bool {
        !title.mympsuTrimmed.isEmpty && !message.mympsuTrimmed.isEmpty
    }
}

struct AdminSystemNoticesView: View {
    let activeTheme: AppTheme
    let onBack: () -> Void
    var toolbarRefreshRequest: Binding<Int>? = nil

    @StateObject private var viewModel = AdminSystemNoticesViewModel()
    @State private var draft = SystemNoticeDraft()
    @State private var editingNotice: SystemNotice?
    @State private var pendingDelete: SystemNotice?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statusArea
            editor
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuTask { await viewModel.load() }
        .alert(isPresented: deleteAlertBinding) {
            Alert(
                title: Text("Удалить уведомление?"),
                message: Text("Это действие нельзя отменить."),
                primaryButton: .destructive(Text("Удалить")) {
                    guard let pendingDelete else { return }
                    self.pendingDelete = nil
                    Task { await viewModel.delete(pendingDelete) }
                },
                secondaryButton: .cancel(Text("Отмена")) {
                    pendingDelete = nil
                }
            )
        }
        .onChange(of: toolbarRefreshRequest?.wrappedValue ?? 0) { _ in
            guard toolbarRefreshRequest != nil else { return }
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var header: some View {
#if os(iOS)
        HStack(spacing: 10) {
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Уведомления") {
                onBack()
            }
            Spacer(minLength: 0)
            Button {
                Task { await viewModel.load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .mympsuDefaultSurface(cornerRadius: 18, padding: 0)
            .disabled(viewModel.isLoading)
        }
#else
        EmptyView()
#endif
    }

    @ViewBuilder
    private var statusArea: some View {
        if viewModel.isLoading && viewModel.notices.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                Text("Загружаем уведомления")
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

    private var editor: some View {
        MyMPSUSettingsCard {
            HStack {
                Label(editingNotice == nil ? "Новое уведомление" : "Редактирование", systemImage: "megaphone.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                if editingNotice != nil {
                    Button("Сброс") {
                        editingNotice = nil
                        draft = SystemNoticeDraft()
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            TextField("Заголовок", text: $draft.title)
                .textFieldStyle(.roundedBorder)
            TextField("Сообщение", text: $draft.message)
                .textFieldStyle(.roundedBorder)

            Picker("Тип", selection: $draft.type) {
                ForEach(SystemNoticeType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Picker("Показ", selection: $draft.showAs) {
                ForEach(SystemNoticePresentation.allCases) { presentation in
                    Text(presentation.title).tag(presentation)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Можно скрыть", isOn: $draft.dismissible)

            TextField("startsAt, опционально", text: $draft.startsAt)
                .textFieldStyle(.roundedBorder)
            TextField("endsAt, опционально", text: $draft.endsAt)
                .textFieldStyle(.roundedBorder)

            Button(editingNotice == nil ? "Создать" : "Сохранить") {
                let currentDraft = draft
                if let editingNotice {
                    Task { await viewModel.update(id: editingNotice.id, from: currentDraft) }
                } else {
                    Task { await viewModel.create(from: currentDraft) }
                }
                editingNotice = nil
                draft = SystemNoticeDraft()
            }
            .font(.caption.weight(.semibold))
            .disabled(!draft.isValid || viewModel.processingId != nil)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.isLoading && viewModel.notices.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.accentColor)
                Text("Уведомлений пока нет.")
                    .font(.headline)
                Text("Создайте баннер или модальное предупреждение для пользователей.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .mympsuAdaptiveGlassCard(cornerRadius: 16)
            .padding(.horizontal, 4)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.notices) { notice in
                        AdminSystemNoticeCard(
                            notice: notice,
                            isProcessing: viewModel.processingId == notice.id,
                            onEdit: {
                                editingNotice = notice
                                draft = SystemNoticeDraft(notice: notice)
                            },
                            onActivate: { Task { await viewModel.setActive(notice, active: true) } },
                            onDeactivate: { Task { await viewModel.setActive(notice, active: false) } },
                            onDelete: { pendingDelete = notice }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 24)
            }
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }
}

private struct AdminSystemNoticeCard: View {
    let notice: SystemNotice
    let isProcessing: Bool
    let onEdit: () -> Void
    let onActivate: () -> Void
    let onDeactivate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(notice.title)
                        .font(.subheadline.weight(.semibold))
                    Text(notice.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                statusChip
            }

            HStack(spacing: 6) {
                Text(notice.type.title)
                Text(notice.showAs.title)
                Text(notice.dismissible ? "Скрываемое" : "Обязательное")
            }
            .font(.caption2.weight(.semibold))
            .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Button("Изменить", action: onEdit)
                if notice.isActive == true {
                    Button("Деактивировать", action: onDeactivate)
                        .foregroundColor(.red)
                } else {
                    Button("Активировать", action: onActivate)
                }
                Button("Удалить", action: onDelete)
                    .foregroundColor(.red)
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.75)
                }
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.semibold))
            .disabled(isProcessing)
        }
        .mympsuDefaultSurface(cornerRadius: 16, padding: 12)
    }

    private var statusChip: some View {
        Text(notice.isActive == true ? "active" : "inactive")
            .font(.caption2.weight(.bold))
            .foregroundColor(notice.isActive == true ? .green : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background((notice.isActive == true ? Color.green : Color.secondary).opacity(0.12))
            .clipShape(Capsule())
    }

    private var symbolName: String {
        switch notice.type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch notice.type {
        case .info: return .accentColor
        case .warning: return Color(red: 0.90, green: 0.58, blue: 0.18)
        case .maintenance: return Color(red: 0.40, green: 0.58, blue: 0.95)
        case .critical: return .red
        }
    }
}
