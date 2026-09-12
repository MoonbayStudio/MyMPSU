//
//  ContentView.swift
//  MyMPSU
//
//  Created by Nicolas Forest on 11/9/25.
//

import SwiftUI
internal import Combine
import AVFoundation
#if os(macOS)
import Cocoa
#endif


struct ContentView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @EnvironmentObject private var runtimeConfig: RuntimeConfigService
#if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appLockManager = AppLockManager.shared
    @State private var isRestoringScheduleAfterUnlock = false
    @State private var didHandleInitialScheduleAppearance = false
#endif
    enum MenuSubView {
        case groupSelection
        case settings
        case themes
        case accessibility
        case assistant
        case about
        case developerTools
    }
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("accessibilityReduceMotion") private var accessibilityReduceMotion = false
    @AppStorage("accessibilityHighContrast") private var accessibilityHighContrast = false
    @AppStorage("accessibilityLargerText") private var accessibilityLargerText = false
    @AppStorage("accessibilityAutoSpeakSchedule") private var accessibilityAutoSpeakSchedule = false
    @AppStorage("accessibilitySpeechDetailed") private var accessibilitySpeechDetailed = true
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    
    @State private var selectedView: Int? = 0
    /// Use this binding when a non-optional Binding<Int> is required, e.g. MainContentView.
    var selectedViewNonOptional: Binding<Int> {
        Binding<Int>(
            get: { selectedView ?? 0 },
            set: { selectedView = $0 }
        )
    }
    @State private var selectedIndex: Int = 0
    @State private var showBottomIslandAnimated: Bool = false
    @State private var isActiveWindow = true
    @State private var selectedGroup: MyGroup? = nil
    @State private var selectedDate = Date()
    @State private var menuTitle: String = "Меню"
    @State private var selectedMenuSubView: MenuSubView? = nil
    @State private var previousMenuSubView: MenuSubView? = nil
    @State private var menuSubViewDragOffset: CGFloat = 0
    @State private var isAccountNestedScreenPresented = false
#if os(iOS)
    @State private var isScheduleTopChromeVisible = true
    @State private var isBottomIslandHiddenByScheduleScroll = false
    @State private var isScheduleCalendarPresented = false
    @State private var scheduleCalendarDisplayedMonth = Date()
    @State private var bottomIslandRefreshPromptIndex: Int?
    @State private var scheduleRefreshRequestID = 0
    @State private var sessionRefreshRequestID = 0
