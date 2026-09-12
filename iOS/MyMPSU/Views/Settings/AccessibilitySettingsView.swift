import SwiftUI

struct AccessibilitySettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("accessibilityReduceMotion") private var reduceMotion = false
    @AppStorage("accessibilityHighContrast") private var highContrast = false
    @AppStorage("accessibilityLargerText") private var largerText = false
    @AppStorage("accessibilityAutoSpeakSchedule") private var autoSpeakSchedule = false
    @AppStorage("accessibilitySpeechDetailed") private var detailedSpeech = true
    @AppStorage("accessibilityHapticsEnabled") private var hapticsEnabled = true
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default

    @Binding var menuTitle: String
    @Binding var selectedMenuSubView: ContentView.MenuSubView?
    var onBack: (() -> Void)? = nil
    var onSpeakSchedule: (() -> Void)? = nil
    private var activeTheme: AppTheme { AppThemeCatalog.theme(for: selectedThemeID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
#if os(iOS)
            titleBackHeader("Спец. возможности")
#endif

            MyMPSUSettingsCard {
                Toggle(isOn: $reduceMotion) {
                    Label("Уменьшить движение", systemImage: "figure.walk.motion")
                }

                Toggle(isOn: $highContrast) {
                    Label("Повышенный контраст", systemImage: "circle.lefthalf.filled")
                }

                Toggle(isOn: $largerText) {
                    Label("Увеличенный текст", systemImage: "textformat.size")
                }

                Toggle(isOn: $hapticsEnabled) {
                    Label("Тактильный отклик", systemImage: "iphone.radiowaves.left.and.right")
                }

                Toggle(isOn: $autoSpeakSchedule) {
                    Label("Автоозвучка расписания", systemImage: "speaker.wave.2.fill")
                }

                Toggle(isOn: $detailedSpeech) {
                    Label("Подробная озвучка", systemImage: "text.quote")
                }

                Button {
                    onSpeakSchedule?()
                } label: {
                    HStack {
                        Label("Озвучить текущее расписание", systemImage: "waveform")
                        Spacer()
                        Image(systemName: "play.fill")
                            .foregroundColor(.secondary)
                    }
                    .mympsuDefaultSurface()
                }
                .mympsuInteractiveButtonStyle()
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .mympsuControlTintStyle()
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
    }

    @ViewBuilder
    private func titleBackHeader(_ title: String) -> some View {
        MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: title) {
            if let onBack {
                onBack()
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedMenuSubView = .settings
                    menuTitle = "Настройки"
                }
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
