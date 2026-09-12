package ru.moonbaystudio.mympsu.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import ru.moonbaystudio.mympsu.ui.theme.AppTheme
import ru.moonbaystudio.mympsu.ui.theme.ThemeBackgroundStyle

@Composable
fun ThemedBackground(
    theme: AppTheme,
    content: @Composable () -> Unit
) {
    val modifier = when (theme.backgroundStyle) {
        ThemeBackgroundStyle.SYSTEM -> Modifier.background(MaterialTheme.colorScheme.background)
        ThemeBackgroundStyle.DREAMY_SKY_DAY -> Modifier.background(Brush.verticalGradient(listOf(Color(0xFF87CEEB), Color(0xFFE0F6FF))))
        ThemeBackgroundStyle.DREAMY_SKY_NIGHT -> Modifier.background(Brush.verticalGradient(listOf(Color(0xFF191970), Color(0xFF000080))))
        ThemeBackgroundStyle.TOKYO_CITY_DAY -> Modifier.background(Color(0xFFF0F8FF))
        ThemeBackgroundStyle.TOKYO_CITY_NIGHT -> Modifier.background(Color(0xFF0D1117))
        ThemeBackgroundStyle.GIRLY_VIBES_DAY -> Modifier.background(Brush.verticalGradient(listOf(Color(0xFFFFC0CB), Color(0xFFFFE4E1))))
        ThemeBackgroundStyle.GIRLY_VIBES_NIGHT -> Modifier.background(Brush.verticalGradient(listOf(Color(0xFF800080), Color(0xFF4B0082))))
        ThemeBackgroundStyle.CHUCK_NETWORK_DAY -> Modifier.background(Color(0xFF1A1A1A))
        ThemeBackgroundStyle.CHUCK_NETWORK_NIGHT -> Modifier.background(Color.Black)
    }

    Box(modifier = modifier.fillMaxSize()) {
        content()
    }
}
