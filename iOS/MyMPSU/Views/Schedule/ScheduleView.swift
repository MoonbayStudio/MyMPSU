import SwiftUI
internal import Combine

#if os(macOS)
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#elseif os(iOS)
struct VisualEffectView: UIViewRepresentable {
    var material: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: material))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
#endif

enum HomeworkButtonState: Equatable {
    case hidden
    case unavailable
    case add
    case view
    case edit

    var title: String {
        switch self {
        case .hidden:
            return ""
        case .unavailable:
            return "Домашки нет"
        case .add:
            return "Добавить домашку"
        case .view:
            return "Домашка"
        case .edit:
            return "Изменить домашку"
        }
    }

    var isEnabled: Bool {
        switch self {
        case .hidden, .unavailable:
            return false
        case .add, .view, .edit:
            return true
        }
    }
}

struct ScheduleView: View {
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @AppStorage("selectedGroupId") private var defaultGroupId = ""
    @Environment(\.mympsuSurfaceStrokeOpacity) private var strokeOpacity
    @StateObject private var authSession = AuthSessionManager.shared
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var selectedDate: Date
    var groupId: String
    var examOnly: Bool = false
    var onScrollChromeChange: (_ topChromeVisible: Bool, _ bottomIslandVisible: Bool) -> Void = { _, _ in }
    var externalRefreshRequest: Int = 0
    @State private var showHomeworkUnavailable = false
    @State private var homeworksByLessonKey: [String: Homework] = [:]
    @State private var selectedHomeworkSheet: HomeworkSheetSelection?
    @State private var homeworkErrorMessage: String?
    @State private var refreshNotice: ScheduleRefreshNotice?
    @State private var refreshNoticeID = UUID()
    @State private var showLastCachedDayWarning = false
    @State private var lastContentTopY: CGFloat?

    private static let homeworkDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    private var isDisplayingRequestedSchedule: Bool {
        viewModel.isDisplayingSchedule(groupId: groupId, date: selectedDate, examOnly: examOnly)
    }

    private var visibleItems: [ScheduleItem] {
        isDisplayingRequestedSchedule ? viewModel.items : []
    }

    private var visibleAnimatedItems: [ScheduleItem] {
        isDisplayingRequestedSchedule ? viewModel.animatedItems : []
    }

    private var isWaitingForRequestedSchedule: Bool {
        !groupId.isEmpty && !isDisplayingRequestedSchedule
    }

    private var isLoadingRequestedSchedule: Bool {
        viewModel.isLoading && !isWaitingForRequestedSchedule
    }

    private var scheduleSurfaceFill: Color {
        activeTheme.usesCloudSurface ? activeTheme.cloudSurfaceFill : Color.mympsuHeaderCapsuleFill
    }

    private var scheduleSurfaceStroke: Color {
        activeTheme.usesCloudSurface
            ? activeTheme.cloudSurfaceStroke
            : Color.mympsuSurfaceStrokeBase.opacity(strokeOpacity)
    }

#if os(macOS)
    @ViewBuilder
    private var macScheduleCardBackground: some View {
        scheduleSurfaceFill
    }

    private var macScheduleCardStroke: Color {
        scheduleSurfaceStroke
    }

    private var macScheduleCardCornerRadius: CGFloat {
        16
    }
#endif

    private var currentGroupId: Int? {
        Int(groupId)
    }

    private var homeworkGroupId: Int? {
        Int(defaultGroupId.mympsuTrimmed) ?? currentGroupId
    }

    private var isViewingDefaultGroupSchedule: Bool {
        guard let currentGroupId else { return false }
        guard let defaultGroupId = Int(defaultGroupId.mympsuTrimmed) else { return false }
        return currentGroupId == defaultGroupId
    }

    private var shouldShowHomeworkControls: Bool {
        !examOnly && isViewingDefaultGroupSchedule
    }

    private var selectedLessonDateString: String {
        Self.homeworkDateFormatter.string(from: selectedDate)
    }

