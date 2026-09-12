package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.data.remote.dto.AccountSession
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.viewmodel.AuthViewModel
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountSessionsScreen(
    onBack: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel()
) {
    val sessions by viewModel.sessions.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    var showLogoutOthersConfirmation by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.loadSessions()
    }

    if (showLogoutOthersConfirmation) {
        AlertDialog(
            onDismissRequest = { showLogoutOthersConfirmation = false },
            title = { Text("Выйти на других устройствах?") },
            text = { Text("Текущий сеанс останется активным, остальные устройства будут отключены.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.logoutOthers()
                        showLogoutOthersConfirmation = false
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Выйти")
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutOthersConfirmation = false }) {
                    Text("Отмена")
                }
            }
        )
    }

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Сеансы",
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
                },
                actions = {
                    if (sessions.size > 1) {
                        ActionCapsule(
                            icon = Icons.Default.ExitToApp,
                            onClick = { showLogoutOthersConfirmation = true }
                        )
                    }
                    ActionCapsule(
                        icon = Icons.Default.Refresh,
                        onClick = { viewModel.loadSessions() }
                    )
                }
            )
        }
    ) { padding ->
        if (isLoading && sessions.isEmpty()) {
            Box(modifier = Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .padding(padding)
                    .fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item {
                    Text(
                        text = "Активные устройства",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                }

                items(sessions) { session ->
                    SessionItem(session = session, onRevoke = { viewModel.revokeSession(session.id) })
                }

                item { Spacer(Modifier.height(100.dp)) }
            }
        }
    }
}

@Composable
fun SessionItem(session: AccountSession, onRevoke: () -> Unit) {
    val platform = session.platform?.lowercase() ?: ""
    val isDesktop = platform.contains("mac") || platform.contains("windows") || platform.contains("web")

    val icon = if (isDesktop) Icons.Default.Computer else Icons.Default.PhoneAndroid

    ListItem(
        headlineContent = {
            Column {
                Text(
                    text = when(platform) {
                        "ios" -> "iOS"
                        "android" -> "Android"
                        "macos" -> "macOS"
                        "web" -> "Web"
                        else -> platform.uppercase()
                    },
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = session.deviceName ?: "Неизвестное устройство",
                        fontWeight = FontWeight.SemiBold
                    )
                    if (session.isCurrent) {
                        Spacer(Modifier.width(8.dp))
                        Surface(
                            color = MaterialTheme.colorScheme.primaryContainer,
                            shape = RoundedCornerShape(4.dp)
                        ) {
                            Text(
                                text = "ТЕКУЩЕЕ",
                                style = MaterialTheme.typography.labelSmall,
                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        }
                    }
                }
            }
        },
        supportingContent = {
            Column {
                val lastSeen = session.lastSeenAt ?: session.createdAt
                Text(text = "Последний раз: ${formatSessionDate(lastSeen)}")
                session.safeIpText?.let {
                    Text(
                        text = "IP: $it",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        },
leadingContent = {
            Surface(
                color = MaterialTheme.colorScheme.secondaryContainer,
                shape = CircleShape,
                modifier = Modifier.size(40.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSecondaryContainer,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        },
        trailingContent = {
            if (!session.isCurrent) {
                IconButton(onClick = onRevoke) {
                    Icon(Icons.Default.Delete, contentDescription = "Revoke", tint = MaterialTheme.colorScheme.error)
                }
            }
        }
    )
}

fun formatSessionDate(dateString: String?): String {
    if (dateString.isNullOrBlank()) return "недавно"

    val formats = listOf(
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd HH:mm:ss"
    )

    val outputFormat = SimpleDateFormat("d MMMM yyyy HH:mm", Locale("ru"))

    for (format in formats) {
        try {
            val sdf = SimpleDateFormat(format, Locale.US)
            if (format.endsWith("'Z'")) {
                sdf.timeZone = TimeZone.getTimeZone("UTC")
            }
            val date = sdf.parse(dateString)
            if (date != null) {
                return outputFormat.format(date)
            }
        } catch (e: Exception) {
            // Try next format
        }
    }

    return dateString.replace("T", " ").substringBefore(".")
}
