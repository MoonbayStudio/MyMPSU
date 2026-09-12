import SwiftUI

struct AssistantChatView: View {
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @StateObject private var viewModel: PelikashaChatViewModel
    @EnvironmentObject private var runtimeConfig: RuntimeConfigService
    @State private var isKeyboardVisible = false
    @State private var showPersonaSelection = false
    @State private var showHistory = false

    let onBack: (() -> Void)?

    init(selectedDate: Date? = nil, onBack: (() -> Void)? = nil) {
        self._viewModel = StateObject(
            wrappedValue: PelikashaChatViewModel(selectedDateProvider: { selectedDate })
        )
        self.onBack = onBack
    }

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
        ZStack {
            if showPersonaSelection {
                AssistantPersonaSelectionView(
                    activeTheme: activeTheme,
                    selectedPersona: $viewModel.selectedPersona,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showPersonaSelection = false
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if showHistory {
                PelikashaHistoryView(
                    history: viewModel.history,
                    currentDialogID: viewModel.currentDialogID,
                    openDialog: { id in viewModel.openDialog(id: id) },
                    newDialog: { viewModel.startNewDialog() },
                    deleteDialog: { id in viewModel.deleteDialog(id: id) },
                    clearHistory: { viewModel.clearHistory() },
                    closeHistory: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showHistory = false
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                chatContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showPersonaSelection)
        .animation(.easeInOut(duration: 0.18), value: showHistory)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .onDisappear {
            viewModel.cancelCurrentRequest()
        }
#if os(macOS)
        .modifier(AssistantMacToolbarModifier(
            navigationContent: AnyView(assistantToolbarNavigationContent),
            actionsContent: AnyView(assistantToolbarActions)
        ))
        .modifier(MyMPSUMacWindowToolbarBackgroundModifier())
#endif
#if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
#endif
    }

#if os(macOS)
    private struct AssistantMacToolbarModifier: ViewModifier {
        let navigationContent: AnyView
        let actionsContent: AnyView

        func body(content: Content) -> some View {
            if #available(macOS 26.0, *) {
                content
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            navigationContent
                        }
                        .sharedBackgroundVisibility(.hidden)

                        ToolbarItemGroup(placement: .primaryAction) {
                            actionsContent
                        }
                        .sharedBackgroundVisibility(.hidden)
                    }
            } else {
                content
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            navigationContent
                        }

                        ToolbarItemGroup(placement: .primaryAction) {
                            actionsContent
                        }
                    }
            }
        }
    }