    private var canManageHomeworkForSelectedGroup: Bool {
        guard shouldShowHomeworkControls, let currentUser = authSession.currentUser else { return false }
        return currentUser.isAdmin || currentUser.isModerator || currentUser.isGroupLeader
    }

    var body: some View {
    // macOS
    #if os(macOS)
        VStack(spacing: 0) {
            if groupId.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                    Text("Выбери группу")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .padding()
                .background(macScheduleCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous).stroke(macScheduleCardStroke, lineWidth: 0.8))
                .mympsuGlass(in: RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous))
                .shadow(radius: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isWaitingForRequestedSchedule {
                scheduleSwapPlaceholder
                    .transition(.opacity)
            } else if isLoadingRequestedSchedule {
                VStack(spacing: 16) {
                    VStack {
                        if #available(macOS 12.0, *) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.accentColor)
                        } else {
                            // Fallback on earlier versions
                            ProgressView()
                                .scaleEffect(1.5)
                            // .tint not available, so just omit
                        }
                    }
                    Text("Загружаем пары...")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .padding()
                .background(macScheduleCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous).stroke(macScheduleCardStroke, lineWidth: 0.8))
                .mympsuGlass(in: RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous))
                .shadow(radius: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                    Text(
                        viewModel.hasOfflineCacheMissForSelectedDay
                        ? "Нет подключения к API, и пары на выбранный день не загружены в кэш."
                        : (viewModel.hasConnectionError
                           ? "Ошибка подключения. Выключи VPN и обнови расписание."
                           : "Нет пар на выбранную дату")
                    )
                        .foregroundColor(.secondary)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(macScheduleCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous).stroke(macScheduleCardStroke, lineWidth: 0.8))
                .mympsuGlass(in: RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous))
                .shadow(radius: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                if #available(macOS 13.0, *) {
                    HStack {
                        Spacer()
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(visibleAnimatedItems) { item in
                                    VStack(alignment: .leading, spacing: 8) {
                                        if !item.period.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text(item.period)
                                                .font(.title2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                        }
                                        HStack {
                                            Text(item.time)
                                                .font(.title3)
                                                .bold()
                                            Spacer()
                                            Text(item.subgroup ?? "")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        if let classURL = item.classURL, let url = URL(string: classURL) {
                                            Link(destination: url) {
                                                Text(item.title)
                                                    .font(.title3)
                                                    .bold()
                                                    .underline()
                                            }
                                        } else {
                                            Text(item.title)
                                                .font(.title3)
                                                .bold()
                                        }
                                        HStack(spacing: 6) {
                                            Image(systemName: "pencil")
                                            Text(item.lessonType)
                                        }
                                        .font(.subheadline)
                                        if !item.teacher.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            HStack(spacing: 6) {
                                                Image(systemName: "person.fill")
                                                Text(item.teacher)
                                            }
                                            .font(.subheadline)
                                        }
                                        if !item.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            HStack(spacing: 6) {
                                                Image(systemName: "mappin.and.ellipse")
                                                Text(item.address)
                                            }
                                            .font(.footnote)
                                        }
                                        HStack(spacing: 8) {
                                            Text(item.room)
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)

                                            Spacer(minLength: 0)

                                            if macHomeworkButtonTitle(for: item) != nil {
                                                Button {
                                                    openHomeworkSheet(for: item)
                                                } label: {
                                                    Label(macHomeworkButtonTitle(for: item) ?? "Домашка", systemImage: macHomeworkButtonIcon(for: item))
                                                        .font(.caption.weight(.semibold))
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background(scheduleSurfaceFill)
                                                        .clipShape(Capsule())
                                                        .overlay(Capsule().stroke(scheduleSurfaceStroke, lineWidth: 0.8))
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(!macHomeworkButtonEnabled(for: item))
                                                .opacity(macHomeworkButtonEnabled(for: item) ? 1 : 0.62)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .mympsuTextSelectionEnabled()
                                    .background(macScheduleCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous).stroke(macScheduleCardStroke, lineWidth: 0.8))
                                    .mympsuGlass(in: RoundedRectangle(cornerRadius: macScheduleCardCornerRadius, style: .continuous))
                                }
                                Spacer().frame(height: 16)
                            }
                            .padding(.top,20)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .scrollContentBackground(.hidden)
                        }
                        .padding(.bottom, 16)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) // 👈 добавлено
                        
                        Spacer()
                    }
                    .transition(.opacity)
                } else {
                    // Fallback on earlier versions
                }
            }
        }
        .id(selectedDate)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .alert(isPresented: $showHomeworkUnavailable) {
            Alert(
                title: Text("Домашка"),
                message: Text(homeworkErrorMessage ?? "Домашки для этой пары пока нет."),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(item: $selectedHomeworkSheet) { selection in
            homeworkSheet(for: selection)
        }
        .onChange(of: selectedDate) { _ in
            Task {
                await loadHomeworksForSelectedDate()
            }
        }
        .onChange(of: groupId) { _ in
            selectedHomeworkSheet = nil
            Task {
                await loadHomeworksForSelectedDate()
            }
        }
        .onChange(of: defaultGroupId) { _ in
            selectedHomeworkSheet = nil
            Task {
                await loadHomeworksForSelectedDate()
            }
        }
        .onAppear {
            guard !groupId.isEmpty else { return }
            Task {
                await viewModel.loadOnce(groupId: groupId, date: selectedDate, examOnly: examOnly)
                await loadHomeworksForSelectedDate()
            }
        }
                        // iOS
    #else
    ZStack(alignment: .top) {
        VStack(spacing: 12) {
            VStack {
                if groupId.isEmpty {
                    centeredScheduleState {
                        scheduleStateCard(systemImage: "person.3.fill", message: "Выбери группу")
                    }
                } else if isWaitingForRequestedSchedule {
                    scheduleSwapPlaceholder
                        .transition(.opacity)
                } else if isLoadingRequestedSchedule {
                    centeredScheduleState {
                        loadingStateCard
                    }
                } else if visibleItems.isEmpty {
                    GeometryReader { geometry in
                        ScrollView {
                            scheduleStateCard(
                                systemImage: "calendar.badge.exclamationmark",
                                message: viewModel.hasOfflineCacheMissForSelectedDay
                                    ? "Нет подключения к API, и пары на выбранный день не загружены в кэш."
                                    : (viewModel.hasConnectionError
                                       ? connectionErrorMessage
                                       : emptyScheduleMessage)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: geometry.size.height, alignment: .center)
                        }
                        .refreshable {
                            await performManualRefresh()
                        }
                    }
                    .transition(.opacity)
                } else {
                    Group {
                        if #available(iOS 16.0, *) {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    scrollChromeSensor
                                    ForEach(visibleAnimatedItems) { item in
                                        ScheduleItemCard(
                                            item: item,
                                            homeworkButtonState: homeworkButtonState(for: item)
                                        ) {
                                            openHomeworkSheet(for: item)
                                        }
                                    }
                                    Spacer().frame(height: 128)
                                }
                                .padding(.top, 60)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .scrollContentBackground(.hidden)
                            }
                            .coordinateSpace(name: scrollCoordinateSpaceName)
                            .onPreferenceChange(ScheduleScrollTopPreferenceKey.self) { topY in
                                handleScrollTopChange(topY)
                            }
                            .refreshable {
                                await performManualRefresh()
                            }
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    scrollChromeSensor
                                    ForEach(visibleAnimatedItems) { item in
                                        ScheduleItemCard(
                                            item: item,
                                            homeworkButtonState: homeworkButtonState(for: item)
                                        ) {
                                            openHomeworkSheet(for: item)
                                        }
                                    }
                                    Spacer().frame(height: 128)
                                }
                                .padding(.top, 60)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                            }
                            .coordinateSpace(name: scrollCoordinateSpaceName)
                            .onPreferenceChange(ScheduleScrollTopPreferenceKey.self) { topY in
                                handleScrollTopChange(topY)
                            }
                            .refreshable {
                                await performManualRefresh()
                            }
                        }
                    }
                    .id("\(selectedDate.timeIntervalSinceReferenceDate)-\(groupId)-\(examOnly)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.14), value: isDisplayingRequestedSchedule)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .zIndex(0)
        .id("\(groupId)-\(examOnly)")
    }
    .background(Color.clear)
    .alert("Домашка", isPresented: $showHomeworkUnavailable) {
        Button("OK", role: .cancel) {}
    } message: {
        Text(homeworkErrorMessage ?? "Домашки для этой пары пока нет.")
    }
    .alert("Последний день в кэше", isPresented: $showLastCachedDayWarning) {
        Button("OK", role: .cancel) {}
    } message: {
        Text("Это последний день, сохранённый в кэше. Включите интернет или выключите VPN, чтобы сохранить следующие недели.")
    }
    .sheet(item: $selectedHomeworkSheet) { selection in
        homeworkSheet(for: selection)
    }
    .overlay(alignment: .top) {
        if let refreshNotice {
            refreshNoticeView(refreshNotice)
                .padding(.top, 88)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    .onChange(of: selectedDate) { _ in
        Task {
            await loadHomeworksForSelectedDate()
        }
    }
    .onChange(of: groupId) { _ in
        selectedHomeworkSheet = nil
        Task {
            await loadHomeworksForSelectedDate()
        }
    }
    .onChange(of: defaultGroupId) { _ in
        selectedHomeworkSheet = nil
        Task {
            await loadHomeworksForSelectedDate()
        }
    }
    .onChange(of: externalRefreshRequest) { _ in
        Task {
            await performManualRefresh()
        }
    }
    .onAppear {
        guard !groupId.isEmpty else { return }
        lastContentTopY = nil
        onScrollChromeChange(true, true)
        if examOnly {
            viewModel.loadSessionFromCache(groupId: groupId)
        } else {
            // Tab switches already trigger loading in ContentView.
            // Keep onAppear only for first entrance to schedule content.
            guard viewModel.items.isEmpty, viewModel.animatedItems.isEmpty, !viewModel.isLoading else { return }
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard viewModel.items.isEmpty, viewModel.animatedItems.isEmpty, !viewModel.isLoading else {
                    await loadHomeworksForSelectedDate()
                    return
                }
                viewModel.animatedItems.removeAll()
                await viewModel.loadOnce(groupId: groupId, date: selectedDate, examOnly: false)
                await loadHomeworksForSelectedDate()
            }
        }
    }
#endif
    }

    private struct ScheduleRefreshNotice {
        let message: String
        let systemImage: String
        let color: Color
    }

    private var scheduleSwapPlaceholder: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }

