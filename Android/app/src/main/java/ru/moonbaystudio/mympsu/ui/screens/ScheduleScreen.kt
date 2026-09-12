package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.data.remote.dto.Homework
import ru.moonbaystudio.mympsu.data.model.ScheduleItem
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.viewmodel.ScheduleViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduleScreen(
    groupId: Int,
    viewModel: ScheduleViewModel = hiltViewModel()
) {
    val items by viewModel.scheduleItems.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val selectedDate by viewModel.selectedDate.collectAsState()
    val homeworks by viewModel.homeworks.collectAsState()
    val currentUser by viewModel.currentUser.collectAsState()
    val refreshStatus by viewModel.refreshStatus.collectAsState()
    val showLastDayWarning by viewModel.showLastDayWarning.collectAsState()
    val isOffline by viewModel.isOffline.collectAsState()
    val defaultGroupId by viewModel.defaultGroupId.collectAsState(initial = -1)
    val isViewingDefaultGroupSchedule = defaultGroupId == groupId
    val canShowHomework = currentUser != null && isViewingDefaultGroupSchedule

    var showDatePicker by remember { mutableStateOf(false) }
    var selectedLessonForHomework by remember { mutableStateOf<ScheduleItem?>(null) }

    LaunchedEffect(canShowHomework) {
        if (!canShowHomework) {
            selectedLessonForHomework = null
        }
    }

    LaunchedEffect(groupId) {
        viewModel.loadSchedule(groupId, false)
    }

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Расписание",
                subtitle = SimpleDateFormat("d MMMM, EEEE", Locale("ru")).format(selectedDate),
                actions = {
                    if (isOffline) {
                        ActionCapsule(icon = Icons.Default.CloudOff, onClick = { viewModel.manualRefresh() })
                    }
                    ActionCapsule(icon = Icons.Default.DateRange, onClick = { showDatePicker = true })
                }
            )
        }
    ) { padding ->
        if (showLastDayWarning) {
            AlertDialog(
                onDismissRequest = { viewModel.dismissWarning() },
                title = { Text("Внимание") },
                text = { Text("Это последний день в кэше. Пожалуйста, включите интернет или выключите VPN, чтобы загрузить следующие недели.") },
                confirmButton = {
                    TextButton(onClick = { viewModel.dismissWarning() }) {
                        Text("ОК")
                    }
                }
            )
        }

        if (showDatePicker) {
            val datePickerState = rememberDatePickerState(initialSelectedDateMillis = selectedDate.time)
            DatePickerDialog(
                onDismissRequest = { showDatePicker = false },
                confirmButton = {
                    TextButton(onClick = {
                        datePickerState.selectedDateMillis?.let {
                            viewModel.setDate(Date(it))
                        }
                        showDatePicker = false
                    }) {
                        Text("OK")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showDatePicker = false }) {
                        Text("Отмена")
                    }
                }
            ) {
                DatePicker(state = datePickerState)
            }
        }

        selectedLessonForHomework?.let { lesson ->
            val dateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(selectedDate)
            val homework = homeworks["$dateStr|${lesson.time}|${lesson.title}"]
            val canEdit = canShowHomework &&
                (currentUser?.isAdmin == true || currentUser?.isModerator == true || currentUser?.isGroupLeader == true)

            if (canShowHomework) {
                HomeworkDialog(
                    lesson = lesson,
                    homework = homework,
                    canEdit = canEdit,
                    onDismiss = { selectedLessonForHomework = null },
                    onSave = { text ->
                        viewModel.saveHomework(lesson, text)
                        selectedLessonForHomework = null
                    },
                    onDelete = {
                        homework?.let { viewModel.deleteHomework(it.id) }
                        selectedLessonForHomework = null
                    }
                )
            }
        }

        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            val pullToRefreshState = rememberPullToRefreshState()
            
            PullToRefreshBox(
                isRefreshing = isLoading && items.isNotEmpty(),
                onRefresh = { viewModel.manualRefresh() },
                state = pullToRefreshState,
                modifier = Modifier.fillMaxSize()
            ) {
                if (isLoading && items.isEmpty()) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                } else if (items.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Default.Info,
                                contentDescription = null,
                                modifier = Modifier.size(64.dp),
                                tint = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f)
                            )
                            Spacer(Modifier.height(16.dp))
                            Text(
                                text = "Сегодня нет пар",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "Можно отдохнуть!",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                            )
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 104.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(items) { item ->
                            val dateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(selectedDate)
                            val homework = homeworks["$dateStr|${item.time}|${item.title}"]
                            val canEdit = canShowHomework &&
                                (currentUser?.isAdmin == true || currentUser?.isModerator == true || currentUser?.isGroupLeader == true)

                            ScheduleItemCard(
                                item = item,
                                homework = if (canShowHomework) homework else null,
                                canEdit = canEdit,
                                onHomeworkClick = { selectedLessonForHomework = item }
                            )
                        }
                    }
                }
            }

            refreshStatus?.let { status ->
                Surface(
                    modifier = Modifier
                        .align(Alignment.Center)
                        .padding(16.dp),
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    tonalElevation = 8.dp
                ) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        val icon = if (status is ScheduleViewModel.RefreshStatus.Success) Icons.Default.Check else Icons.Default.Close
                        val color = if (status is ScheduleViewModel.RefreshStatus.Success) Color.Green else Color.Red
                        val text = if (status is ScheduleViewModel.RefreshStatus.Success) "Обновлено" else (status as ScheduleViewModel.RefreshStatus.Error).message

                        Icon(
                            imageVector = icon,
                            contentDescription = null,
                            tint = color,
                            modifier = Modifier.size(48.dp)
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(text = text, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                    }
                }
            }
        }
    }
}

