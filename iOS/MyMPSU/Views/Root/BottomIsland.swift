import SwiftUI

struct BottomIsland: View {
    @Binding var selectedIndex: Int
    @Binding var refreshPromptIndex: Int?
    var onRefreshSelectedTab: (_ index: Int) -> Void = { _ in }
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    private let items: [(title: String, icon: String)] = [
        ("Расписание", "calendar"),
        ("AI", "bubble.left.and.bubble.right.fill"),
        ("Сессия", "graduationcap.fill"),
        ("Аккаунт", "person.crop.circle.fill"),
        ("Меню", "line.3.horizontal")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    handleTap(on: index)
                } label: {
                    let displayItem = item(for: index)
                    VStack(spacing: 3) {
                        Image(systemName: displayItem.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(displayItem.title)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(selectedIndex == index ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(itemBackground(isSelected: selectedIndex == index))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(maxWidth: 560)
        .mympsuAdaptiveGlassCard(cornerRadius: 26)
        .padding(.horizontal, 12)
    }

    private func handleTap(on index: Int) {
        let supportsInlineRefresh = index == 0 || index == 2
        withAnimation(.easeInOut(duration: 0.18)) {
            if selectedIndex == index, supportsInlineRefresh {
                if refreshPromptIndex == index {
                    refreshPromptIndex = nil
                    onRefreshSelectedTab(index)
                } else {
                    refreshPromptIndex = index
                }
            } else {
                selectedIndex = index
                refreshPromptIndex = nil
            }
        }
    }

    private func item(for index: Int) -> (title: String, icon: String) {
        if refreshPromptIndex == index {
            return ("Обновить", "arrow.clockwise")
        }

        return items[index]
    }

    @ViewBuilder
    private func itemBackground(isSelected: Bool) -> some View {
        if isSelected {
            Color.accentColor
        } else if activeTheme.usesCloudSurface {
            activeTheme.cloudSurfaceFill.opacity(0.5)
        } else {
            Color.clear
        }
    }
}
