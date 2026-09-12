import SwiftUI

struct MenuDestinationView: View {
    let subview: ContentView.MenuSubView?
    @Binding var selectedGroup: MyGroup?
    @Binding var menuTitle: String
    @Binding var selectedMenuSubView: ContentView.MenuSubView?
    @ObservedObject var viewModel: ScheduleViewModel
    var selectedDate: Date = Date()
    var onBack: (() -> Void)? = nil
    var onOpenThemes: (() -> Void)? = nil
    var onOpenAccessibility: (() -> Void)? = nil
    var onOpenAssistant: (() -> Void)? = nil
    var onSpeakSchedule: (() -> Void)? = nil

    var body: some View {
        switch subview {
        case .groupSelection:
            GroupSelectionView(
                selectedGroup: $selectedGroup,
                menuTitle: $menuTitle,
                selectedMenuSubView: $selectedMenuSubView,
                viewModel: viewModel,
                onBack: onBack
            )
        case .settings:
            SettingsView(
                menuTitle: $menuTitle,
                selectedMenuSubView: $selectedMenuSubView,
                selectedDate: selectedDate,
                onBack: onBack,
                onOpenThemes: onOpenThemes,
                onOpenAccessibility: onOpenAccessibility,
                onOpenAssistant: onOpenAssistant
            )
        case .themes:
            ThemesSettingsView(menuTitle: $menuTitle, selectedMenuSubView: $selectedMenuSubView, onBack: onBack)
        case .accessibility:
            AccessibilitySettingsView(
                menuTitle: $menuTitle,
                selectedMenuSubView: $selectedMenuSubView,
                onBack: onBack,
                onSpeakSchedule: onSpeakSchedule
            )
        case .assistant:
            AssistantChatView(selectedDate: selectedDate, onBack: onBack)
        case .about:
            AboutAppView(menuTitle: $menuTitle, selectedMenuSubView: $selectedMenuSubView, onBack: onBack)
        case .developerTools:
            DeveloperToolsView(onBack: onBack)
        case nil:
            EmptyView()
        }
    }
}
