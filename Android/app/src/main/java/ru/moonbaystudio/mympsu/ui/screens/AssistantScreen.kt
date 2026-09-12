package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Face
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.data.model.AssistantMessage
import ru.moonbaystudio.mympsu.data.model.AssistantPersona
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.viewmodel.AssistantViewModel
import ru.moonbaystudio.mympsu.ui.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AssistantScreen(
    viewModel: AssistantViewModel = hiltViewModel()
) {
    val messages by viewModel.messages.collectAsState()
    val inputText by viewModel.inputText.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val selectedPersona by viewModel.selectedPersona.collectAsState()
    val runtimeState by viewModel.runtimeConfigState.collectAsState()
    val remainingRequests by viewModel.remainingRequests.collectAsState()
    val aiEnabled = runtimeState.config.aiEnabled

    // Sync persona with default from preferences if first time
    val settingsViewModel: SettingsViewModel = hiltViewModel()
    val defaultPersonaPref by settingsViewModel.defaultPersona.collectAsState()
    
    LaunchedEffect(defaultPersonaPref) {
        if (messages.isEmpty()) {
            viewModel.setPersona(if (defaultPersonaPref == "pelikasha") AssistantPersona.PELIKASHA else AssistantPersona.STESHA)
        }
    }

    var showPersonaSelection by remember { mutableStateOf(false) }

    val listState = rememberLazyListState()

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    if (showPersonaSelection) {
        PersonaSelectionDialog(
            selectedPersona = selectedPersona,
            onPersonaSelected = { 
                viewModel.setPersona(it)
                showPersonaSelection = false
            },
            onDismiss = { showPersonaSelection = false }
        )
    }

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Помощник МПГУ",
                subtitle = selectedPersona.displayName,
                actions = {
                    IconButton(onClick = { viewModel.clearHistory() }) {
                        Icon(imageVector = Icons.Default.Delete, contentDescription = "Очистить чат")
                    }
                    ActionCapsule(icon = Icons.Default.Face, onClick = { showPersonaSelection = true })
                }
            )
        },
        bottomBar = {
            Box(modifier = Modifier.padding(bottom = 88.dp)) { // Avoid overlap with island
                Surface(
                    modifier = Modifier
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                        .clip(RoundedCornerShape(24.dp)),
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.9f),
                    tonalElevation = 2.dp
                ) {
                    Column(
                        modifier = Modifier
                            .padding(horizontal = 16.dp, vertical = 4.dp)
                            .fillMaxWidth()
                            .navigationBarsPadding()
                            .imePadding(),
                    ) {
                        val limitText = when {
                            !aiEnabled -> "AI временно отключен администратором"
                            remainingRequests != null && runtimeState.config.aiDailyLimit != null ->
                                "Осталось ${remainingRequests} из ${runtimeState.config.aiDailyLimit} запросов"
                            remainingRequests != null -> "Осталось запросов: ${remainingRequests}"
                            runtimeState.config.aiDailyLimit != null -> "Лимит на день: ${runtimeState.config.aiDailyLimit}"
                            else -> null
                        }
                        if (limitText != null) {
                            Text(
                                text = limitText,
                                style = MaterialTheme.typography.labelMedium,
                                color = if (aiEnabled) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.error,
                                modifier = Modifier.padding(start = 4.dp, top = 4.dp, bottom = 2.dp)
                            )
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            TextField(
                                value = inputText,
                                onValueChange = { viewModel.setInputText(it) },
                                modifier = Modifier.weight(1f),
                                placeholder = { Text(if (aiEnabled) "Спросить помощника МПГУ..." else "AI отключен") },
                                colors = TextFieldDefaults.colors(
                                    focusedContainerColor = Color.Transparent,
                                    unfocusedContainerColor = Color.Transparent,
                                    disabledContainerColor = Color.Transparent,
                                    focusedIndicatorColor = Color.Transparent,
                                    unfocusedIndicatorColor = Color.Transparent,
                                ),
                                maxLines = 4,
                                enabled = !isLoading && aiEnabled
                            )
                            IconButton(
                                onClick = {
                                    if (isLoading) viewModel.cancelCurrentRequest() else viewModel.sendMessage()
                                },
                                enabled = (inputText.isNotBlank() && aiEnabled) || isLoading
                            ) {
                                if (isLoading) {
                                    Icon(imageVector = Icons.Default.Close, contentDescription = "Отменить", tint = MaterialTheme.colorScheme.primary)
                                } else {
                                    Icon(imageVector = Icons.AutoMirrored.Filled.Send, contentDescription = "Send", tint = MaterialTheme.colorScheme.primary)
                                }
                            }
                        }
                    }
                }
            }
        }
    ) { padding ->
        LazyColumn(
            state = listState,
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 220.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (messages.isEmpty()) {
                item {
                    EmptyAssistantState(selectedPersona)
                }
            }
            items(items = messages) { message ->
                MessageBubble(message)
            }
        }
    }
}

@Composable
fun EmptyAssistantState(persona: AssistantPersona) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
        shape = MaterialTheme.shapes.large
    ) {
        Column(modifier = Modifier.padding(24.dp)) {
            Text(
                text = "Привет! Я ${persona.displayName}",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = "Я твой помощник MyMPSU. Спроси меня о расписании, кабинетах или просто поболтай!",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
fun MessageBubble(message: AssistantMessage) {
    val alignment = if (message.role == AssistantMessage.Role.USER) Alignment.CenterEnd else Alignment.CenterStart
    val containerColor = when (message.role) {
        AssistantMessage.Role.USER -> MaterialTheme.colorScheme.primaryContainer
        AssistantMessage.Role.ASSISTANT -> MaterialTheme.colorScheme.secondaryContainer
        AssistantMessage.Role.SYSTEM_LOCAL -> MaterialTheme.colorScheme.errorContainer
    }

    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = alignment) {
        Surface(
            color = containerColor,
            shape = MaterialTheme.shapes.medium,
            modifier = Modifier.widthIn(max = 300.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                if (message.role == AssistantMessage.Role.ASSISTANT) {
                    Text(
                        text = message.persona?.displayName ?: "Помощник МПГУ",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                Text(text = message.text, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

@Composable
fun PersonaSelectionDialog(
    selectedPersona: AssistantPersona,
    onPersonaSelected: (AssistantPersona) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Выберите персонажа") },
        text = {
            Column {
                AssistantPersona.values().forEach { persona ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onPersonaSelected(persona) }
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(selected = persona == selectedPersona, onClick = { onPersonaSelected(persona) })
                        Spacer(Modifier.width(8.dp))
                        Text(persona.displayName)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("Закрыть") }
        }
    )
}
