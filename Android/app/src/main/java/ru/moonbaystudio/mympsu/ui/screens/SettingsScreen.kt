package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val defaultPersona by viewModel.defaultPersona.collectAsState()
    val scheduleCacheWeeks by viewModel.scheduleCacheWeeks.collectAsState()
    val offlineScheduleEnabled by viewModel.offlineScheduleEnabled.collectAsState()
    val liveActivityEnabled by viewModel.liveActivityEnabled.collectAsState()

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Настройки",
                navigationIcon = {
                    ActionCapsule(icon = Icons.Default.ArrowBack, onClick = onBack)
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
                Text("Внешний вид", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(vertical = 8.dp))
                ListItem(
                    headlineContent = { Text("Темы оформления") },
                    trailingContent = { Icon(Icons.Default.KeyboardArrowRight, contentDescription = null) },
                    modifier = Modifier.clickable { onNavigate("themes") }
                )
                ListItem(
                    headlineContent = { Text("Специальные возможности") },
                    trailingContent = { Icon(Icons.Default.KeyboardArrowRight, contentDescription = null) },
                    modifier = Modifier.clickable { onNavigate("accessibility") }
                )
            }
            item {
                Text("Ассистент", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(vertical = 8.dp))
                ListItem(
                    headlineContent = { Text("Персонаж по умолчанию") },
                    supportingContent = { Text(if (defaultPersona == "pelikasha") "Помощник МПГУ" else "Стеша") },
                    trailingContent = {
                        Switch(
                            checked = defaultPersona == "stesha",
                            onCheckedChange = { viewModel.updateDefaultPersona(if (it) "stesha" else "pelikasha") }
                        )
                    }
                )
            }
            item {
                Text("Уведомления", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(vertical = 8.dp))
                ListItem(
                    headlineContent = { Text("Активные уведомления") },
                    supportingContent = { Text("Показывать текущую пару в шторке") },
                    trailingContent = {
                        Switch(
                            checked = liveActivityEnabled,
                            onCheckedChange = { viewModel.updateLiveActivityEnabled(it) }
                        )
                    }
                )
            }
            item {
                Text("Данные", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(vertical = 8.dp))
                ListItem(
                    headlineContent = { Text("Офлайн-кэш расписания") },
                    supportingContent = { Text("Сохранять пары локально для работы без сети") },
                    trailingContent = {
                        Switch(
                            checked = offlineScheduleEnabled,
                            onCheckedChange = { viewModel.updateOfflineScheduleEnabled(it) }
                        )
                    }
                )
                ListItem(
                    headlineContent = { Text(if (scheduleCacheWeeks == 0) "Кэш выключен" else "Кэш на недель: $scheduleCacheWeeks") },
                    supportingContent = {
                        Slider(
                            value = scheduleCacheWeeks.toFloat(),
                            onValueChange = { viewModel.updateScheduleCacheWeeks(it.toInt()) },
                            valueRange = 0f..4f,
                            steps = 3,
                            enabled = offlineScheduleEnabled
                        )
                    }
                )
                ListItem(
                    headlineContent = { Text("Очистить кэш") },
                    supportingContent = { Text("Удалить сохраненное расписание") },
                    modifier = Modifier.clickable { viewModel.clearCache() }
                )
            }
        }
    }
}
