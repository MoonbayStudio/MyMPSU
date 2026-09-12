import SwiftUI

struct PelikashaChatView: View {
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @StateObject private var viewModel = PelikashaChatViewModel()
    @State private var isKeyboardVisible = false
    @State private var isHistoryPresented = false

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
        Group {
#if os(macOS)
            if #available(macOS 26.0, *) {
                chatRoot
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            toolbarTitle
                        }
                        .sharedBackgroundVisibility(.hidden)

                        ToolbarItem(placement: .primaryAction) {
                            historyToolbarButton
                        }
                        .sharedBackgroundVisibility(.hidden)
                    }
            } else {
                chatRoot
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            toolbarTitle
                        }

                        ToolbarItem(placement: .primaryAction) {
                            historyToolbarButton
                        }
                    }
            }
#else
            if #available(iOS 16.0, *) {
                NavigationStack {
                    ZStack {
                        ThemedBackground(theme: activeTheme)
                            .ignoresSafeArea()
                        chatRoot
                    }
                    .navigationDestination(isPresented: $isHistoryPresented) {
                        historyScreen
                    }
                }
            } else {
                NavigationView {
                    ZStack {
                        ThemedBackground(theme: activeTheme)
                            .ignoresSafeArea()
                        chatRoot
                    }
                    .background(
                        NavigationLink(destination: historyScreen, isActive: $isHistoryPresented) {
                            EmptyView()
                        }
                        .hidden()
                    )
                }
                .navigationViewStyle(.stack)
            }
#endif
        }
#if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
#endif
    }

#if os(iOS)
    private var historyScreen: some View {
        PelikashaHistoryView(
            history: viewModel.history,
            currentDialogID: viewModel.currentDialogID,
            openDialog: { id in viewModel.openDialog(id: id) },
            newDialog: { viewModel.startNewDialog() },
            deleteDialog: { id in viewModel.deleteDialog(id: id) },
            clearHistory: { viewModel.clearHistory() },
            closeHistory: { isHistoryPresented = false }
        )
    }
#endif

    @ViewBuilder
    private var chatRoot: some View {
#if os(macOS)
        HStack(spacing: 0) {
            macChatRoot
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isHistoryPresented {
                macHistorySidebar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(chatBackground)
        .animation(.easeInOut(duration: 0.22), value: isHistoryPresented)
#else
        VStack(spacing: 0) {
            header
            chatContent
        }
        .safeAreaInset(edge: .bottom) {
            composer
        }
#endif
    }

#if os(macOS)
    private var toolbarTitle: some View {
        MyMPSUToolbarTitleCapsule(shape: activeTheme.headerShape,
                                    title: "Помощник МПГУ",
                                    systemImage: chatIconName)
            .padding(.leading, 16)
    }

    private var historyToolbarButton: some View {
        MyMPSUToolbarIconButton(shape: activeTheme.headerShape,
                                  systemImage: "sidebar.right") {
            isHistoryPresented.toggle()
        }
    }

    @ViewBuilder
    private var macChatRoot: some View {
        if #available(macOS 12.0, *) {
            chatContent
                .background(chatBackground)
                .safeAreaInset(edge: .bottom) {
                    composer
                }
        } else {
            VStack(spacing: 0) {
                chatContent
                composer
            }
            .background(chatBackground)
        }
    }

    private var macHistorySidebar: some View {
        PelikashaHistoryView(
            history: viewModel.history,
            currentDialogID: viewModel.currentDialogID,
            openDialog: { id in viewModel.openDialog(id: id) },
            newDialog: { viewModel.startNewDialog() },
            deleteDialog: { id in viewModel.deleteDialog(id: id) },
            clearHistory: { viewModel.clearHistory() },
            closeHistory: { isHistoryPresented = false }
        )
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .background(sidebarBackground)
        .overlay(
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 0.8)
                Spacer(minLength: 0)
            }
        )
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        if #available(macOS 12.0, *) {
            Color.clear.background(.ultraThinMaterial)
        } else {
            Color(NSColor.windowBackgroundColor).opacity(0.94)
        }
    }
#endif

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
#if os(macOS)
                HStack(spacing: 8) {
                    Image(systemName: chatIconName)
                        .foregroundColor(.accentColor)
                    Text("Помощник МПГУ")
                        .font(.title3.weight(.semibold))
                }
                .frame(height: 44)
