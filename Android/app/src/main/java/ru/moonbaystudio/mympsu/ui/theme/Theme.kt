package ru.moonbaystudio.mympsu.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = Purple80,
    secondary = PurpleGrey80,
    tertiary = Pink80
)

private val LightColorScheme = lightColorScheme(
    primary = Purple40,
    secondary = PurpleGrey40,
    tertiary = Pink40
)

private val HighContrastLight = lightColorScheme(
    primary = Color.Black,
    onPrimary = Color.White,
    secondary = Color(0xFF0000FF),
    onSecondary = Color.White,
    background = Color.White,
    onBackground = Color.Black,
    surface = Color.White,
    onSurface = Color.Black,
    error = Color(0xFFB00020),
    onError = Color.White
)

private val HighContrastDark = darkColorScheme(
    primary = Color.White,
    onPrimary = Color.Black,
    secondary = Color(0xFFFFFF00),
    onSecondary = Color.Black,
    background = Color.Black,
    onBackground = Color.White,
    surface = Color.Black,
    onSurface = Color.White,
    error = Color(0xFFCF6679),
    onError = Color.Black
)

@Composable
fun MyMPSUTheme(
    appTheme: AppTheme = AppThemeCatalog.theme("classic"),
    highContrast: Boolean = false,
    largerText: Boolean = false,
    content: @Composable () -> Unit
) {
    val baseColorScheme = if (highContrast) {
        if (appTheme.isDark) HighContrastDark else HighContrastLight
    } else {
        when (appTheme.backgroundStyle) {
            ThemeBackgroundStyle.DREAMY_SKY_DAY -> lightColorScheme(primary = Color(0xFF007AFF), secondary = Color(0xFF5AC8FA))
            ThemeBackgroundStyle.DREAMY_SKY_NIGHT -> darkColorScheme(primary = Color(0xFF5AC8FA), secondary = Color(0xFF007AFF))
            ThemeBackgroundStyle.TOKYO_CITY_DAY -> lightColorScheme(primary = TokyoDayAccent)
            ThemeBackgroundStyle.TOKYO_CITY_NIGHT -> darkColorScheme(primary = TokyoNightAccent)
            ThemeBackgroundStyle.GIRLY_VIBES_DAY -> lightColorScheme(primary = GirlyDayAccent)
            ThemeBackgroundStyle.GIRLY_VIBES_NIGHT -> darkColorScheme(primary = GirlyNightAccent)
            ThemeBackgroundStyle.CHUCK_NETWORK_DAY -> lightColorScheme(primary = ChuckDayAccent)
            ThemeBackgroundStyle.CHUCK_NETWORK_NIGHT -> darkColorScheme(primary = ChuckNightAccent)
            else -> if (appTheme.isDark) DarkColorScheme else LightColorScheme
        }
    }

    val typography = if (largerText) {
        Typography(
            headlineLarge = TextStyle(fontSize = 38.sp),
            headlineMedium = TextStyle(fontSize = 32.sp),
            titleLarge = TextStyle(fontSize = 26.sp),
            titleMedium = TextStyle(fontSize = 22.sp),
            bodyLarge = TextStyle(fontSize = 20.sp),
            bodyMedium = TextStyle(fontSize = 18.sp),
            labelLarge = TextStyle(fontSize = 18.sp),
            labelSmall = TextStyle(fontSize = 14.sp)
        )
    } else {
        Typography() // Default
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = baseColorScheme.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !appTheme.isDark
        }
    }

    MaterialTheme(
        colorScheme = baseColorScheme,
        typography = typography,
        content = content
    )
}
