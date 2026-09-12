import SwiftUI

enum ThemedComponentShape: String, Codable, CaseIterable, Identifiable {
    case capsule
    case roundedCard
    case cloud

    var id: String { rawValue }
}

enum AppThemeBackgroundStyle: String, Codable, CaseIterable {
    case system
    case dreamySkyDay
    case dreamySkyNight
    case tokyoCityDay
    case tokyoCityNight
    case girlyVibesDay
    case girlyVibesNight
    case chuckNetworkDay
    case chuckNetworkNight
}

struct AppTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let backgroundStyle: AppThemeBackgroundStyle
    let headerShape: ThemedComponentShape
    let inputShape: ThemedComponentShape
    let preferredColorScheme: ColorScheme?
    let usesCloudSurface: Bool
    let usesCloudPattern: Bool
    let cloudSurfaceFill: Color
    let cloudSurfaceStroke: Color

    var dateShape: ThemedComponentShape { headerShape }

    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct AppThemeFamily: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let lightThemeID: String
    let darkThemeID: String
}

enum AppThemeCatalog {
    static let `default` = "system-light"

    static let families: [AppThemeFamily] = [
        AppThemeFamily(
            id: "system",
            name: "Системная",
            subtitle: "Чистый стандартный интерфейс.",
            lightThemeID: "system-light",
            darkThemeID: "system-dark"
        ),
        AppThemeFamily(
            id: "dreamy-sky",
            name: "Dreamy Sky",
            subtitle: "Мягкое небо и облачные поверхности.",
            lightThemeID: "dreamy-sky-day",
            darkThemeID: "dreamy-sky-night"
        ),
        AppThemeFamily(
            id: "tokyo-city",
            name: "Tokyo City",
            subtitle: "Городской неон для светлой и тёмной темы.",
            lightThemeID: "tokyo-city-day",
            darkThemeID: "tokyo-city-night"
        ),
        AppThemeFamily(
            id: "girly-vibes",
            name: "Girly Vibes",
            subtitle: "Мягкие розовые и лавандовые тона.",
            lightThemeID: "girly-vibes-day",
            darkThemeID: "girly-vibes-night"
        ),
        AppThemeFamily(
            id: "chuck-network",
            name: "Chuck Network",
            subtitle: "Свежая зелёная сетка и контраст.",
            lightThemeID: "chuck-network-day",
            darkThemeID: "chuck-network-night"
        )
    ]

    private static let themes: [String: AppTheme] = {
        let all: [AppTheme] = [
            AppTheme(
                id: "system-light",
                name: "Системная светлая",
                backgroundStyle: .system,
                headerShape: .capsule,
                inputShape: .roundedCard,
                preferredColorScheme: .light,
                usesCloudSurface: false,
                usesCloudPattern: false,
                cloudSurfaceFill: Color.white.opacity(0.78),
                cloudSurfaceStroke: Color.white.opacity(0.28)
            ),
            AppTheme(
                id: "system-dark",
                name: "Системная тёмная",
                backgroundStyle: .system,
                headerShape: .capsule,
                inputShape: .roundedCard,
                preferredColorScheme: .dark,
                usesCloudSurface: false,
                usesCloudPattern: false,
                cloudSurfaceFill: Color.white.opacity(0.12),
                cloudSurfaceStroke: Color.white.opacity(0.18)
            ),
            AppTheme(
                id: "dreamy-sky-day",
                name: "Dreamy Sky Day",
                backgroundStyle: .dreamySkyDay,
                headerShape: .cloud,
                inputShape: .roundedCard,
                preferredColorScheme: .light,
                usesCloudSurface: true,
                usesCloudPattern: true,
                cloudSurfaceFill: Color.white.opacity(0.78),
                cloudSurfaceStroke: Color.white.opacity(0.48)
            ),
            AppTheme(
                id: "dreamy-sky-night",
                name: "Dreamy Sky Night",
                backgroundStyle: .dreamySkyNight,
                headerShape: .cloud,
                inputShape: .roundedCard,
                preferredColorScheme: .dark,
                usesCloudSurface: true,
                usesCloudPattern: true,
                cloudSurfaceFill: Color.white.opacity(0.13),
                cloudSurfaceStroke: Color.white.opacity(0.20)
            ),
            AppTheme(
                id: "tokyo-city-day",
                name: "Tokyo City Day",
                backgroundStyle: .tokyoCityDay,
                headerShape: .capsule,
                inputShape: .roundedCard,
                preferredColorScheme: .light,
                usesCloudSurface: false,
                usesCloudPattern: false,
                cloudSurfaceFill: Color.white.opacity(0.70),
                cloudSurfaceStroke: Color.white.opacity(0.28)
            ),
            AppTheme(
                id: "tokyo-city-night",
                name: "Tokyo City Night",
                backgroundStyle: .tokyoCityNight,
                headerShape: .capsule,
                inputShape: .roundedCard,
                preferredColorScheme: .dark,
                usesCloudSurface: false,
                usesCloudPattern: false,
                cloudSurfaceFill: Color.white.opacity(0.12),
                cloudSurfaceStroke: Color.white.opacity(0.20)
            ),
            AppTheme(
                id: "girly-vibes-day",
                name: "Girly Vibes Day",
                backgroundStyle: .girlyVibesDay,
                headerShape: .roundedCard,
                inputShape: .roundedCard,
                preferredColorScheme: .light,
                usesCloudSurface: false,
                usesCloudPattern: false,
                cloudSurfaceFill: Color.white.opacity(0.72),
                cloudSurfaceStroke: Color.white.opacity(0.32)
            ),
            AppTheme(
                id: "girly-vibes-night",
                name: "Girly Vibes Night",
                backgroundStyle: .girlyVibesNight,
                headerShape: .roundedCard,
                inputShape: .roundedCard,
                preferredColorScheme: .dark,
                usesCloudSurface: false,
                usesCloudPattern: false,
                cloudSurfaceFill: Color.white.opacity(0.14),
                cloudSurfaceStroke: Color.white.opacity(0.20)
            ),
            AppTheme(
                id: "chuck-network-day",
                name: "Chuck Network Day",
                backgroundStyle: .chuckNetworkDay,
                headerShape: .capsule,
                inputShape: .roundedCard,
                preferredColorScheme: .light,
                usesCloudSurface: false,
                usesCloudPattern: false,
                cloudSurfaceFill: Color.white.opacity(0.70),
                cloudSurfaceStroke: Color.white.opacity(0.30)
            ),
            AppTheme(
                id: "chuck-network-night",
                name: "Chuck Network Night",
                backgroundStyle: .chuckNetworkNight,
                headerShape: .capsule,
                inputShape: .roundedCard,
                preferredColorScheme: .dark,
                usesCloudSurface: false,
                usesCloudPattern: false,
                cloudSurfaceFill: Color.white.opacity(0.12),
                cloudSurfaceStroke: Color.white.opacity(0.20)
            )
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    static func theme(for id: String) -> AppTheme {
        themes[id] ?? themes[Self.default]!
    }
}
