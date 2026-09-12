package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccessibilitySettingsScreen(
    onBack: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val reduceMotion by viewModel.reduceMotion.collectAsState()
    val highContrast by viewModel.highContrast.collectAsState()
    val largerText by viewModel.largerText.collectAsState()
    val autoSpeakSchedule by viewModel.autoSpeakSchedule.collectAsState()
    val speechDetailed by viewModel.speechDetailed.collectAsState()
    val hapticsEnabled by viewModel.hapticsEnabled.collectAsState()

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Спец. возможности",
                navigationIcon = {
                    Surface(
                        onClick = onBack,
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier.size(40.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                        }
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 104.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            item {
                AccessibilitySwitchItem(
                    title = "Уменьшить движение",
                    subtitle = "Сократить анимации интерфейса",
                    checked = reduceMotion,
                    onCheckedChange = viewModel::updateReduceMotion
                )
                AccessibilitySwitchItem(
                    title = "Увеличенный шрифт",
                    subtitle = "Сделать текст приложения крупнее",
                    checked = largerText,
                    onCheckedChange = viewModel::updateLargerText
                )
                AccessibilitySwitchItem(
                    title = "Высокий контраст",
                    subtitle = "Улучшить видимость элементов интерфейса",
                    checked = highContrast,
                    onCheckedChange = viewModel::updateHighContrast
                )
                AccessibilitySwitchItem(
                    title = "Тактильный отклик",
                    subtitle = "Оставить вибрацию для ключевых действий",
                    checked = hapticsEnabled,
                    onCheckedChange = viewModel::updateHapticsEnabled
                )
                AccessibilitySwitchItem(
                    title = "Автоозвучка расписания",
                    subtitle = "Озвучивать расписание после смены даты или группы",
                    checked = autoSpeakSchedule,
                    onCheckedChange = viewModel::updateAutoSpeakSchedule
                )
                AccessibilitySwitchItem(
                    title = "Подробная озвучка",
                    subtitle = "Добавлять преподавателя, аудиторию и тип пары",
                    checked = speechDetailed,
                    onCheckedChange = viewModel::updateSpeechDetailed
                )
            }
        }
    }
}

@Composable
private fun AccessibilitySwitchItem(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    ListItem(
        headlineContent = { Text(title) },
        supportingContent = { Text(subtitle) },
        trailingContent = {
            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange
            )
        }
    )
}
