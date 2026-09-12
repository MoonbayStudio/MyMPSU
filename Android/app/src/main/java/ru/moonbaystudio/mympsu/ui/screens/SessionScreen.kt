package ru.moonbaystudio.mympsu.ui.screens

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
import ru.moonbaystudio.mympsu.data.model.ScheduleItem
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.viewmodel.ScheduleViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionScreen(
    groupId: Int,
    viewModel: ScheduleViewModel = hiltViewModel()
) {
    val items by viewModel.scheduleItems.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val refreshStatus by viewModel.refreshStatus.collectAsState()
    val isOffline by viewModel.isOffline.collectAsState()

    LaunchedEffect(groupId) {
        viewModel.loadSchedule(groupId, true)
    }

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Сессия",
                actions = {
                    if (isOffline) {
                        ActionCapsule(icon = Icons.Default.CloudOff, onClick = { viewModel.manualRefresh() })
                    }
                }
            )
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            val pullToRefreshState = rememberPullToRefreshState()
            
            PullToRefreshBox(
                isRefreshing = isLoading && items.isNotEmpty(),
                onRefresh = { viewModel.manualRefresh() },
                state = pullToRefreshState,
                modifier = Modifier.fillMaxSize()
            ) {
                val today = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }.time
                
                val filteredItems = items.filter { item ->
                    val itemDate = try {
                        SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(item.period)
                    } catch (e: Exception) {
                        null
                    }
                    itemDate == null || !itemDate.before(today)
                }.sortedBy { it.sortDateIso ?: it.period }

                if (isLoading && filteredItems.isEmpty()) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                } else if (filteredItems.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Default.DateRange,
                                contentDescription = null,
                                modifier = Modifier.size(64.dp),
                                tint = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f)
                            )
                            Spacer(Modifier.height(16.dp))
                            Text(
                                text = "Расписание сессии не найдено",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "Похоже, экзаменов пока нет",
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
                        items(filteredItems) { item ->
                            SessionItemCard(item = item)
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
fun SessionItemCard(item: ScheduleItem) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(text = item.time, style = MaterialTheme.typography.labelMedium)
                Spacer(Modifier.weight(1f))
                if (item.period.isNotEmpty()) {
                    val displayDate = try {
                        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(item.period)
                        SimpleDateFormat("d MMMM", Locale("ru")).format(date)
                    } catch (e: Exception) {
                        item.period
                    }
                    Text(text = displayDate, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                }
            }
            Text(text = item.title, style = MaterialTheme.typography.titleMedium)
            Text(text = item.teacher, style = MaterialTheme.typography.bodyMedium)
            Text(text = "${item.lessonType} • ${item.room}", style = MaterialTheme.typography.bodySmall)
            if (item.address.isNotEmpty()) {
                Text(text = item.address, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
