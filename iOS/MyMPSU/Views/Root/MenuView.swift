import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
struct InvertedHighlightButtonStyle: ButtonStyle {
    var normalColor: Color = .white
    var pressedColor: Color = .gray

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? pressedColor : normalColor)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if #available(macOS 14.0, *) {
                        Color.clear.background(.ultraThinMaterial)
                    } else {
                        #if os(macOS)
                        Color(NSColor.windowBackgroundColor).opacity(0.8)
                        #endif
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
    }
}
#endif
struct MenuView: View {
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var selectedGroup: MyGroup?
    @Binding var menuTitle: String
    @Binding var selectedMenuSubView: ContentView.MenuSubView?
    @State private var showAbout = false

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }
    
    var body: some View {
#if os(macOS)
ZStack {
    ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 14) {
            // macOS 26+ — menu buttons only
            Button(action: {
                withAnimation(.easeInOut) {
                    selectedMenuSubView = .groupSelection
                    menuTitle = "Выбор группы"
                }
            }) {
                HStack {
                    Image(systemName: "person.3.fill")
                    Text("Выбор группы")
                    Spacer()
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
            
            Button(action: {
                withAnimation(.easeInOut) {
                    selectedMenuSubView = .settings
                    menuTitle = "Настройки"
                }
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Настройки")
                    Spacer()
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
            
            Button(action: {
                withAnimation {
                    showAbout.toggle()
                    menuTitle = "О приложении"
                    selectedMenuSubView = .about
                }
            }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                    Text("О приложении")
                    Spacer()
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        }
    }
    .blur(radius: showAbout ? 3 : 0)
    .allowsHitTesting(!showAbout)
    
    if showAbout {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showAbout = false
                        selectedMenuSubView = nil
                        menuTitle = "Меню"
                    }
                }
            
            if #available(macOS 12.0, *) {
                AboutAppView(menuTitle: $menuTitle, selectedMenuSubView: $selectedMenuSubView)
                    .frame(minWidth: 600, idealWidth: 600, maxWidth: 600,
                           minHeight: 700, idealHeight: 700, maxHeight: 700)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .shadow(radius: 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: showAbout)
            } else {
                // Fallback on earlier versions
            }
        }
    }
#else
        VStack(alignment: .leading, spacing: 16) {
            // Header
                ThemedChrome(shape: activeTheme.headerShape) {
                    Text("Меню")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .frame(height: 44)
                        .background(Color.clear)
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedMenuSubView = .groupSelection
                    menuTitle = "Выбор группы"
                }
            } label: {
                HStack {
                    Image(systemName: "person.3.fill")
                    Text("Выбор группы")
                    Spacer()
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
            .padding(.horizontal, 16)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedMenuSubView = .settings
                    menuTitle = "Настройки"
                }
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Настройки")
                    Spacer()
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
            .padding(.horizontal, 16)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedMenuSubView = .about
                    menuTitle = "О приложении"
                }
            }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                    Text("О приложении")
                    Spacer()
                }
                .mympsuDefaultSurface()
            }
            .mympsuInteractiveButtonStyle()
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
#endif
    }

    @ViewBuilder
    private var menuButtonBackground: some View {
#if os(iOS)
        if #available(iOS 15.0, *) {
            Color.clear.background(.ultraThinMaterial)
        } else {
            Color.gray.opacity(0.2)
        }
#else
        Color.gray.opacity(0.2)
#endif
    }

}