#else
                ThemedChrome(shape: activeTheme.headerShape) {
                    HStack(spacing: 8) {
                        Image(systemName: chatIconName)
                            .foregroundColor(.accentColor)
                        Text("Помощник МПГУ")
                            .font(.title3.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .frame(height: 44)
                    .background(Color.clear)
                }
#endif
                Spacer()
#if os(macOS)
                MyMPSUToolbarIconButton(shape: activeTheme.headerShape,
                                          systemImage: "sidebar.right") {
                    isHistoryPresented.toggle()
                }
#else
                ThemedChrome(shape: activeTheme.headerShape) {
                    Button {
                        isHistoryPresented = true
                    } label: {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                }
#endif
            }
            Text("AI-помощник студентов МПГУ")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    private var chatContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .padding(.top, 48)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.vertical, 12)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isLoading) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        HStack {
            ThinkingInputBar(
                text: $viewModel.inputText,
                isThinking: viewModel.isLoading,
                isCancelling: viewModel.isCancelling,
                placeholder: "Напиши Помощнику МПГУ…",
                thinkingPlaceholder: "Помощник МПГУ думает...",
                sendSymbolName: "paperplane.fill",
                onSend: {
                    viewModel.sendMessage()
                },
                onCancel: {
                    viewModel.cancelCurrentRequest()
                },
                themedShape: activeTheme.inputShape
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, composerBottomPadding)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: chatIconName)
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
            Text("Спроси помощника МПГУ о расписании, учебе или сессии")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Например: \"Какие пары завтра?\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .mympsuAdaptiveGlassCard(cornerRadius: 20)
        .padding(.horizontal, 16)
    }

    private var chatIconName: String {
#if os(iOS)
        if #available(iOS 16.0, *) {
            return "bird.fill"
        }
        return "bubble.left.and.bubble.right.fill"
#elseif os(macOS)
        if #available(macOS 13.0, *) {
            return "bird.fill"
        }
        return "bubble.left.and.bubble.right.fill"
#else
        return "message.fill"
#endif
    }

    private var chatBackground: some View {
        Group {
#if os(iOS)
            ThemedBackground(theme: activeTheme)
#else
            ThemedBackground(theme: activeTheme)
#endif
        }
        .ignoresSafeArea()
    }

    private var composerBottomPadding: CGFloat {
#if os(iOS)
        return isKeyboardVisible ? 10 : 92
#else
        return 12
#endif
    }

    private func dismissKeyboard() {
#if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

struct PelikashaHistoryView: View {
    let history: [PelikashaChatViewModel.DialogRecord]
    let currentDialogID: UUID
    let openDialog: (UUID) -> Void
    let newDialog: () -> Void
    let deleteDialog: (UUID) -> Void
    let clearHistory: () -> Void
    var closeHistory: (() -> Void)? = nil

    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
#if os(macOS)
        VStack(alignment: .leading, spacing: 8) {
            Text("История")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.top, 12)
            historyList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#else
        VStack(alignment: .leading, spacing: 16) {
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "История") {
                dismissHistory()
            }
            historyList
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
    }

    private var historyList: some View {
        List {
            Button {
                newDialog()
                dismissHistory()
            } label: {
                Label("Новый диалог", systemImage: "square.and.pencil")
            }

            ForEach(history) { dialog in
                Button {
                    openDialog(dialog.id)
                    dismissHistory()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dialog.title)
                                .font(.headline)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .clipped()
                            Text(Self.dateFormatter.string(from: dialog.updatedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if dialog.id == currentDialogID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .mympsuGlassButtonStyle()
                .modifier(DeleteSwipeCompat {
                    deleteDialog(dialog.id)
                })
            }

            if !history.isEmpty {
                Button {
                    clearHistory()
                    dismissHistory()
                } label: {
                    Label("Очистить историю", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }

    private func dismissHistory() {
        if let closeHistory {
            closeHistory()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct DeleteSwipeCompat: ViewModifier {
    let onDelete: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 15.0, *) {
            content.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
        } else {
            content.contextMenu {
                Button(action: onDelete) {
                    Label("Удалить", systemImage: "trash")
                }
            }
        }
#else
        if #available(macOS 12.0, *) {
            content.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
        } else {
            content.contextMenu {
                Button(action: onDelete) {
                    Label("Удалить", systemImage: "trash")
                }
            }
        }
#endif
    }
}

private struct MessageBubble: View {
    let message: PelikashaMessage
    @Environment(\.mympsuSurfaceStrokeOpacity) private var strokeOpacity

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
                bubble
            } else {
                bubble
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
    }

    private var bubble: some View {
        Text(message.text)
            .font(.body)
            .foregroundColor(message.role == .user ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Group {
                    if message.role == .user {
                        Color.accentColor
                    } else if message.role == .systemLocal {
                        Color.orange.opacity(0.14)
                    } else {
                        MyMPSUAdaptiveMaterialFill()
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(message.role == .user ? Color.clear : (message.role == .systemLocal ? Color.orange.opacity(0.28) : Color.white.opacity(strokeOpacity)), lineWidth: 0.8)
            )
    }
}
