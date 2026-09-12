import SwiftUI

struct ThemesSettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var menuTitle: String
    @Binding var selectedMenuSubView: ContentView.MenuSubView?
    var onBack: (() -> Void)? = nil
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    private var activeTheme: AppTheme { AppThemeCatalog.theme(for: selectedThemeID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
#if os(iOS)
                titleBackHeader("Темы")
#endif

                VStack(alignment: .leading, spacing: 12) {
                    Text("Оформление")
                        .font(.headline)

                    ForEach(AppThemeCatalog.families) { family in
                        themeFamilyCard(family)
                    }
                }
                .mympsuDefaultSurface()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
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

    private func themeFamilyCard(_ family: AppThemeFamily) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(family.name)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(family.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isFamilySelected(family) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }

            HStack(spacing: 8) {
                themeVariantButton(title: "Светлая", themeID: family.lightThemeID, systemImage: "sun.max.fill")
                themeVariantButton(title: "Темная", themeID: family.darkThemeID, systemImage: "moon.fill")
            }
        }
        .mympsuDefaultSurface(cornerRadius: 16, padding: 12)
    }

    private func themeVariantButton(title: String, themeID: String, systemImage: String) -> some View {
        Button {
            selectedThemeID = themeID
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if selectedThemeID == themeID {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundColor(selectedThemeID == themeID ? .white : .primary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(variantBackground(isSelected: selectedThemeID == themeID))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func variantBackground(isSelected: Bool) -> some View {
        if isSelected {
            Color.accentColor
        } else {
            Color.mympsuHeaderCapsuleFill
        }
    }

    private func isFamilySelected(_ family: AppThemeFamily) -> Bool {
        selectedThemeID == family.lightThemeID || selectedThemeID == family.darkThemeID
    }
}
