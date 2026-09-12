import SwiftUI
internal import Combine

@MainActor
final class AdminRuntimeSettingsViewModel: ObservableObject {
    @Published var settings: [AdminRuntimeSetting] = []
    @Published var drafts: [String: RuntimeSettingValue] = [:]
    @Published var isLoading = false
    @Published var processingKey: String?
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let whitelist = Set(["AI_ENABLED", "AI_DAILY_LIMIT", "PERSONA_THEME", "MAINTENANCE_MODE", "SCHEDULE_CACHE_TTL_SECONDS"])

    var visibleSettings: [AdminRuntimeSetting] {
        settings.filter { whitelist.contains($0.key) }.sorted { $0.key < $1.key }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            settings = try await APIService.shared.fetchAdminSettings()
            drafts = Dictionary(uniqueKeysWithValues: visibleSettings.map { ($0.key, $0.value) })
        } catch {
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    func save(key: String) async {
        guard processingKey == nil, let value = drafts[key] else { return }
        processingKey = key
        errorMessage = nil
        successMessage = nil
        do {
            let updated = try await APIService.shared.updateAdminSetting(key: key, value: normalized(value, for: key))
            if let index = settings.firstIndex(where: { $0.key == key }) {
                settings[index] = updated
            } else {
                settings.append(updated)
            }
            drafts[key] = updated.value
            successMessage = "Настройка сохранена."
            if ["AI_ENABLED", "AI_DAILY_LIMIT", "PERSONA_THEME", "MAINTENANCE_MODE", "SCHEDULE_CACHE_TTL_SECONDS"].contains(key) {
                await RuntimeConfigService.shared.refresh(force: true)
            }
        } catch {
            errorMessage = Self.message(for: error)
        }
        processingKey = nil
    }

    private func normalized(_ value: RuntimeSettingValue, for key: String) -> RuntimeSettingValue {
        switch (key, value) {
        case ("AI_DAILY_LIMIT", .int(let value)), ("SCHEDULE_CACHE_TTL_SECONDS", .int(let value)):
            return .int(max(0, value))
        default:
            return value
        }
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
        case 422: return "Backend не принял значение настройки."
        case 404: return "Endpoint настроек пока недоступен."
        default: return "Backend вернул ошибку \(statusCode)."
        }
    }
}

struct AdminRuntimeSettingsView: View {
    let activeTheme: AppTheme
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    let onBack: () -> Void
    var toolbarRefreshRequest: Binding<Int>? = nil

    @StateObject private var viewModel = AdminRuntimeSettingsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statusArea
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuTask { await viewModel.load() }
        .onChange(of: toolbarRefreshRequest?.wrappedValue ?? 0) { _ in
            guard toolbarRefreshRequest != nil else { return }
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var header: some View {
#if os(iOS)
        HStack(spacing: 10) {
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Дебаг") {
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
        if viewModel.isLoading && viewModel.settings.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                Text("Загружаем настройки")
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
    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                AdminLiveActivityDebugSection(scheduleViewModel: scheduleViewModel)

                if !viewModel.isLoading && viewModel.visibleSettings.isEmpty {
                    emptyRuntimeSettingsCard
                } else {
                    ForEach(viewModel.visibleSettings) { setting in
                        AdminRuntimeSettingRow(
                            setting: setting,
                            draft: Binding(
                                get: { viewModel.drafts[setting.key] ?? setting.value },
                                set: { viewModel.drafts[setting.key] = $0 }
                            ),
                            isProcessing: viewModel.processingKey == setting.key,
                            onSave: { Task { await viewModel.save(key: setting.key) } }
                        )
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 24)
        }
    }

    private var emptyRuntimeSettingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.accentColor)
            Text("Runtime-настроек пока нет.")
                .font(.headline)
            Text("Отображаются только whitelisted runtime-настройки.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .mympsuAdaptiveGlassCard(cornerRadius: 16)
    }
}

private struct AdminLiveActivityDebugSection: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @State private var groupName = "Debug group"
    @State private var firstTitle = "Первая пара"
    @State private var firstTeacher = "Преподаватель 1"
    @State private var firstLocation = "101"
    @State private var firstStart = Date().addingTimeInterval(-5 * 60)
    @State private var firstEnd = Date().addingTimeInterval(2 * 60)
    @State private var secondTitle = "Вторая пара"
    @State private var secondTeacher = "Преподаватель 2"
    @State private var secondLocation = "202"
    @State private var secondStart = Date().addingTimeInterval(4 * 60)
    @State private var secondEnd = Date().addingTimeInterval(14 * 60)
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bolt.badge.clock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Лайв активити")
                        .font(.headline)
                    Text("Тест перехода: пара, перерыв, следующая пара.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }

            if !LiveActivityManager.shared.isSupported {
                Label("Live Activities недоступны на этом устройстве или выключены в системе.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }

            labeledTextField("Группа", text: $groupName)

            lessonEditor(
                title: "Пара 1",
                lessonTitle: $firstTitle,
                teacher: $firstTeacher,
                location: $firstLocation,
                start: $firstStart,
                end: $firstEnd
            )

            lessonEditor(
                title: "Пара 2",
                lessonTitle: $secondTitle,
                teacher: $secondTeacher,
                location: $secondLocation,
                start: $secondStart,
                end: $secondEnd
            )

            VStack(spacing: 8) {
                debugButton("Загрузить тестовые пары", systemImage: "calendar.badge.plus", action: applyDebugSchedule)

                HStack(spacing: 8) {
                    debugButton("Пара сейчас", systemImage: "play.fill", action: prepareLessonNow)
                    debugButton("Перерыв сейчас", systemImage: "pause.fill", action: prepareBreakNow)
                }

                debugButton("Остановить Live Activity", systemImage: "stop.fill", isDestructive: true, action: stopActivity)
            }

            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
            }
        }
        .mympsuDefaultSurface(cornerRadius: 18, padding: 14)
    }

