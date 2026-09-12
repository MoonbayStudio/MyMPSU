package ru.moonbaystudio.mympsu.ui.theme

import androidx.compose.ui.graphics.Color

enum class ThemedComponentShape {
    CAPSULE, ROUNDED_CARD, CLOUD
}

enum class ThemeBackgroundStyle {
    SYSTEM, DREAMY_SKY_DAY, DREAMY_SKY_NIGHT, TOKYO_CITY_DAY, TOKYO_CITY_NIGHT, GIRLY_VIBES_DAY, GIRLY_VIBES_NIGHT, CHUCK_NETWORK_DAY, CHUCK_NETWORK_NIGHT
}

data class AppTheme(
    val id: String,
    val name: String,
    val subtitle: String,
    val headerShape: ThemedComponentShape,
    val dateShape: ThemedComponentShape,
    val inputShape: ThemedComponentShape,
    val backgroundStyle: ThemeBackgroundStyle,
    val usesCloudPattern: Boolean,
    val isDark: Boolean,
    val primaryColor: Color
) {
    val usesCloudSurface: Boolean
        get() = headerShape == ThemedComponentShape.CLOUD || dateShape == ThemedComponentShape.CLOUD || usesCloudPattern

    val cloudSurfaceFill: Color
        get() = if (backgroundStyle == ThemeBackgroundStyle.DREAMY_SKY_NIGHT) {
            Color.Black.copy(alpha = 0.18f)
        } else {
            Color.White.copy(alpha = 0.26f)
        }

    val cloudSurfaceStroke: Color
        get() = if (backgroundStyle == ThemeBackgroundStyle.DREAMY_SKY_NIGHT) {
            Color.White.copy(alpha = 0.07f)
        } else {
            Color.White.copy(alpha = 0.34f)
        }
}

data class AppThemeFamily(
    val id: String,
    val name: String,
    val subtitle: String,
    val lightThemeID: String,
    val darkThemeID: String
)

object AppThemeCatalog {
    val families = listOf(
        AppThemeFamily("standard", "Стандартная", "Спокойный системный стиль без декоративного фона.", "classic", "classic-dark"),
        AppThemeFamily("clouds", "Облачно", "Мягкое небо, облака и легкая воздушная подложка.", "dreamy-clouds-day", "dreamy-clouds-night"),
        AppThemeFamily("tokyo-city", "Токио Сити", "Городской неон, стекло и холодные контрастные акценты.", "tokyo-city-day", "tokyo-city-night"),
        AppThemeFamily("girly-vibes", "Девчачие вайбы", "Розовые, ягодные и лавандовые оттенки с мягким светом.", "girly-vibes-day", "girly-vibes-night"),
        AppThemeFamily("chuck-network", "Чак нетворк", "Неон, сетка и энергичная цифровая атмосфера.", "chuck-network-day", "chuck-network-night")
    )

    val themes = listOf(
        AppTheme("classic", "Стандартная • Светлая", "Системная светлая тема", ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.SYSTEM, false, false, Purple40),
        AppTheme("classic-dark", "Стандартная • Темная", "Системная темная тема", ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.SYSTEM, false, true, Purple80),
        AppTheme("dreamy-clouds-day", "Облачно • Светлая", "Небо и мягкие облака", ThemedComponentShape.CLOUD, ThemedComponentShape.CLOUD, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.DREAMY_SKY_DAY, true, false, Color(0xFF007AFF)),
        AppTheme("dreamy-clouds-night", "Облачно • Темная", "Ночное небо, звезды и темные облака", ThemedComponentShape.CLOUD, ThemedComponentShape.CLOUD, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.DREAMY_SKY_NIGHT, true, true, Color(0xFF5AC8FA)),
        AppTheme("tokyo-city-day", "Токио Сити • Светлая", "Светлый городской неон", ThemedComponentShape.ROUNDED_CARD, ThemedComponentShape.ROUNDED_CARD, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.TOKYO_CITY_DAY, false, false, TokyoDayAccent),
        AppTheme("tokyo-city-night", "Токио Сити • Темная", "Ночной город и неоновые линии", ThemedComponentShape.ROUNDED_CARD, ThemedComponentShape.ROUNDED_CARD, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.TOKYO_CITY_NIGHT, false, true, TokyoNightAccent),
        AppTheme("girly-vibes-day", "Девчачие вайбы • Светлая", "Розовый свет и лавандовая база", ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.GIRLY_VIBES_DAY, false, false, GirlyDayAccent),
        AppTheme("girly-vibes-night", "Девчачие вайбы • Темная", "Ягодный градиент и мягкий неон", ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.GIRLY_VIBES_NIGHT, false, true, GirlyNightAccent),
        AppTheme("chuck-network-day", "Чак нетворк • Светлая", "Цифровая сетка и кислотный акцент", ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.CHUCK_NETWORK_DAY, false, false, ChuckDayAccent),
        AppTheme("chuck-network-night", "Чак нетворк • Темная", "Черный неон и сетевой glow", ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemedComponentShape.CAPSULE, ThemeBackgroundStyle.CHUCK_NETWORK_NIGHT, false, true, ChuckNightAccent)
    )

    fun theme(id: String): AppTheme = themes.find { it.id == id } ?: themes[0]
}