#endif

    private let contentHorizontalPadding: CGFloat = 16
    private let scheduleCalendarVerticalOffset: CGFloat = 11

    private struct MenuBackSwipeConfig {
        let edgeWidth: CGFloat
        let triggerRatio: CGFloat
        let predictedTriggerRatio: CGFloat
        let completeResponse: CGFloat
        let completeDamping: CGFloat
        let cancelResponse: CGFloat
        let cancelDamping: CGFloat

        static let `default` = MenuBackSwipeConfig(
            edgeWidth: 28,
            triggerRatio: 0.28,
            predictedTriggerRatio: 0.4,
            completeResponse: 0.24,
            completeDamping: 0.9,
            cancelResponse: 0.28,
            cancelDamping: 0.88
        )
    }

    private let menuBackSwipeConfig = MenuBackSwipeConfig.default
    @State private var isKeyboardVisible = false
    private let speechSynthesizer = AVSpeechSynthesizer()

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }
    
    private func getTitle(for viewIndex: Int) -> String {
        switch viewIndex {
        case 0: return "Расписание"
        case 1: return "Помощник МПГУ"
        case 2: return "Сессия"
        case 3: return "Аккаунт"
        case 4: return "Меню"
        default: return ""
        }
    }
    var body: some View {
#if os(macOS)
        if #available(macOS 13.0, *) {
            SplitViewContent(parent: self)
                .background(TitlebarSeparatorHider())
        } else {
            ZStack {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        SidebarView(selectedView: selectedViewNonOptional)
                            .frame(width: 150)
                            .padding(.leading, 10)
                        VStack(spacing: 0) {
                            ZStack(alignment: .topLeading) {
                                DraggableHeaderView()
                                    .frame(height: 80)
                                HStack(spacing: 10) {
                                    if selectedView == 4 && selectedMenuSubView != nil {
                                        Button(action: {
                                            if selectedMenuSubView == .themes || selectedMenuSubView == .accessibility {
                                                selectedMenuSubView = .settings
                                                menuTitle = "Настройки"
                                            } else {
                                                selectedMenuSubView = nil
                                                menuTitle = "Меню"
                                            }
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .font(.title2)
                                        }
                                        .mympsuGlassButtonStyle()
                                    }

                                    Text(selectedView == 4 ? menuTitle : getTitle(for: selectedView ?? 0))
                                        .font(.title3.weight(.semibold))
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .frame(height: 40)
                                        .background(capsuleHeaderBackground)
                                        .clipShape(Capsule())
                                        .mympsuGlass(in: Capsule())
                                    
                                    if selectedView == 0 {
                                        Button {
                                            let groupIdToLoad = selectedGroup?.id ?? viewModel.savedGroupId
                                            guard !groupIdToLoad.isEmpty else { return }
                                            Task {
                                                await runtimeConfig.refresh(force: true)
                                                await viewModel.load(for: groupIdToLoad, date: selectedDate, examOnly: false)
                                            }
                                        } label: {
                                            Image(systemName: "arrow.clockwise")
                                                .frame(width: 32, height: 32)
                                        }
                                        .buttonStyle(.plain)

                                        CalendarDatePicker(selectedDate: $selectedDate, showsChrome: false)
                                            .frame(height: 32)
                                    }
                                }
                                .padding(.leading, 20)
                                .padding(.top, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .zIndex(1)
                            }
                            .frame(height: 80)
                            ZStack {
                                MainContentView(
                                    selectedIndex: selectedViewNonOptional,
                                    selectedDate: $selectedDate,
                                    selectedGroup: $selectedGroup,
                                    scheduleViewModel: viewModel,
                                    menuTitle: $menuTitle,
                                    selectedMenuSubView: $selectedMenuSubView,
                                    speakCurrentSchedule: speakCurrentSchedule
                                )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onChange(of: selectedGroup) { newGroup in
                                Task {
                                    await viewModel.loadOnce(groupId: newGroup?.id ?? "", date: selectedDate)
                                }
                            }
                            .onChange(of: selectedDate) { newDate in
                                Task {
                                    await viewModel.loadOnce(groupId: selectedGroup?.id ?? viewModel.savedGroupId, date: newDate)
                                }
                            }
                        }
                        .padding(.horizontal, 5)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                isActiveWindow = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                isActiveWindow = false
            }
        }
#else
        ZStack(alignment: .bottom) {
            ThemedBackground(theme: activeTheme).ignoresSafeArea()

            // Main VStack
            VStack(spacing: 0) {
                if selectedIndex == 0 || selectedIndex == 2 {
                    ZStack(alignment: .top) {
                        ScheduleView(viewModel: viewModel, selectedDate: $selectedDate,
                                     groupId: selectedGroup?.id ?? viewModel.savedGroupId,
                                     examOnly: selectedIndex == 2,
                                     onScrollChromeChange: handleScheduleScrollChrome,
                                     externalRefreshRequest: selectedIndex == 2 ? sessionRefreshRequestID : scheduleRefreshRequestID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        scheduleTopOverlay
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedIndex)
                    .transition(.opacity)
                } else if selectedIndex == 1 {
                    AssistantChatView(selectedDate: selectedDate)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else if selectedIndex == 3 {
                    AccountView(scheduleViewModel: viewModel,
                                nestedScreenPresented: $isAccountNestedScreenPresented)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else if selectedIndex == 4 {
                    ZStack {
                        if selectedMenuSubView == nil {
                            menuRootView
                        } else {
                            // Render destination underneath only during interactive return.
                            if menuSubViewDragOffset > 0 {
                                menuBackDestinationView
                            }
                            menuSubViewContent
                                .offset(x: max(0, menuSubViewDragOffset))
                                .transition(menuSubViewTransition)
                        }
                    }
                    .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
                    .overlay(alignment: .leading) {
                        if selectedMenuSubView != nil {
                            Color.clear
                                .frame(width: menuBackSwipeConfig.edgeWidth)
                                .contentShape(Rectangle())
                                .highPriorityGesture(interactiveMenuBackGesture)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.14), value: selectedIndex)

            if showBottomIslandAnimated {
                BottomIsland(
                    selectedIndex: $selectedIndex,
                    refreshPromptIndex: $bottomIslandRefreshPromptIndex,
                    onRefreshSelectedTab: handleBottomIslandRefresh
                )
                    .frame(height: 80)
                    .offset(y: isBottomIslandHiddenByScheduleScroll ? 110 : 0)
                    .opacity(isBottomIslandHiddenByScheduleScroll ? 0 : 1)
                    .allowsHitTesting(!isBottomIslandHiddenByScheduleScroll)
                    .animation(.easeInOut(duration: 0.18), value: isBottomIslandHiddenByScheduleScroll)
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if runtimeConfig.settings.maintenanceMode {
                    RuntimeNoticeBanner(
                        notice: SystemNotice(
                            id: -1,
                            title: "Технические работы",
                            message: "Часть функций может быть временно недоступна.",
                            type: .maintenance,
                            showAs: .banner,
                            dismissible: false
                        ),
                        onDismiss: {}
                    )
                    .padding(.horizontal, 12)
                }

                if let notice = runtimeConfig.visibleNotice, notice.showAs == .banner {
                    RuntimeNoticeBanner(notice: notice) {
                        runtimeConfig.dismiss(notice)
                    }
                    .padding(.horizontal, 12)
                }

            }
            .padding(.top, 8)
        }
        .overlay {
            if let notice = runtimeConfig.visibleNotice, notice.showAs == .modal {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                RuntimeNoticeModalContent(notice: notice) {
                    runtimeConfig.dismiss(notice)
                }
                .frame(maxWidth: 420)
                .mympsuAdaptiveGlassCard(cornerRadius: 20)
                .padding(24)
            }
        }
        .overlay {
            if appLockManager.shouldShowLockScreen {
                AppLockGateView(lockManager: appLockManager)
                    .zIndex(20)
            } else if appLockManager.shouldShowPrivacyCover {
                AppLockPrivacyCoverView()
                    .zIndex(20)
            }
        }
        .onChange(of: viewModel.animatedItems) { _ in }
        .onChange(of: selectedGroup) { newGroup in
            let groupIdToLoad = newGroup?.id ?? ""
            guard !groupIdToLoad.isEmpty else { return }
            let shouldEnsure = shouldRunAutomaticScheduleEnsure
            if selectedIndex == 2 {
                viewModel.loadSessionFromCache(groupId: groupIdToLoad)
            } else if selectedIndex == 0 {
                Task {
                    await viewModel.loadOnce(groupId: groupIdToLoad, date: selectedDate, examOnly: false)
                    guard shouldEnsure, shouldRunAutomaticScheduleEnsure else { return }
                    await viewModel.ensureScheduleCachesIfNeeded(groupId: groupIdToLoad, anchorDate: selectedDate)
                    guard shouldRunAutomaticScheduleEnsure else { return }
                    await viewModel.loadOnce(groupId: groupIdToLoad, date: selectedDate, examOnly: false)
                }
            }
        }
        .onChange(of: selectedDate) { newDate in
            guard selectedIndex == 0 else { return }
            Task {
                let groupIdToLoad = selectedGroup?.id ?? viewModel.savedGroupId
                await viewModel.loadOnce(groupId: groupIdToLoad, date: newDate, examOnly: false)
            }
        }
        .onChange(of: viewModel.items) { _ in
            guard accessibilityAutoSpeakSchedule, selectedIndex == 0 else { return }
            speakCurrentSchedule()
        }
        .onChange(of: appLockManager.isUnlocked) { isUnlocked in
            guard isUnlocked else { return }
            isRestoringScheduleAfterUnlock = true
            viewModel.protectVisibleCacheDuringResume()
            reloadVisibleScheduleAfterUnlock()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isRestoringScheduleAfterUnlock = false
            }
        }
        .onChange(of: selectedIndex) { newIndex in
            guard newIndex == 0 || newIndex == 2 else { return }
            let groupIdToLoad = selectedGroup?.id ?? viewModel.savedGroupId
            guard !groupIdToLoad.isEmpty else { return }
            let shouldEnsure = shouldRunAutomaticScheduleEnsure
            if newIndex == 2 {
                viewModel.loadSessionFromCache(groupId: groupIdToLoad)
                Task {
                    guard shouldEnsure, shouldRunAutomaticScheduleEnsure else { return }
                    await viewModel.ensureScheduleCachesIfNeeded(groupId: groupIdToLoad, anchorDate: selectedDate)
                    guard shouldRunAutomaticScheduleEnsure else { return }
                    viewModel.loadSessionFromCache(groupId: groupIdToLoad)
                }
            } else {
                // Show loading placeholder only when there is no in-memory cache
                // for the selected day. This keeps tab switch snappy.
                if shouldEnsure, !viewModel.hasInMemoryCache(groupId: groupIdToLoad, date: selectedDate, examOnly: false) {
                    viewModel.isLoading = true
                    viewModel.hasConnectionError = false
                    viewModel.hasOfflineCacheMissForSelectedDay = false
                    viewModel.items.removeAll()
                    viewModel.animatedItems.removeAll()
                }
                Task {
                    await viewModel.loadOnce(groupId: groupIdToLoad, date: selectedDate, examOnly: false)
                    guard shouldEnsure, shouldRunAutomaticScheduleEnsure else { return }
                    await viewModel.ensureScheduleCachesIfNeeded(groupId: groupIdToLoad, anchorDate: selectedDate)
                    guard shouldRunAutomaticScheduleEnsure else { return }
                    await viewModel.loadOnce(groupId: groupIdToLoad, date: selectedDate, examOnly: false)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserSettingsSyncService.didUpdateSelectedGroup)) { notification in
            applySyncedSelectedGroup(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
            updateBottomIslandVisibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
            updateBottomIslandVisibility()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                appLockManager.hidePrivacyCover()
            case .inactive:
                appLockManager.showPrivacyCoverIfNeeded()
            case .background:
                appLockManager.lockIfNeeded()
            @unknown default:
                break
            }
        }
        .onAppear {
            updateBottomIslandVisibility()
            guard !didHandleInitialScheduleAppearance else {
                viewModel.protectVisibleCacheDuringResume()
                reloadVisibleScheduleAfterUnlock()
                return
            }
            didHandleInitialScheduleAppearance = true
            if shouldRunAutomaticScheduleEnsure {
                ensureVisibleScheduleCachesIfNeeded()
            } else {
                reloadVisibleScheduleAfterUnlock()
            }
        }
        .onChange(of: selectedIndex) { newIndex in
            resetScheduleScrollChrome()
            bottomIslandRefreshPromptIndex = nil
            if newIndex != 3 {
                isAccountNestedScreenPresented = false
            }
            updateBottomIslandVisibility()
        }
        .onChange(of: isAccountNestedScreenPresented) { _ in
            updateBottomIslandVisibility()
        }
        .onChange(of: selectedMenuSubView) { newValue in
            previousMenuSubView = newValue
            updateBottomIslandVisibility()
        }
        .contrast(accessibilityHighContrast ? 1.12 : 1.0)
        .environment(\.dynamicTypeSize, accessibilityLargerText ? .xLarge : .large)
        .transaction { tx in
            if accessibilityReduceMotion {
                tx.animation = nil
                tx.disablesAnimations = true
            }
        }
#endif
    }

#if os(iOS)
    private var scheduleTopOverlay: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center) {
                    ThemedChrome(shape: activeTheme.headerShape) {
                        Text(selectedIndex == 2 ? "Сессия" : "Расписание")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .frame(height: 44)
                            .background(Color.clear)
                    }
                    Spacer()

                    if selectedIndex == 0 {
                        ThemedChrome(shape: activeTheme.dateShape) {
                            CalendarDatePicker(
                                selectedDate: $selectedDate,
                                showsChrome: false,
                                showsCalendarIcon: true,
                                pickerPresentationOffset: CGSize(width: 0, height: scheduleCalendarVerticalOffset),
                                alignsPickerPresentationToTrailingEdge: true
                            ) {
                                scheduleCalendarDisplayedMonth = selectedDate
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                                    isScheduleCalendarPresented.toggle()
                                }
                            }
                            .onChange(of: selectedDate) { _ in
                                let groupIdToLoad = selectedGroup?.id ?? viewModel.savedGroupId
                                guard !groupIdToLoad.isEmpty else { return }
                                Task {
                                    await viewModel.loadOnce(groupId: groupIdToLoad, date: selectedDate, examOnly: false)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(width: 192, height: 44, alignment: .center)
                        }
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 16)

                if selectedIndex == 0 && isScheduleCalendarPresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.16)) {
                                isScheduleCalendarPresented = false
                            }
                        }
                        .zIndex(5)
                }

                if selectedIndex == 0 && isScheduleCalendarPresented {
                    AlignedCalendarOverlay(
                        selectedDate: $selectedDate,
                        displayedMonth: $scheduleCalendarDisplayedMonth
                    ) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            isScheduleCalendarPresented = false
                        }
                    }
                    .frame(width: min(geometry.size.width - contentHorizontalPadding * 2, 320))
                    .padding(.top, 16 + 44 + scheduleCalendarVerticalOffset)
                    .padding(.trailing, contentHorizontalPadding)
                    .transition(.scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity))
                    .zIndex(10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(
            maxWidth: .infinity,
            maxHeight: isScheduleCalendarPresented ? .infinity : 76,
            alignment: .top
        )
        .offset(y: isScheduleTopChromeVisible ? 0 : -72)
        .opacity(isScheduleTopChromeVisible ? 1 : 0)
        .allowsHitTesting(isScheduleTopChromeVisible)
        .animation(.easeInOut(duration: 0.18), value: isScheduleTopChromeVisible)
        .zIndex(2)
    }
#endif

    private func updateBottomIslandVisibility() {
        let shouldShowByNavigation = selectedIndex == 0
        || selectedIndex == 1
        || selectedIndex == 2
        || (selectedIndex == 3 && !isAccountNestedScreenPresented)
        || (selectedIndex == 4 && selectedMenuSubView == nil)
        showBottomIslandAnimated = shouldShowByNavigation && !isKeyboardVisible
    }

#if os(iOS)
    private func handleScheduleScrollChrome(topChromeVisible: Bool, bottomIslandVisible: Bool) {
        guard selectedIndex == 0 || selectedIndex == 2 else { return }
        if isScheduleTopChromeVisible != topChromeVisible {
            isScheduleTopChromeVisible = topChromeVisible
        }
        let shouldHideBottomIsland = !bottomIslandVisible
        if isBottomIslandHiddenByScheduleScroll != shouldHideBottomIsland {
            isBottomIslandHiddenByScheduleScroll = shouldHideBottomIsland
        }
    }

    private func resetScheduleScrollChrome() {
        isScheduleTopChromeVisible = true
        isBottomIslandHiddenByScheduleScroll = false
    }

    private func handleBottomIslandRefresh(_ index: Int) {
        guard selectedIndex == index else { return }
        switch index {
        case 0:
            scheduleRefreshRequestID += 1
        case 2:
            sessionRefreshRequestID += 1
        default:
            break
        }
    }
#endif

    private func reloadVisibleScheduleAfterUnlock() {
        guard selectedIndex == 0 || selectedIndex == 2 else { return }
        let groupIdToLoad = selectedGroup?.id ?? viewModel.savedGroupId
        guard !groupIdToLoad.isEmpty else { return }
        viewModel.restoreCachedScheduleForResume(
            groupId: groupIdToLoad,
            date: selectedDate,
            examOnly: selectedIndex == 2
        )
    }

    private var shouldRunAutomaticScheduleEnsure: Bool {
#if os(iOS)
        !isRestoringScheduleAfterUnlock
        && !appLockManager.shouldShowLockScreen
        && !appLockManager.shouldShowPrivacyCover
#else
        true
#endif
    }

    private func ensureVisibleScheduleCachesIfNeeded() {
        guard selectedIndex == 0 || selectedIndex == 2 else { return }
        let groupIdToLoad = selectedGroup?.id ?? viewModel.savedGroupId
        guard !groupIdToLoad.isEmpty else { return }
        let shouldEnsure = shouldRunAutomaticScheduleEnsure
        Task {
            await viewModel.loadOnce(groupId: groupIdToLoad, date: selectedDate, examOnly: selectedIndex == 2)
            guard shouldEnsure, shouldRunAutomaticScheduleEnsure else { return }
            await viewModel.ensureScheduleCachesIfNeeded(groupId: groupIdToLoad, anchorDate: selectedDate)
            guard shouldRunAutomaticScheduleEnsure else { return }
            await viewModel.loadOnce(groupId: groupIdToLoad, date: selectedDate, examOnly: selectedIndex == 2)
        }
    }

    private func applySyncedSelectedGroup(_ notification: Notification) {
        guard let groupId = notification.userInfo?["groupId"] as? String,
              !groupId.isEmpty else { return }
        let groupName = notification.userInfo?["groupName"] as? String ?? groupId
        let group = MyGroup(id: groupId, name: groupName)
        selectedGroup = group
        viewModel.savedGroupId = groupId
    }

    @ViewBuilder
    private var menuRootView: some View {
        MenuView(viewModel: viewModel,
                 selectedGroup: $selectedGroup,
                 menuTitle: $menuTitle,
                 selectedMenuSubView: $selectedMenuSubView)
            .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
    }

    @ViewBuilder
    private var menuBackDestinationView: some View {
        switch selectedMenuSubView {
        case .themes, .accessibility, .assistant:
            SettingsView(menuTitle: $menuTitle,
                         selectedMenuSubView: $selectedMenuSubView,
                         selectedDate: selectedDate)
        default:
            menuRootView
        }
    }

    private var menuSubViewContent: some View {
        MenuDestinationView(subview: selectedMenuSubView,
                            selectedGroup: $selectedGroup,
                            menuTitle: $menuTitle,
                            selectedMenuSubView: $selectedMenuSubView,
                            viewModel: viewModel,
                            selectedDate: selectedDate,
                            onBack: triggerMenuBackNavigation,
                            onOpenThemes: triggerOpenThemesNavigation,
                            onOpenAccessibility: triggerOpenAccessibilityNavigation,
                            onOpenAssistant: triggerOpenAssistantNavigation,
                            onSpeakSchedule: speakCurrentSchedule)
    }

    private var menuSubViewTransition: AnyTransition {
        let oldLevel = menuSubViewLevel(previousMenuSubView)
        let newLevel = menuSubViewLevel(selectedMenuSubView)
        let isBackNavigation = newLevel < oldLevel

        if isBackNavigation {
            return .asymmetric(insertion: .identity, removal: .move(edge: .trailing))
        } else {
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .opacity
            )
        }
    }

    private func menuSubViewLevel(_ subView: MenuSubView?) -> Int {
        switch subView {
        case nil:
            return 0
        case .groupSelection, .settings, .about, .developerTools:
            return 1
        case .themes, .accessibility, .assistant:
            return 2
        }
    }

    private var menuPageBackground: Color {
        if case .system = activeTheme.backgroundStyle {
#if os(iOS)
            return Color(UIColor.systemBackground)
#elseif os(macOS)
            return Color(NSColor.windowBackgroundColor)
#else
            return Color.clear
#endif
        }
        return Color.clear
    }

    private func triggerMenuBackNavigation() {
        guard selectedIndex == 4, selectedMenuSubView != nil else { return }
#if os(iOS)
        let width = UIScreen.main.bounds.width
#elseif os(macOS)
        let width = NSScreen.main?.frame.width ?? 800
#else
        let width: CGFloat = 800
#endif
        let currentSubView = selectedMenuSubView
        let targetSubView: MenuSubView?
        switch currentSubView {
        case .themes, .accessibility, .assistant:
            targetSubView = .settings
        default:
            targetSubView = nil
        }

        withAnimation(.interactiveSpring(response: menuBackSwipeConfig.completeResponse,
                                         dampingFraction: menuBackSwipeConfig.completeDamping)) {
            menuSubViewDragOffset = width
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                selectedMenuSubView = targetSubView
                menuTitle = (targetSubView == .settings) ? "Настройки" : "Меню"
                menuSubViewDragOffset = 0
                previousMenuSubView = targetSubView
            }
        }
    }

    private func triggerOpenThemesNavigation() {
        previousMenuSubView = .settings
        withAnimation(.easeInOut(duration: 0.18)) {
            menuTitle = "Темы"
            selectedMenuSubView = .themes
        }
    }

    private func triggerOpenAccessibilityNavigation() {
        previousMenuSubView = .settings
        withAnimation(.easeInOut(duration: 0.18)) {
            menuTitle = "Спец. возможности"
            selectedMenuSubView = .accessibility
        }
    }

    private func triggerOpenAssistantNavigation() {
        previousMenuSubView = .settings
        withAnimation(.easeInOut(duration: 0.18)) {
            menuTitle = "AI-ассистент"
            selectedMenuSubView = .assistant
        }
    }

    private func speakCurrentSchedule() {
        let speechText: String

        if viewModel.items.isEmpty {
            speechText = "На выбранную дату занятий нет."
        } else {
            let lines = viewModel.items.map { item in
                if accessibilitySpeechDetailed {
                    return "\(item.time). \(item.title). \(item.lessonType). Аудитория: \(item.room). Преподаватель: \(item.teacher)."
                } else {
                    return "\(item.time). \(item.title)."
                }
            }

            speechText = "Расписание на день. " + lines.joined(separator: " ")
        }

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: speechText)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        speechSynthesizer.speak(utterance)
    }

    private var interactiveMenuBackGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged(handleMenuBackSwipeChanged)
            .onEnded(handleMenuBackSwipeEnded)
    }

    private func handleMenuBackSwipeChanged(_ value: DragGesture.Value) {
        guard selectedIndex == 4, selectedMenuSubView != nil else { return }
        menuSubViewDragOffset = max(0, value.translation.width)
    }

    private func handleMenuBackSwipeEnded(_ value: DragGesture.Value) {
        guard selectedIndex == 4, selectedMenuSubView != nil else { return }

#if os(iOS)
        let width = UIScreen.main.bounds.width
#elseif os(macOS)
        let width = NSScreen.main?.frame.width ?? 800
#else
        let width: CGFloat = 800
#endif
        let predicted = value.predictedEndTranslation.width
        let shouldClose = menuSubViewDragOffset > width * menuBackSwipeConfig.triggerRatio
            || predicted > width * menuBackSwipeConfig.predictedTriggerRatio

        if shouldClose {
            triggerMenuBackNavigation()
        } else {
            withAnimation(.interactiveSpring(response: menuBackSwipeConfig.cancelResponse,
                                             dampingFraction: menuBackSwipeConfig.cancelDamping)) {
                menuSubViewDragOffset = 0
            }
        }
    }

    @ViewBuilder
    private var contentCapsuleBackground: some View {
#if os(iOS)
        if activeTheme.usesCloudSurface {
            activeTheme.cloudSurfaceFill
        } else {
            Color.mympsuHeaderCapsuleFill
        }
#else
        if #available(macOS 12.0, *) {
            Color.clear.background(.ultraThinMaterial)
        } else {
            Color(NSColor.windowBackgroundColor).opacity(0.88)
        }
