//
//  LaunchView.swift
//  MyMPSU
//
//  Created by Nicolas Forest on 10/1/25.
//

import SwiftUI

struct LaunchView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showLogo = false
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            ThemedBackground(theme: activeTheme)
                .ignoresSafeArea()

            ZStack {
                VStack(spacing: 12) {
                    Image(launchIconName)
                        .resizable()
                        .frame(width: 200, height: 200)
                        .foregroundColor(.white)
                        .opacity(showLogo ? 1 : 0)
                        .animation(.easeIn(duration: 0.5), value: showLogo)

                    Text("Добро пожаловать")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(launchTextColor)
                        .opacity(showLogo ? 1 : 0)
                        .animation(.easeIn(duration: 0.5), value: showLogo)

                    Text("в Мой МПГУ")
                        .font(.system(size: 24))
                        .foregroundColor(launchTextColor)
                        .opacity(showLogo ? 1 : 0)
                        .animation(.easeIn(duration: 0.5), value: showLogo)
                }
                VStack {
                    Spacer()

                    Text("Moonbay Studio")
                        .font(.system(size: 12))
                        .foregroundColor(launchTextColor)
                        .opacity(showLogo ? 1 : 0)
                        .animation(.easeIn(duration: 0.5), value: showLogo)
                        .padding(.bottom, 20)

                    Text("Версия 0.9 альфа")
                        .font(.system(size: 12))
                        .foregroundColor(launchTextColor)
                        .opacity(showLogo ? 1 : 0)
                        .animation(.easeIn(duration: 0.5), value: showLogo)
                        .padding(.bottom, 20)
                }
            }
        }
        .preferredColorScheme(activeColorScheme)
        .onAppear {
            showLogo = true
            Task {
                await UserSettingsSyncService.syncRemoteSettingsIfAuthenticated()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onFinished()
            }
        }
    }

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    private var activeColorScheme: ColorScheme? {
        if let forced = activeTheme.preferredColorScheme {
            return forced
        }
        return useSystemTheme ? nil : (isDarkMode ? .dark : .light)
    }

    private var launchTextColor: Color {
        isLaunchDarkMode ? .white : Color(hex: "1260C4")
    }

    private var launchIconName: String {
        isLaunchDarkMode ? "mpsuicondark" : "mpsuicon"
    }

    private var isLaunchDarkMode: Bool {
        activeColorScheme == .dark || (activeColorScheme == nil && systemColorScheme == .dark)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
