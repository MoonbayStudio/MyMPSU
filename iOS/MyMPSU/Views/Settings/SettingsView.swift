import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    @AppStorage("offlineScheduleEnabled") private var offlineScheduleEnabled = true
    @AppStorage("offlineScheduleWeeks") private var offlineScheduleWeeks = 1
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @AppStorage("assistantDefaultPersona") private var assistantDefaultPersona = AssistantPersona.pelikasha.rawValue
#if os(iOS)
    @StateObject private var appLockManager = AppLockManager.shared
    @State private var showsAppLockSetup = false
#endif
    @State private var isRefreshingGroups = false
    @Binding var menuTitle: String
    @Binding var selectedMenuSubView: ContentView.MenuSubView?
    var selectedDate: Date = Date()
    var onBack: (() -> Void)? = nil
    var onOpenThemes: (() -> Void)? = nil
    var onOpenAccessibility: (() -> Void)? = nil
    var onOpenAssistant: (() -> Void)? = nil

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
#if os(iOS)
                titleBackHeader("Настройки")
#endif

#if os(macOS)
                Button {
                    withAnimation(.easeInOut) {
                        menuTitle = "Темы"
                        selectedMenuSubView = .themes
                    }
                } label: {
                    HStack {
                        Label("Темы", systemImage: "paintpalette.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .mympsuDefaultSurface()
                }
                .mympsuInteractiveButtonStyle()
#else
                Button {
                    if let onOpenThemes {
                        onOpenThemes()
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            menuTitle = "Темы"
                            selectedMenuSubView = .themes
                        }
                    }
                } label: {
                    HStack {
                        Label("Темы", systemImage: "paintpalette.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .mympsuDefaultSurface()
                }
                .mympsuInteractiveButtonStyle()
#endif

#if os(macOS)
                Button {
                    withAnimation(.easeInOut) {
                        menuTitle = "Спец. возможности"
                        selectedMenuSubView = .accessibility
                    }
                } label: {
                    HStack {
                        Label("Спец. возможности", systemImage: "figure.stand")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .mympsuDefaultSurface()
                }
                .mympsuInteractiveButtonStyle()
#else
                Button {
                    if let onOpenAccessibility {
                        onOpenAccessibility()
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            menuTitle = "Спец. возможности"
                            selectedMenuSubView = .accessibility
                        }
                    }
                } label: {
                    HStack {
                        Label("Спец. возможности", systemImage: "figure.stand")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .mympsuDefaultSurface()
                }
                .mympsuInteractiveButtonStyle()
#endif

                MyMPSUSettingsCard {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Персонаж по умолчанию")
                                .font(.subheadline.weight(.semibold))
                            Text("Используется при открытии чата.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    Picker("Персонаж по умолчанию", selection: $assistantDefaultPersona) {
                        ForEach(AssistantPersona.allCases) { persona in
                            Text(persona.displayName).tag(persona.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if developerModeEnabled {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            menuTitle = "Игрушки разработчика"
                            selectedMenuSubView = .developerTools
                        }
                    } label: {
                        HStack {
                            Label("Игрушки разработчика", systemImage: "hammer.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .mympsuDefaultSurface()
                    }
                    .mympsuInteractiveButtonStyle()
                }

                MyMPSUSettingsCard {
                    Toggle(isOn: $useSystemTheme) {
                        Label("Использовать системную тему", systemImage: "circle.lefthalf.filled")
                    }
#if os(macOS)
                    Text("Если цвета сломались, нажмите Alt+Tab или щёлкните за пределами приложения.")
                        .font(.caption)
                        .foregroundColor(.secondary)
#endif
                }

                if !useSystemTheme {
                    MyMPSUSettingsCard {
                        Toggle(isOn: $isDarkMode) {
                            Label("Тёмная тема", systemImage: "moon.fill")
                        }
                    }
                }

                MyMPSUSettingsCard {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Активные уведомления", systemImage: "bell.fill")
                    }
                    .disabled(!LiveActivityManager.shared.isSupported)
#if os(macOS)
                    Text("Если у вас есть iPhone, привязанный к этому Mac через iCloud, активные уведомления будут работать и здесь.")
                        .font(.caption)
                        .foregroundColor(.secondary)
#endif
                }

#if os(iOS)
                appLockSettingsSection
#endif

                MyMPSUSettingsCard {
                    Toggle(isOn: $offlineScheduleEnabled) {
                        Label("Офлайн-режим расписания", systemImage: "externaldrive.fill")
                    }

                    if offlineScheduleEnabled {
                        Stepper(value: $offlineScheduleWeeks, in: 1 ... 4) {
                            HStack {
                                Label("Кэш на недель", systemImage: "calendar.badge.clock")
                                Spacer()
                                Text("\(offlineScheduleWeeks)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button {
                        refreshGroupsCache()
                    } label: {
                        HStack {
                            Label(
                                isRefreshingGroups ? "Обновляем список групп" : "Обновить список групп",
                                systemImage: "arrow.clockwise"
                            )
                            Spacer()
                            if isRefreshingGroups {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isRefreshingGroups)
                    .mympsuInteractiveButtonStyle()

                    Text("Используйте редко и только при необходимости, чтобы приложение не дёргало API без повода.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuControlTintStyle()
#if os(iOS)
        .sheet(isPresented: $showsAppLockSetup) {
            AppLockSetupView(lockManager: appLockManager) {
                showsAppLockSetup = false
            }
        }
#endif
        .onAppear {
            if !(1...4).contains(offlineScheduleWeeks) {
                offlineScheduleWeeks = 1
            }
        }
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
    }

#if os(iOS)
    private var appLockSettingsSection: some View {
        MyMPSUSettingsCard {
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
        }
    }

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
    private func titleBackHeader(_ title: String) -> some View {
        MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: title) {
            if let onBack {
                onBack()
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedMenuSubView = nil
                    menuTitle = "Меню"
                }
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    private func refreshGroupsCache() {
        guard !isRefreshingGroups else { return }
        isRefreshingGroups = true
        Task {
            await APIService.shared.refreshInstitutesWithGroupsCache()
            await MainActor.run {
                isRefreshingGroups = false
            }
        }
    }
}