#endif
    }

#if os(macOS)
    @ViewBuilder
    private var capsuleHeaderBackground: some View {
        if #available(macOS 12.0, *) {
            Color.clear.background(.ultraThinMaterial)
        } else {
            Color(NSColor.windowBackgroundColor).opacity(0.88)
        }
    }
#endif
#if os(macOS)
    private struct TitlebarSeparatorHider: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                if #available(macOS 13.0, *), let window = view.window {
                    window.titlebarSeparatorStyle = .none
                }
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {}
    }

    @available(macOS 13.0, *)
    struct SplitViewContent: View {
        let parent: ContentView

        private let sidebarItems: [(title: String, icon: String, tag: Int)] = [
            ("Расписание", "calendar", 0),
            ("Помощник МПГУ", "bubble.left.and.bubble.right.fill", 1),
            ("Сессия", "graduationcap.fill", 2),
            ("Аккаунт", "person.crop.circle.fill", 3),
            ("Меню", "line.3.horizontal", 4)
        ]

        var body: some View {
            NavigationSplitView {
                List(selection: parent.$selectedView) {
                    ForEach(sidebarItems, id: \.tag) { item in
                        Label(item.title, systemImage: item.icon)
                            .tag(item.tag)
                    }
                }
            } detail: {
                MainContentView(
                    selectedIndex: parent.selectedViewNonOptional,
                    selectedDate: parent.$selectedDate,
                    selectedGroup: parent.$selectedGroup,
                    scheduleViewModel: parent.viewModel,
                    menuTitle: parent.$menuTitle,
                    selectedMenuSubView: parent.$selectedMenuSubView,
                    speakCurrentSchedule: parent.speakCurrentSchedule
                )
            }
        }
    }