#if os(iOS)
    private var scrollCoordinateSpaceName: String {
        "schedule-scroll-\(groupId)-\(examOnly)"
    }

    private var scrollChromeSensor: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ScheduleScrollTopPreferenceKey.self,
                value: proxy.frame(in: .named(scrollCoordinateSpaceName)).minY
            )
        }
        .frame(height: 1)
    }

    private var connectionErrorMessage: String {
        "Ошибка подключения. Выключи VPN и нажми «Обновить» в островке."
    }

    private var emptyScheduleMessage: String {
        if examOnly {
            return "Сессия пуста. Нажми «Обновить» в островке."
        }

        return "Нет пар на выбранную дату"
    }

    private func handleScrollTopChange(_ topY: CGFloat) {
        guard topY.isFinite else { return }
        if let lastContentTopY, abs(topY - lastContentTopY) < 1 {
            return
        }

        lastContentTopY = topY
        let topChromeVisible = topY > 42
        let bottomIslandVisible = topY > 42
        onScrollChromeChange(topChromeVisible, bottomIslandVisible)
    }

    private func performManualRefresh() async {
        let groupIdToLoad = groupId
        guard !groupIdToLoad.isEmpty else { return }
        let result = await viewModel.manualRefresh(groupId: groupIdToLoad, date: selectedDate, examOnly: examOnly)
        await loadHomeworksForSelectedDate()
        viewModel.animatedItems = viewModel.items.sorted(by: { $0.time < $1.time })
        switch result {
        case .success:
            showRefreshNotice(ScheduleRefreshNotice(message: "Обновлено", systemImage: "checkmark.circle.fill", color: .green))
        case .failure:
            showRefreshNotice(ScheduleRefreshNotice(message: "Нет интернета или API недоступно", systemImage: "xmark.circle.fill", color: .red))
        case .lastCachedDayExtensionFailed:
            showRefreshNotice(ScheduleRefreshNotice(message: "Не удалось продлить кэш", systemImage: "xmark.circle.fill", color: .red))
            showLastCachedDayWarning = true
        }
    }

    private func showRefreshNotice(_ notice: ScheduleRefreshNotice) {
        let noticeID = UUID()
        withAnimation(.easeInOut(duration: 0.18)) {
            refreshNoticeID = noticeID
            refreshNotice = notice
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard refreshNoticeID == noticeID else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                refreshNotice = nil
            }
        }
    }

    private func refreshNoticeView(_ notice: ScheduleRefreshNotice) -> some View {
        HStack(spacing: 8) {
            Image(systemName: notice.systemImage)
                .foregroundColor(notice.color)
            Text(notice.message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.mympsuHeaderCapsuleFill)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    @ViewBuilder
    private func centeredScheduleState<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var loadingStateCard: some View {
        VStack(spacing: 16) {
            VStack {
                if #available(iOS 14.0, *) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.accentColor)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            Text("Загружаю пары...")
                .foregroundColor(.secondary)
                .font(.title3)
        }
        .padding()
        .mympsuStateCard(cornerRadius: 20, shadowRadius: 5)
    }

    private func scheduleStateCard(systemImage: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text(message)
                .foregroundColor(.secondary)
                .font(.title3)
                .multilineTextAlignment(.center)
        }
        .padding()
        .mympsuStateCard(cornerRadius: 20, shadowRadius: 5)
    }
#endif

    private func homeworkButtonState(for item: ScheduleItem) -> HomeworkButtonState {
        guard shouldShowHomeworkControls else { return .hidden }
        let homework = homework(for: item)
        if homework != nil {
            return canManageHomeworkForSelectedGroup ? .edit : .view
        }
        return canManageHomeworkForSelectedGroup ? .add : .unavailable
    }

    private func macHomeworkButtonTitle(for item: ScheduleItem) -> String? {
        switch homeworkButtonState(for: item) {
        case .hidden:
            return nil
        case .unavailable:
            return "Домашки нет"
        case .add:
            return "Добавить домашку"
        case .view:
            return "Домашка"
        case .edit:
            return "Изменить домашку"
        }
    }

    private func macHomeworkButtonIcon(for item: ScheduleItem) -> String {
        switch homeworkButtonState(for: item) {
        case .add:
            return "plus.circle.fill"
        case .edit:
            return "pencil.circle.fill"
        case .view:
            return "doc.text.fill"
        case .unavailable, .hidden:
            return "doc.text"
        }
    }

    private func macHomeworkButtonEnabled(for item: ScheduleItem) -> Bool {
        homeworkButtonState(for: item).isEnabled
    }

    private func homeworkSheet(for selection: HomeworkSheetSelection) -> some View {
        HomeworkSheet(
            lesson: selection.lesson,
            lessonDate: selectedLessonDateString,
            homework: selection.homework,
            canEdit: canManageHomeworkForSelectedGroup,
            onSave: { text in
                try await saveHomework(for: selection.lesson, existing: selection.homework, text: text)
            },
            onDelete: {
                if let homework = selection.homework {
                    try await deleteHomework(homework)
                }
            }
        )
    }

    private func openHomeworkSheet(for item: ScheduleItem) {
        guard shouldShowHomeworkControls else { return }
        let homework = homework(for: item)
        guard canManageHomeworkForSelectedGroup || homework != nil else {
            homeworkErrorMessage = "Домашки для этой пары пока нет."
            showHomeworkUnavailable = true
            return
        }
        selectedHomeworkSheet = HomeworkSheetSelection(lesson: item, homework: homework)
    }

    private func homework(for item: ScheduleItem) -> Homework? {
        homeworksByLessonKey[homeworkKey(date: selectedLessonDateString, time: item.time, subject: item.title)]
    }

    private func homeworkKey(date: String, time: String, subject: String) -> String {
        "\(date)|\(time.mympsuTrimmed)|\(subject.mympsuTrimmed)"
    }

    private func loadHomeworksForSelectedDate() async {
        guard shouldShowHomeworkControls else {
            homeworksByLessonKey = [:]
            homeworkErrorMessage = nil
            return
        }
        guard let groupId = homeworkGroupId else { return }
        do {
            let homeworks = try await APIService.shared.fetchGroupHomeworks(groupId: groupId, date: selectedLessonDateString)
            homeworksByLessonKey = Dictionary(uniqueKeysWithValues: homeworks.map {
                (homeworkKey(date: $0.lessonDate, time: $0.lessonTime, subject: $0.subject), $0)
            })
            homeworkErrorMessage = nil
        } catch {
            homeworkErrorMessage = homeworkMessage(for: error)
        }
    }

    private func saveHomework(for lesson: ScheduleItem, existing: Homework?, text: String) async throws -> Homework {
        guard let groupId = homeworkGroupId else {
            throw APIServiceError.invalidURL
        }
        let homework: Homework
        if let existing {
            homework = try await APIService.shared.updateHomework(groupId: groupId, homeworkId: existing.id, text: text)
        } else {
            homework = try await APIService.shared.createHomework(
                groupId: groupId,
                lessonDate: selectedLessonDateString,
                lessonTime: lesson.time,
                subject: lesson.title,
                teacher: lesson.teacher.mympsuTrimmed.isEmpty ? nil : lesson.teacher,
                room: lesson.room.mympsuTrimmed.isEmpty ? nil : lesson.room,
                text: text
            )
        }
        homeworksByLessonKey[homeworkKey(date: homework.lessonDate, time: homework.lessonTime, subject: homework.subject)] = homework
        NotificationCenter.default.post(name: .mympsuHomeworksDidChange, object: nil)
        return homework
    }

    private func deleteHomework(_ homework: Homework) async throws {
        guard let groupId = homeworkGroupId else {
            throw APIServiceError.invalidURL
        }
        try await APIService.shared.deleteHomework(groupId: groupId, homeworkId: homework.id)
        homeworksByLessonKey.removeValue(forKey: homeworkKey(date: homework.lessonDate, time: homework.lessonTime, subject: homework.subject))
        NotificationCenter.default.post(name: .mympsuHomeworksDidChange, object: nil)
    }

    private func homeworkMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Проверьте подключение и попробуйте ещё раз."
        }
        if case APIServiceError.httpStatusWithBody(let statusCode, _) = error {
            if statusCode == 403 {
                return "Ты не состоишь в этой группе или нет доступа."
            }
            if statusCode == 404 {
                return "Домашки нет."
            }
            if statusCode == 400 {
                return "Backend не принял данные домашки."
            }
            return "Backend вернул ошибку \(statusCode)."
        }
        return "Не удалось загрузить домашку."
    }
}