#endif

    private var chatContent: some View {
        VStack(spacing: 0) {
#if os(iOS)
            header
#else
            headerNotice
#endif
            messageList
        }
        .mympsuBottomInset {
            composer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .mympsuDefaultSurface()
                    .accessibilityLabel("Назад")
                }

                ThemedChrome(shape: activeTheme.headerShape) {
                    HStack(spacing: 8) {
                        Image(systemName: personaIcon)
                            .foregroundColor(.accentColor)
                        Text(viewModel.selectedPersona.displayName)
                            .font(.title3.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                }

                Spacer(minLength: 0)

                if let remaining = visibleRemaining {
                    Text("Осталось сегодня: \(remaining)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .mympsuDefaultSurface()
                }

                headerIconButton(systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                                 accessibilityLabel: "История чата") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showHistory = true
                    }
                }

                headerIconButton(systemImage: "gearshape.fill",
                                 accessibilityLabel: "Настройки Помощника МПГУ") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showPersonaSelection = true
                    }
                }

                headerIconButton(systemImage: "plus",
                                 accessibilityLabel: "Новый чат") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.startNewDialog()
                    }
                }
            }

            Text(runtimeConfig.settings.aiEnabled ? "Помощник МПГУ может ошибаться. Расписание лучше сверять с основным экраном." : "AI-чат временно отключён администратором.")
                .font(.footnote)
                .foregroundColor(runtimeConfig.settings.aiEnabled ? .secondary : .red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

#if os(macOS)
    private var assistantToolbarNavigationContent: some View {
        HStack(spacing: 8) {
            if showPersonaSelection {
                MyMPSUToolbarIconButton(shape: activeTheme.headerShape, systemImage: "chevron.left") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showPersonaSelection = false
                    }
                }
            }

            MyMPSUToolbarTitleCapsule(
                shape: activeTheme.headerShape,
                title: showPersonaSelection ? "Персонаж" : viewModel.selectedPersona.displayName,
                systemImage: showPersonaSelection ? "person.crop.circle" : personaIcon
            )
        }
        .padding(.leading, 16)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var assistantToolbarActions: some View {
        if !showPersonaSelection {
            if let remaining = visibleRemaining {
                ThemedChrome(shape: activeTheme.headerShape) {
                    Text("Осталось сегодня: \(remaining)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                }
            }

            MyMPSUToolbarIconButton(shape: activeTheme.headerShape, systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showHistory = true
                }
            }

            MyMPSUToolbarIconButton(shape: activeTheme.headerShape, systemImage: "gearshape.fill") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showPersonaSelection = true
                }
            }

            MyMPSUToolbarIconButton(shape: activeTheme.headerShape, systemImage: "plus") {
                viewModel.startNewDialog()
            }
        }
    }

    private var headerNotice: some View {
        Text(runtimeConfig.settings.aiEnabled ? "Помощник МПГУ может ошибаться. Расписание лучше сверять с основным экраном." : "AI-чат временно отключён администратором.")
            .font(.footnote)
            .foregroundColor(runtimeConfig.settings.aiEnabled ? .secondary : .red)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
    }
#endif

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .padding(.top, 24)
                    } else {
                        ForEach(viewModel.messages) { message in
                            AssistantMessageBubble(message: message)
                        }
                    }

                    if shouldShowRetry {
                        retryButton
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("assistant-bottom")
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isLoading) { _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: personaIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.selectedPersona.displayName)
                        .font(.headline)
                    Text(viewModel.selectedPersona.promptHint)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text(emptyStateText)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mympsuAdaptiveGlassCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    private var retryButton: some View {
        Button {
            viewModel.retryLastMessage()
        } label: {
            Label("Повторить", systemImage: "arrow.clockwise")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(height: 34)
        }
        .buttonStyle(.plain)
        .mympsuDefaultSurface()
        .padding(.top, 2)
    }

    private var composer: some View {
        ThinkingInputBar(
            text: $viewModel.inputText,
            isThinking: viewModel.isLoading,
            placeholder: placeholder,
            thinkingPlaceholder: thinkingPlaceholder,
            sendSymbolName: "paperplane.fill",
            isDisabled: !runtimeConfig.settings.aiEnabled,
            onSend: sendMessageIfAllowed,
            onCancel: viewModel.cancelCurrentRequest,
            themedShape: activeTheme.inputShape
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, composerBottomPadding)
    }

    private var personaIcon: String {
        let icon = viewModel.selectedPersona.icon
#if os(iOS)
        if icon == "bird.fill", #unavailable(iOS 16.0) {
            return "bubble.left.and.bubble.right.fill"
        }
#elseif os(macOS)
        if icon == "bird.fill", #unavailable(macOS 13.0) {
            return "bubble.left.and.bubble.right.fill"
        }
