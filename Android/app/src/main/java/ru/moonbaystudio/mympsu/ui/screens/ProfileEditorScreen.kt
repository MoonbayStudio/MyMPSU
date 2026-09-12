package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.components.UserBadgeRow
import ru.moonbaystudio.mympsu.ui.viewmodel.AuthViewModel
import ru.moonbaystudio.mympsu.ui.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ProfileEditorScreen(
    onBack: () -> Unit,
    onNavigate: (String) -> Unit = {},
    viewModel: AuthViewModel = hiltViewModel()
) {
    val currentUser by viewModel.currentUser.collectAsState()
    val roleRequests by viewModel.roleRequests.collectAsState()
    val groupChangeRequests by viewModel.groupChangeRequests.collectAsState()

    val settingsViewModel: SettingsViewModel = hiltViewModel()
    val selectedGroupName by settingsViewModel.selectedGroupName.collectAsState()

    var displayName by remember { mutableStateOf(currentUser?.name ?: "") }
    val isLoading by viewModel.isLoading.collectAsState()

    val hasRequests = roleRequests.isNotEmpty() || groupChangeRequests.isNotEmpty()

    LaunchedEffect(currentUser) {
        if (displayName.isEmpty()) {
            displayName = currentUser?.name ?: ""
        }
    }

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Профиль",
                navigationIcon = {
                    Surface(
                        onClick = onBack,
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier.size(40.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            viewModel.updateProfile(displayName)
                            onBack()
                        },
                        enabled = !isLoading && displayName.isNotBlank() && displayName != currentUser?.name
                    ) {
                        Text("Готово", fontWeight = FontWeight.Bold)
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Имя
            OutlinedTextField(
                value = displayName,
                onValueChange = { displayName = it },
                label = { Text("Имя") },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                singleLine = true
            )

            // Значки
            if (currentUser?.badges?.isNotEmpty() == true) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Значки", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.height(8.dp))
                        UserBadgeRow(badges = currentUser!!.badges, maxBadges = 10)
                    }
                }
            }

            // Роли
            Card(
                modifier = Modifier.fillMaxWidth(),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Роли", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.height(8.dp))
                    if (currentUser?.roles?.isNotEmpty() == true) {
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            currentUser?.roles?.forEach { role ->
                                SuggestionChip(
                                    onClick = {},
                                    label = { Text(role.title) }
                                )
                            }
                        }
                    } else {
                        Text("У вас пока нет специальных ролей", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }

            // Кнопки запроса ролей и заявок
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                val canRequestTester = currentUser?.isAdmin != true && currentUser?.isTester != true
                val testerRequestPending = roleRequests.any { it.roleType == "tester" && it.status == "pending" }

                Button(
                    onClick = { viewModel.requestTesterRole() },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    enabled = !isLoading && canRequestTester && !testerRequestPending
                ) {
                    Text(if (testerRequestPending) "Заявка отправлена" else "Запросить роль", maxLines = 1)
                }

                OutlinedButton(
                    onClick = { /* Можно открыть диалог со списком заявок */ },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    enabled = hasRequests
                ) {
                    Text("Мои заявки", maxLines = 1)
                }
            }

            if (hasRequests) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        roleRequests.forEach { request ->
                            UserRoleRequestRow(request, isLoading, onCancel = { viewModel.cancelRoleRequest(request.id) })
                        }
                        groupChangeRequests.forEach { request ->
                            GroupChangeRequestRow(request, isLoading, onCancel = { viewModel.cancelGroupChangeRequest(request.id) })
                        }
                    }
                }
            }

            // Группа по умолчанию
            Text("Группа по умолчанию", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 8.dp))
            ListItem(
                headlineContent = { Text(selectedGroupName ?: "Не выбрана") },
                leadingContent = { Icon(Icons.Default.Group, contentDescription = null) },
                trailingContent = {
                    IconButton(onClick = { onNavigate("default_group_selection") }) {
                        Icon(Icons.Default.Edit, contentDescription = "Edit Group")
                    }
                },
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .clickable { onNavigate("default_group_selection") }
            )

            Spacer(modifier = Modifier.height(112.dp))
        }
    }
}
