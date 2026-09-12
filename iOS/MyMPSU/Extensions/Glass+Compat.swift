import SwiftUI

#if os(macOS)
struct MyMPSUMacWindowToolbarBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else if #available(macOS 13.0, *) {
            content
                .toolbarBackground(.hidden, for: .windowToolbar)
        } else {
            content
        }
    }
}
#endif

extension Color {
    static var mympsuHeaderCapsuleFill: Color {
#if os(macOS)
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor.white.withAlphaComponent(0.10)
                : NSColor.black.withAlphaComponent(0.055)
        })
#else
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.055)
        })
#endif
    }

    static var mympsuSurfaceStrokeBase: Color {
#if os(macOS)
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor.white : NSColor.black
        })
#else
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
        })
#endif
    }

    static var mympsuControlTint: Color {
#if os(macOS)
        Color.mympsuHeaderCapsuleFill
#else
        Color.accentColor
#endif
    }
}

private struct MyMPSUDisableLiveMaterialKey: EnvironmentKey {
    static let defaultValue = false
}

private struct MyMPSUSurfaceStrokeOpacityKey: EnvironmentKey {
    static let defaultValue: Double = 0.22
}

extension EnvironmentValues {
    var mympsuDisableLiveMaterial: Bool {
        get { self[MyMPSUDisableLiveMaterialKey.self] }
        set { self[MyMPSUDisableLiveMaterialKey.self] = newValue }
    }

    var mympsuSurfaceStrokeOpacity: Double {
        get { self[MyMPSUSurfaceStrokeOpacityKey.self] }
        set { self[MyMPSUSurfaceStrokeOpacityKey.self] = newValue }
    }
}

struct MyMPSUAdaptiveMaterialFill: View {
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @Environment(\.mympsuDisableLiveMaterial) private var disableLiveMaterial

    var body: some View {
        if activeTheme.usesCloudSurface {
            activeTheme.cloudSurfaceFill
        } else {
#if os(macOS)
            if #available(macOS 12.0, *) {
                if disableLiveMaterial {
                    Color(NSColor.windowBackgroundColor).opacity(0.88)
                } else {
                    Color.clear.background(.ultraThinMaterial)
                }
            } else {
                Color(NSColor.windowBackgroundColor).opacity(0.88)
            }
#else
            if #available(iOS 16.0, *) {
                if disableLiveMaterial {
                    Color(UIColor.secondarySystemBackground).opacity(0.88)
                } else {
                    Color.clear.background(.ultraThinMaterial)
                }
            } else {
                Color(UIColor.secondarySystemBackground)
            }
#endif
        }
    }

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }
}

struct MyMPSUBackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MyMPSUToolbarTitleCapsule: View {
    let shape: ThemedComponentShape
    let title: String
    var systemImage: String? = nil
    var iconColor: Color = .accentColor

    var body: some View {
        ThemedChrome(shape: shape) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(height: 36)
            .background(Color.clear)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct MyMPSUToolbarIconButton: View {
    let shape: ThemedComponentShape
    let systemImage: String
    let action: () -> Void

    var body: some View {
        ThemedChrome(shape: shape) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(Color.clear)
        }
    }
}

struct MyMPSUTitleBackHeader: View {
    let shape: ThemedComponentShape
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ThemedChrome(shape: shape) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background(Color.clear)
            }

            ThemedChrome(shape: shape) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.clear)
            }
        }
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