@Composable
fun ScheduleItemCard(
    item: ScheduleItem,
    homework: Homework? = null,
    canEdit: Boolean = false,
    onHomeworkClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(text = item.time, style = MaterialTheme.typography.labelMedium)
                Spacer(Modifier.weight(1f))
                if (item.subgroup != null) {
                    Text(text = "П/г ${item.subgroup}", style = MaterialTheme.typography.labelSmall)
                }
            }
            Text(text = item.title, style = MaterialTheme.typography.titleMedium)
            Text(text = item.teacher, style = MaterialTheme.typography.bodyMedium)
            Text(text = "${item.lessonType} • ${item.room}", style = MaterialTheme.typography.bodySmall)
            if (item.address.isNotEmpty()) {
                Text(text = item.address, style = MaterialTheme.typography.bodySmall)
            }
            
            Spacer(Modifier.height(8.dp))

            if (homework != null) {
                Surface(
                    color = MaterialTheme.colorScheme.secondaryContainer,
                    shape = MaterialTheme.shapes.small,
                    modifier = Modifier.clickable { onHomeworkClick() }
                ) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(text = "Домашка:", style = MaterialTheme.typography.labelSmall)
                            Spacer(Modifier.weight(1f))
                            if (canEdit) {
                                Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(12.dp))
                            }
                        }
                        Text(text = homework.text, style = MaterialTheme.typography.bodySmall)
                    }
                }
            } else if (canEdit) {
                TextButton(
                    onClick = onHomeworkClick,
                    modifier = Modifier.align(Alignment.End),
                    contentPadding = PaddingValues(0.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Добавить домашку", style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

@Composable
fun HomeworkDialog(
    lesson: ScheduleItem,
    homework: Homework?,
    canEdit: Boolean,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
    onDelete: () -> Unit
) {
    var text by remember { mutableStateOf(homework?.text ?: "") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (canEdit) (if (homework == null) "Добавить домашку" else "Изменить домашку") else "Домашка") },
        text = {
            Column {
                Text(text = lesson.title, style = MaterialTheme.typography.titleSmall)
                Text(text = "${lesson.time} • ${lesson.teacher}", style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(16.dp))
                if (canEdit) {
                    OutlinedTextField(
                        value = text,
                        onValueChange = { text = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Задание") }
                    )
                } else {
                    Text(text = if (text.isEmpty()) "Домашки нет." else text)
                }
            }
        },
        confirmButton = {
            if (canEdit) {
                TextButton(onClick = { onSave(text) }, enabled = text.isNotBlank()) {
                    Text("Сохранить")
                }
            } else {
                TextButton(onClick = onDismiss) {
                    Text("Закрыть")
                }
            }
        },
        dismissButton = {
            Row {
                if (canEdit && homework != null) {
                    TextButton(onClick = onDelete, colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)) {
                        Text("Удалить")
                    }
                }
                TextButton(onClick = onDismiss) {
                    Text(if (canEdit) "Отмена" else "")
                }
            }
        }
    )
}