#if os(iOS)
private struct ScheduleScrollTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
#endif

private struct HomeworkSheetSelection: Identifiable {
    let lesson: ScheduleItem
    let homework: Homework?

    var id: String {
        lesson.id
    }
}

private struct HomeworkSheet: View {
    let lesson: ScheduleItem
    let lessonDate: String
    let homework: Homework?
    let canEdit: Bool
    let onSave: (String) async throws -> Homework
    let onDelete: () async throws -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var text: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        lesson: ScheduleItem,
        lessonDate: String,
        homework: Homework?,
        canEdit: Bool,
        onSave: @escaping (String) async throws -> Homework,
        onDelete: @escaping () async throws -> Void
    ) {
        self.lesson = lesson
        self.lessonDate = lessonDate
        self.homework = homework
        self.canEdit = canEdit
        self.onSave = onSave
        self.onDelete = onDelete
        self._text = State(initialValue: homework?.text ?? "")
    }

    private var title: String {
        if canEdit {
            return homework == nil ? "Добавить домашку" : "Изменить домашку"
        }
        return "Домашка"
    }

    private var canSave: Bool {
        canEdit && !text.mympsuTrimmed.isEmpty && !isSaving
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    lessonInfo

                    if canEdit {
                        TextEditor(text: $text)
                            .frame(minHeight: 180)
                            .padding(8)
                            .mympsuDefaultSurface()
                    } else {
                        Text(homework?.text.mympsuTrimmed.isEmpty == false ? homework?.text ?? "" : "Домашки нет.")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .mympsuDefaultSurface()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if canEdit, homework != nil {
                        Button {
                            delete()
                        } label: {
                            HStack {
                                Label("Удалить домашку", systemImage: "trash.fill")
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .mympsuDefaultSurface()
                        }
                        .disabled(isSaving)
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        close()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(canEdit ? (isSaving ? "Сохраняем" : "Сохранить") : " ") {
                        if canEdit {
                            save()
                        }
                    }
                    .disabled(!canSave)
                    .opacity(canEdit ? 1 : 0)
                }
            }
        }
    }

    private var lessonInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lesson.title)
                .font(.headline)
            Label(lessonDate, systemImage: "calendar")
            Label(lesson.time, systemImage: "clock")
            if !lesson.teacher.mympsuTrimmed.isEmpty {
                Label(lesson.teacher, systemImage: "person.fill")
            }
            if !lesson.room.mympsuTrimmed.isEmpty {
                Label(lesson.room, systemImage: "mappin.and.ellipse")
            }
        }
        .font(.subheadline)
        .mympsuDefaultSurface()
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await onSave(text.mympsuTrimmed)
                close()
            } catch {
                errorMessage = message(for: error)
            }
            isSaving = false
        }
    }

    private func delete() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onDelete()
                close()
            } catch {
                errorMessage = message(for: error)
            }
            isSaving = false
        }
    }

    private func close() {
        presentationMode.wrappedValue.dismiss()
    }

    private func message(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return "Сеть недоступна. Попробуйте ещё раз."
        }
        if case APIServiceError.httpStatusWithBody(let statusCode, _) = error {
            if statusCode == 403 {
                return "Нет доступа к домашке этой группы."
            }
            if statusCode == 400 {
                return "Проверьте текст домашки."
            }
            return "Backend вернул ошибку \(statusCode)."
        }
        return "Не удалось выполнить действие."
    }
}

extension Notification.Name {
    static let mympsuHomeworksDidChange = Notification.Name("mympsuHomeworksDidChange")
}

private extension View {
    @ViewBuilder
    func ifAvailableMacOS14<Content: View>(_ transform: (Self) -> Content) -> some View {
#if os(macOS)
        if #available(macOS 14.0, *) {
            transform(self)
        } else {
            self
        }
#else
        self
#endif
    }

    @ViewBuilder
    func ifAvailableiOS16<Content: View>(_ transform: (Self) -> Content) -> some View {
#if os(iOS)
        if #available(iOS 16.0, *) {
            transform(self)
        } else {
            self
        }
#else
        self
#endif
    }
}