#endif
        return icon
    }

    private var placeholder: String {
        switch viewModel.selectedPersona {
        case .pelikasha:
            return "Спросить помощника МПГУ..."
        case .stesha:
            return "Спросить Стешу..."
        }
    }

    private var thinkingPlaceholder: String {
        switch viewModel.selectedPersona {
        case .pelikasha:
            return "Помощник МПГУ думает..."
        case .stesha:
            return "Стеша думает..."
        }
    }

    private var emptyStateText: String {
        switch viewModel.selectedPersona {
        case .pelikasha:
            return "Помощник МПГУ отвечает чуть живее и может помочь с коротким учебным вопросом."
        case .stesha:
            return "Стеша отвечает спокойнее, когда нужна мягкая подсказка или поддержка."
        }
    }

    private var visibleRemaining: Int? {
        guard runtimeConfig.settings.aiDailyLimit > 0 else { return nil }
        return max(0, viewModel.remaining ?? runtimeConfig.settings.aiDailyLimit)
    }

    private func sendMessageIfAllowed() {
        guard runtimeConfig.settings.aiEnabled else {
            viewModel.appendLocalSystemMessage("AI-чат временно отключён администратором.")
            return
        }
        viewModel.sendMessage()
    }

    private var shouldShowRetry: Bool {
        guard !viewModel.isLoading, let last = viewModel.messages.last else { return false }
        return last.role == .systemLocal
    }

    private var composerBottomPadding: CGFloat {
#if os(iOS)
        return isKeyboardVisible ? 10 : 92
#else
        return 12
#endif
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("assistant-bottom", anchor: .bottom)
        }
    }

    private func headerIconButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ThemedChrome(shape: activeTheme.headerShape) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color.clear)
                    .contentShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct AssistantPersonaSelectionView: View {
    let activeTheme: AppTheme
    @Binding var selectedPersona: AssistantPersona
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Персонаж") {
                onBack()
            }
#endif

            VStack(alignment: .leading, spacing: 6) {
                Text("Кто будет отвечать")
                    .font(.headline)
                Text("Выбранным может быть только один персонаж.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            HStack(alignment: .top, spacing: 12) {
                ForEach(AssistantPersona.allCases) { persona in
                    AssistantPersonaCard(
                        persona: persona,
                        isSelected: selectedPersona == persona,
                        onSelect: {
                            selectedPersona = persona
                        }
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
    }
}

private struct AssistantPersonaCard: View {
    let persona: AssistantPersona
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                temporaryBackground
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: persona.icon)
                        .font(.system(size: 28, weight: .semibold))
                    Text(persona.displayName)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.22), lineWidth: isSelected ? 1.8 : 0.8)
            )

            Button {
                onSelect()
            } label: {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    Text(isSelected ? "Выбрано" : "Выбрать")
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.plain)
            .mympsuDefaultSurface(cornerRadius: 12, padding: 0)
            .disabled(isSelected)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var temporaryBackground: some View {
        switch persona {
        case .pelikasha:
            LinearGradient(
                colors: [
                    Color(red: 0.66, green: 0.83, blue: 1.0),
                    Color(red: 0.96, green: 0.83, blue: 0.52)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .stesha:
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.55, blue: 0.82),
                    Color(red: 0.78, green: 0.70, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var description: String {
        switch persona {
        case .pelikasha:
            return "Живее, чуть с приколом, но по делу."
        case .stesha:
            return "Спокойнее, мягче, для помощи и поддержки."
        }
    }
}

private struct AssistantMessageBubble: View {
    let message: PelikashaMessage
    @Environment(\.mympsuSurfaceStrokeOpacity) private var strokeOpacity

    var body: some View {
        HStack {
            switch message.role {
            case .user:
                Spacer(minLength: 40)
                bubble
            case .assistant, .systemLocal:
                bubble
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 5) {
            if message.role == .assistant, let persona = message.persona {
                Text(persona.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Text(message.text)
                .font(.body)
                .foregroundColor(message.role == .user ? .white : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(strokeColor, lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private var background: some View {
        switch message.role {
        case .user:
            Color.accentColor
        case .assistant:
            MyMPSUAdaptiveMaterialFill()
        case .systemLocal:
            Color.orange.opacity(0.14)
        }
    }

    private var strokeColor: Color {
        switch message.role {
        case .user:
            return .clear
        case .assistant:
            return Color.white.opacity(strokeOpacity)
        case .systemLocal:
            return Color.orange.opacity(0.28)
        }
    }
}