#endif
#if os(macOS)
    struct MainContentView: View {
        @Binding var selectedIndex: Int
        @Binding var selectedDate: Date
        @Binding var selectedGroup: MyGroup?
        @ObservedObject var scheduleViewModel: ScheduleViewModel
        @Binding var menuTitle: String
        @Binding var selectedMenuSubView: ContentView.MenuSubView?
        let speakCurrentSchedule: () -> Void
        @EnvironmentObject private var runtimeConfig: RuntimeConfigService
        @State private var isAccountPremiumPresented = false
        @State private var accountToolbarTitle = "Аккаунт"
        @State private var accountToolbarShowsBackButton = false
        @State private var accountToolbarBackRequest = 0
        @State private var accountToolbarShowsRefreshButton = false
        @State private var accountToolbarRefreshRequest = 0
        @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default

        private var activeTheme: AppTheme {
            AppThemeCatalog.theme(for: selectedThemeID)
        }

        private func title(for index: Int) -> String {
            switch index {
            case 0: return "Расписание"
            case 1: return "Помощник МПГУ"
            case 2: return "Сессия"
            case 3: return accountToolbarTitle
            case 4: return selectedMenuSubView == nil ? "Меню" : menuTitle
            default: return ""
            }
        }

        var body: some View {
            if selectedIndex == 1 {
                contentBody
            } else if #available(macOS 26.0, *) {
                contentBody
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            toolbarNavigationContent
                        }
                        .sharedBackgroundVisibility(.hidden)

                        ToolbarItemGroup(placement: .primaryAction) {
                            scheduleToolbarActions
                        }
                        .sharedBackgroundVisibility(.hidden)
                    }
            } else {
                contentBody
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            toolbarNavigationContent
                        }

                        ToolbarItemGroup(placement: .primaryAction) {
                            scheduleToolbarActions
                        }
                    }
            }
        }

        private var contentBody: some View {
            mainContent()
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .center)))
                .animation(.easeInOut(duration: 0.18), value: selectedIndex)
                .navigationTitle("")
                .modifier(MyMPSUMacWindowToolbarBackgroundModifier())
                .background(unifiedContentBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .fixedSize(horizontal: false, vertical: false)
        }

        @ViewBuilder
        private var toolbarNavigationContent: some View {
            if selectedIndex == 1 {
                EmptyView()
            } else {
                HStack(spacing: 8) {
                    if shouldShowToolbarBackButton {
                        toolbarBackButton
                    }
                    toolbarTitleCapsule(title(for: selectedIndex))
                }
                .padding(.leading, 16)
                .background(Color.clear)
                .fixedSize(horizontal: true, vertical: false)
                .animation(.easeInOut(duration: 0.18), value: accountToolbarTitle)
                .animation(.easeInOut(duration: 0.18), value: accountToolbarShowsBackButton)
                .animation(.easeInOut(duration: 0.18), value: selectedMenuSubView)
            }
        }

        private var shouldShowToolbarBackButton: Bool {
            (selectedIndex == 4 && selectedMenuSubView != nil) || (selectedIndex == 3 && accountToolbarShowsBackButton)
        }

        private var toolbarBackButton: some View {
            MyMPSUToolbarIconButton(shape: activeTheme.headerShape, systemImage: "chevron.left") {
                withAnimation(.easeInOut) {
                    if selectedIndex == 3 && accountToolbarShowsBackButton {
                        accountToolbarBackRequest += 1
                    } else if selectedMenuSubView == .themes || selectedMenuSubView == .accessibility || selectedMenuSubView == .assistant {
                        selectedMenuSubView = .settings
                        menuTitle = "Настройки"
                    } else {
                        selectedMenuSubView = nil
                        menuTitle = "Меню"
                    }
                }
            }
        }

        @ViewBuilder
        private var scheduleToolbarActions: some View {
            if selectedIndex == 0 {
                ThemedChrome(shape: activeTheme.dateShape) {
                    HStack(spacing: 4) {
                        Button {
                            let groupIdToLoad = selectedGroup?.id ?? scheduleViewModel.savedGroupId
                            guard !groupIdToLoad.isEmpty else { return }
                            Task {
                                await runtimeConfig.refresh(force: true)
                                await scheduleViewModel.load(for: groupIdToLoad, date: selectedDate, examOnly: false)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                                .frame(width: 16, height: 16)
                        }
                        .frame(width: 16, height: 44)
                        .buttonStyle(.plain)

                        CalendarDatePicker(
                            selectedDate: $selectedDate,
                            showsChrome: false,
                            showsCalendarIcon: true
                        )
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 164, height: 36, alignment: .center)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 36, alignment: .center)
                    .padding(.leading, 14)
                    .padding(.trailing, 8)
                    .padding(.vertical, 0)
                    .background(Color.clear)
                }
            } else if selectedIndex == 3 && accountToolbarShowsRefreshButton {
                MyMPSUToolbarIconButton(shape: activeTheme.headerShape, systemImage: "arrow.clockwise") {
                    accountToolbarRefreshRequest += 1
                }
                .accessibilityLabel("Обновить")
            } else {
                EmptyView()
            }
        }

        private func toolbarTitleCapsule(_ title: String) -> some View {
            MyMPSUToolbarTitleCapsule(shape: activeTheme.headerShape, title: title)
        }

        private func menuSubviewContent(_ subview: ContentView.MenuSubView) -> some View {
            MenuDestinationView(subview: subview,
                                selectedGroup: $selectedGroup,
                                menuTitle: $menuTitle,
                                selectedMenuSubView: $selectedMenuSubView,
                                viewModel: scheduleViewModel,
                                selectedDate: selectedDate,
                                onSpeakSchedule: speakCurrentSchedule)
        }

        @ViewBuilder
        private func mainContent() -> some View {
            switch selectedIndex {
            case 0:
                ScheduleView(viewModel: scheduleViewModel,
                             selectedDate: $selectedDate,
                             groupId: selectedGroup?.id ?? scheduleViewModel.savedGroupId)
                .background(unifiedContentBackground)
            case 1:
                AssistantChatView(selectedDate: selectedDate)
                    .background(unifiedContentBackground)
            case 2:
                ScheduleView(viewModel: scheduleViewModel,
                             selectedDate: $selectedDate,
                             groupId: selectedGroup?.id ?? scheduleViewModel.savedGroupId,
                             examOnly: true)
                .background(unifiedContentBackground)
            case 3:
                AccountView(scheduleViewModel: scheduleViewModel,
                            showPremiumScreen: $isAccountPremiumPresented,
                            toolbarTitle: $accountToolbarTitle,
                            toolbarShowsBackButton: $accountToolbarShowsBackButton,
                            toolbarBackRequest: $accountToolbarBackRequest,
                            toolbarShowsRefreshButton: $accountToolbarShowsRefreshButton,
                            toolbarRefreshRequest: $accountToolbarRefreshRequest)
                    .background(unifiedContentBackground)
            case 4:
                if #available(macOS 26.0, *) {
                    ZStack {
                        if let subview = selectedMenuSubView {
                            menuSubviewContent(subview)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            MenuView(viewModel: scheduleViewModel,
                                     selectedGroup: $selectedGroup,
                                     menuTitle: $menuTitle,
                                     selectedMenuSubView: $selectedMenuSubView)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut, value: selectedMenuSubView)
                    .background(unifiedContentBackground)
                } else {
                    VStack(spacing: 0) {
                        if selectedMenuSubView == nil {
                            MenuView(viewModel: scheduleViewModel,
                                     selectedGroup: $selectedGroup,
                                     menuTitle: $menuTitle,
                                     selectedMenuSubView: $selectedMenuSubView)
                        } else {
                            switch selectedMenuSubView {
                            case .groupSelection:
                                GroupSelectionView(selectedGroup: $selectedGroup,
                                                   menuTitle: $menuTitle,
                                                   selectedMenuSubView: $selectedMenuSubView,
                                                   viewModel: scheduleViewModel)
                            case .settings:
                                SettingsView(menuTitle: $menuTitle,
                                             selectedMenuSubView: $selectedMenuSubView)
                            case .themes:
                                ThemesSettingsView(menuTitle: $menuTitle,
                                                   selectedMenuSubView: $selectedMenuSubView)
                            case .about:
                                AboutAppView(menuTitle: $menuTitle,
                                             selectedMenuSubView: $selectedMenuSubView)
                            case .accessibility:
                                AccessibilitySettingsView(
                                    menuTitle: $menuTitle,
                                    selectedMenuSubView: $selectedMenuSubView,
                                    onSpeakSchedule: speakCurrentSchedule
                                )
                            case .developerTools:
                                DeveloperToolsView()
                            default:
                                EmptyView()
                            }
                        }
                    }
                    .background(unifiedContentBackground)
                }
            default:
                EmptyView()
            }
        }

        private var unifiedContentBackground: some View {
            Group {
#if os(macOS)
                ThemedBackground(theme: activeTheme)
#else
                Color.clear
#endif
            }
            .ignoresSafeArea()
        }
    }
#endif
#if os(macOS)
    struct DraggableHeaderView: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            let panGesture = NSPanGestureRecognizer(target: context.coordinator,
                                                    action: #selector(Coordinator.handleDrag))
            view.addGestureRecognizer(panGesture)
            return view
        }
        
        func updateNSView(_ nsView: NSView, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator()
        }
        
        class Coordinator: NSObject {
            @objc func handleDrag(_ sender: NSPanGestureRecognizer) {
                if let window = sender.view?.window, let event = NSApp.currentEvent {
                    window.performDrag(with: event)
                }
            }
        }
    }
#endif
}