    private func lessonEditor(
        title: String,
        lessonTitle: Binding<String>,
        teacher: Binding<String>,
        location: Binding<String>,
        start: Binding<Date>,
        end: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            labeledTextField("Название", text: lessonTitle)

            HStack(spacing: 8) {
                labeledTextField("Преподаватель", text: teacher)
                labeledTextField("Аудитория", text: location)
            }

            HStack(spacing: 8) {
                dateField("Начало", date: start)
                dateField("Конец", date: end)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }

    private func labeledTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func dateField(_ title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            DatePicker(title, selection: date, displayedComponents: [.hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func debugButton(
        _ title: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
        }
        .runtimeDebugButtonStyle()
        .foregroundColor(isDestructive ? .red : nil)
    }

    private func applyDebugSchedule() {
        let range = normalizedRange(start: firstStart, end: firstEnd)
        let secondRange = normalizedRange(start: secondStart, end: secondEnd)
        scheduleViewModel.applyDebugScheduleForLiveActivity(
            groupName: trimmed(groupName, fallback: "Debug group"),
            lessons: [
                ScheduleViewModel.DebugLesson(
                    title: trimmed(firstTitle, fallback: "Первая пара"),
                    teacher: trimmed(firstTeacher, fallback: "Преподаватель"),
                    location: trimmed(firstLocation, fallback: "Аудитория"),
                    start: range.start,
                    end: range.end
                ),
                ScheduleViewModel.DebugLesson(
                    title: trimmed(secondTitle, fallback: "Вторая пара"),
                    teacher: trimmed(secondTeacher, fallback: "Преподаватель"),
                    location: trimmed(secondLocation, fallback: "Аудитория"),
                    start: secondRange.start,
                    end: secondRange.end
                )
            ]
        )
        statusMessage = "Тестовые пары загружены в реальный поток расписания."
    }

    private func prepareLessonNow() {
        let now = Date()
        firstStart = now.addingTimeInterval(-5 * 60)
        firstEnd = now.addingTimeInterval(2 * 60)
        secondStart = now.addingTimeInterval(4 * 60)
        secondEnd = now.addingTimeInterval(14 * 60)
        applyDebugSchedule()
    }

    private func prepareBreakNow() {
        let now = Date()
        firstStart = now.addingTimeInterval(-12 * 60)
        firstEnd = now.addingTimeInterval(-2 * 60)
        secondStart = now.addingTimeInterval(3 * 60)
        secondEnd = now.addingTimeInterval(13 * 60)
        applyDebugSchedule()
    }

    private func stopActivity() {
        LiveActivityManager.shared.endIfNeeded()
        statusMessage = "Live Activity остановлена."
    }

    private func normalizedRange(start: Date, end: Date) -> (start: Date, end: Date) {
        if end > start {
            return (start, end)
        }
        return (start, start.addingTimeInterval(45 * 60))
    }

    private func trimmed(_ value: String, fallback: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? fallback : trimmedValue
    }
}

private struct AdminRuntimeSettingRow: View {
    let setting: AdminRuntimeSetting
    @Binding var draft: RuntimeSettingValue
    let isProcessing: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(setting.key)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            editor

            Button("Сохранить", action: onSave)
                .font(.caption.weight(.semibold))
                .disabled(isProcessing || draft == setting.value)
        }
        .mympsuDefaultSurface(cornerRadius: 16, padding: 12)
    }

    @ViewBuilder
    private var editor: some View {
        switch draft {
        case .bool:
            Toggle("Значение", isOn: boolBinding)
        case .int:
            TextField("0", text: intBinding)
                .textFieldStyle(.roundedBorder)
#if os(iOS)
                .keyboardType(.numberPad)
#endif
        case .string:
            if setting.key == "PERSONA_THEME" {
                Picker("Значение", selection: stringBinding) {
                    Text("auto").tag("auto")
                    Text("pelikasha").tag("pelikasha")
                    Text("stesha").tag("stesha")
                }
                .pickerStyle(.segmented)
            } else {
                TextField("Значение", text: stringBinding)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                if case .bool(let value) = draft { return value }
                return false
            },
            set: { draft = .bool($0) }
        )
    }

    private var intBinding: Binding<String> {
        Binding(
            get: {
                if case .int(let value) = draft { return String(max(0, value)) }
                return "0"
            },
            set: { draft = .int(max(0, Int($0.filter(\.isNumber)) ?? 0)) }
        )
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: {
                if case .string(let value) = draft { return value }
                return ""
            },
            set: { draft = .string($0) }
        )
    }

    private var title: String {
        switch setting.key {
        case "AI_ENABLED": return "AI включён"
        case "AI_DAILY_LIMIT": return "Дневной лимит AI"
        case "PERSONA_THEME": return "Тема персонажа"
        case "MAINTENANCE_MODE": return "Режим техработ"
        case "SCHEDULE_CACHE_TTL_SECONDS": return "TTL кэша расписания"
        default: return setting.key
        }
    }
}

private struct RuntimeDebugButtonStyleModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        if #available(macOS 12.0, *) {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
#else
        content.buttonStyle(.borderedProminent)
#endif
    }
}

private extension View {
    func runtimeDebugButtonStyle() -> some View {
        modifier(RuntimeDebugButtonStyleModifier())
    }
}
