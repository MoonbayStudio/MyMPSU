import SwiftUI

struct AboutAppView: View {
    @Binding var menuTitle: String
    @Binding var selectedMenuSubView: ContentView.MenuSubView?
    var onBack: (() -> Void)? = nil
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
#if os(iOS)
                MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "О приложении") {
                    dismiss()
                }
#endif
                MyMPSUSettingsCard {
                    Label("Мой МПГУ", systemImage: "graduationcap.fill")
                        .font(.title3.weight(.semibold))
                    Text("Расписание, аккаунт и учебные инструменты МПГУ.")
                        .foregroundColor(.secondary)
                    Text("Версия \(appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.9"
    }

    private func dismiss() {
        if let onBack {
            onBack()
        } else {
            selectedMenuSubView = nil
            menuTitle = "Меню"
        }
    }
}
