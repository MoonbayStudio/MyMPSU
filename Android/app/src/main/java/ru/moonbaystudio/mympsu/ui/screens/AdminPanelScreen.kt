package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
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
import ru.moonbaystudio.mympsu.data.remote.dto.AdminRoleRequestDto
import ru.moonbaystudio.mympsu.data.remote.dto.AdminRuntimeSetting
import ru.moonbaystudio.mympsu.data.remote.dto.AdminUserDto
import ru.moonbaystudio.mympsu.data.remote.dto.BadgeDto
import ru.moonbaystudio.mympsu.data.remote.dto.GroupChangeRequestDto
import ru.moonbaystudio.mympsu.data.remote.dto.SystemNotice
import ru.moonbaystudio.mympsu.data.remote.dto.SystemNoticeMutationRequest
import ru.moonbaystudio.mympsu.ui.viewmodel.AdminViewModel

enum class AdminTab { USERS, REQUESTS, SETTINGS, NOTICES }

@Composable
fun AdminPanelScreen(
    onBack: () -> Unit,
    viewModel: AdminViewModel = hiltViewModel()
) {
    val users by viewModel.users.collectAsState()
    val requests by viewModel.requests.collectAsState()
    val groupChangeRequests by viewModel.groupChangeRequests.collectAsState()
    val settings by viewModel.settings.collectAsState()
    val notices by viewModel.notices.collectAsState()
    val badges by viewModel.badges.collectAsState()
    val userSessions by viewModel.userSessions.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.errorMessage.collectAsState()

    var selectedTab by remember { mutableStateOf(AdminTab.USERS) }
    var searchText by remember { mutableStateOf("") }
    var userToEdit by remember { mutableStateOf<AdminUserDto?>(null) }
    var showCreateNoticeDialog by remember { mutableStateOf(false) }
    var roleRequestToReject by remember { mutableStateOf<AdminRoleRequestDto?>(null) }
    var groupChangeRequestToReject by remember { mutableStateOf<GroupChangeRequestDto?>(null) }

    LaunchedEffect(Unit) {
        viewModel.loadAllData()
    }

    if (showCreateNoticeDialog) {
        CreateNoticeDialog(
            onDismiss = { showCreateNoticeDialog = false },
            onConfirm = { request ->
                viewModel.createNotice(request)
                showCreateNoticeDialog = false
            }
        )
    }

    if (userToEdit != null) {
        UserEditorDialog(
            user = userToEdit!!,
            availableBadges = badges,
            sessions = userSessions,
            onDismiss = { userToEdit = null },
            onRoleToggle = { role, enabled -> viewModel.setRole(userToEdit!!.id, role, enabled) },
            onBadgeToggle = { code, enabled, note -> viewModel.setBadge(userToEdit!!.id, code, enabled, note) },
            onLoadSessions = { viewModel.loadUserSessions(userToEdit!!.id) },
            onRevokeSession = { viewModel.revokeUserSession(userToEdit!!.id, it) }
        )
    }

    roleRequestToReject?.let { request ->
        RejectRequestDialog(
            title = "Отклонить заявку",
            subject = request.userEmail ?: "ID: ${request.userId}",
            onDismiss = { roleRequestToReject = null },
            onConfirm = { comment ->
                viewModel.rejectRequest(request.id, comment)
                roleRequestToReject = null
            }
        )
    }

    groupChangeRequestToReject?.let { request ->
        val requestedGroup = request.requestedGroupName ?: request.requestedGroupId.toString()
        RejectRequestDialog(
            title = "Отклонить смену группы",
            subject = requestedGroup,
            onDismiss = { groupChangeRequestToReject = null },
            onConfirm = { comment ->
                viewModel.rejectGroupChangeRequest(request.id, comment)
                groupChangeRequestToReject = null
            }
        )
    }

    Scaffold(
        topBar = {
            ru.moonbaystudio.mympsu.ui.components.CapsuleHeader(
                title = "Админка",
                navigationIcon = {
                    Surface(
                        onClick = onBack,
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier.size(40.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(imageVector = Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.loadAllData() }, enabled = !isLoading) {
                        Icon(imageVector = Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            ScrollableTabRow(
                selectedTabIndex = selectedTab.ordinal,
                edgePadding = 16.dp,
                containerColor = Color.Transparent
            ) {
                AdminTab.entries.forEach { tab ->
                    val title = when(tab) {
                        AdminTab.USERS -> "Юзеры"
                        AdminTab.REQUESTS -> "Заявки (${requests.size + groupChangeRequests.size})"
                        AdminTab.SETTINGS -> "Дебаг"
                        AdminTab.NOTICES -> "Уведомления"
                    }
                    Tab(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        text = { Text(title) }
                    )
                }
            }

            if (selectedTab == AdminTab.NOTICES) {
                Button(
                    onClick = { showCreateNoticeDialog = true },
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(imageVector = Icons.Default.Add, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Создать уведомление")
                }
            }

            if (selectedTab == AdminTab.USERS) {
                OutlinedTextField(
                    value = searchText,
                    onValueChange = { searchText = it },
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    placeholder = { Text("Поиск по имени или email") },
                    leadingIcon = { Icon(imageVector = Icons.Default.Search, contentDescription = null) },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp)
                )
            }

            error?.let {
                Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp))
            }

            Box(modifier = Modifier.fillMaxSize()) {
                if (isLoading && users.isEmpty()) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                } else {
                    val filteredUsers = if (searchText.isBlank()) users else {
                        users.filter { it.name?.contains(searchText, true) == true || it.email?.contains(searchText, true) == true }
                    }

                    LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 112.dp)) {
                        when (selectedTab) {
                            AdminTab.USERS -> {
                                items(items = filteredUsers) { user ->
                                    UserListItem(user = user, onClick = { userToEdit = user })
                                }
                            }
                            AdminTab.REQUESTS -> {
                                items(items = groupChangeRequests) { request ->
                                    GroupChangeRequestListItem(
                                        request = request,
                                        onApprove = { viewModel.approveGroupChangeRequest(request.id) },
                                        onReject = { groupChangeRequestToReject = request }
                                    )
                                }
                                items(items = requests) { request ->
                                    RequestListItem(
                                        request = request,
                                        onApprove = { viewModel.approveRequest(request.id) },
                                        onReject = { roleRequestToReject = request }
                                    )
                                }
                                if (requests.isEmpty() && groupChangeRequests.isEmpty()) {
                                    item { EmptyState("Нет активных заявок") }
                                }
                            }
                            AdminTab.SETTINGS -> {
                                items(items = settings) { setting ->
                                    SettingItem(setting = setting, onUpdate = { viewModel.updateSetting(setting.key, it) })
                                }
                            }
                            AdminTab.NOTICES -> {
                                items(items = notices) { notice ->
                                    NoticeItem(
                                        notice = notice,
                                        onToggle = { viewModel.toggleNotice(notice.id, it) },
                                        onDelete = { viewModel.deleteNotice(notice.id) }
                                    )
                                }
                                if (notices.isEmpty()) {
                                    item { EmptyState("Уведомлений нет") }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun EmptyState(text: String) {
    Box(modifier = Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun RejectRequestDialog(
    title: String,
    subject: String,
    onDismiss: () -> Unit,
    onConfirm: (String?) -> Unit
) {
    var comment by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column {
                Text(subject, style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = comment,
                    onValueChange = { comment = it },
                    label = { Text("Комментарий") },
                    placeholder = { Text("Причина отклонения") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2
                )
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirm(comment.trim().ifBlank { null }) },
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.error
                )
            ) {
                Text("Отклонить")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Отмена") }
        }
    )
}

@Composable
fun UserListItem(user: AdminUserDto, onClick: () -> Unit) {
    ListItem(
        headlineContent = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(user.name ?: "Без имени", fontWeight = FontWeight.Bold)
                if (user.badges.isNotEmpty()) {
                    Spacer(Modifier.width(8.dp))
                    ru.moonbaystudio.mympsu.ui.components.UserBadgeRow(badges = user.badges)
                }
            }
        },
        supportingContent = { Text("${user.email ?: "no email"} • ${user.tier.uppercase()}") },
        leadingContent = {
            val icon = if (user.roles.any { it.type == "admin" }) Icons.Default.Star else Icons.Default.Person
            Icon(imageVector = icon, contentDescription = null, tint = if (icon == Icons.Default.Star) Color(0xFFFFD700) else MaterialTheme.colorScheme.primary)
        },
        trailingContent = { Icon(imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null) },
        modifier = Modifier.clickable(onClick = onClick)
    )
}

@Composable
fun GroupChangeRequestListItem(request: GroupChangeRequestDto, onApprove: () -> Unit, onReject: () -> Unit) {
    val currentGroup = request.currentGroupName ?: request.currentGroupId?.toString() ?: "не выбрана"
    val requestedGroup = request.requestedGroupName ?: request.requestedGroupId.toString()
    ListItem(
        headlineContent = { Text(request.userEmail ?: "ID: ${request.userId}") },
        supportingContent = {
            Text("Смена группы: $currentGroup → $requestedGroup\n${request.createdAt}")
        },
        trailingContent = {
            Row {
                IconButton(onClick = onApprove) {
                    Icon(imageVector = Icons.Default.Check, contentDescription = "Approve", tint = Color.Green)
                }
                IconButton(onClick = onReject) {
                    Icon(imageVector = Icons.Default.Close, contentDescription = "Reject", tint = Color.Red)
                }
            }
        }
    )
}

@Composable
fun RequestListItem(request: AdminRoleRequestDto, onApprove: () -> Unit, onReject: () -> Unit) {
    ListItem(
        headlineContent = { Text(request.userEmail ?: "ID: ${request.userId}") },
        supportingContent = { Text("Хочет роль: ${request.roleType}\n${request.createdAt}") },
        trailingContent = {
            Row {
                IconButton(onClick = onApprove) {
                    Icon(imageVector = Icons.Default.Check, contentDescription = "Approve", tint = Color.Green)
                }
                IconButton(onClick = onReject) {
                    Icon(imageVector = Icons.Default.Close, contentDescription = "Reject", tint = Color.Red)
                }
            }
        }
    )
}

@Composable
fun SettingItem(setting: AdminRuntimeSetting, onUpdate: (Any) -> Unit) {
    var showEditDialog by remember { mutableStateOf(false) }

    if (showEditDialog) {
        RuntimeSettingEditDialog(
            setting = setting,
            onDismiss = { showEditDialog = false },
            onConfirm = {
                onUpdate(it)
                showEditDialog = false
            }
        )
    }

    ListItem(
        headlineContent = { Text(setting.key, fontWeight = FontWeight.Medium) },
        supportingContent = { Text(setting.description ?: setting.value.toString()) },
        trailingContent = {
            val valueAny = setting.value
            if (valueAny is Boolean) {
                Switch(checked = valueAny, onCheckedChange = { onUpdate(it) })
            } else {
                IconButton(onClick = { showEditDialog = true }) {
                    Icon(imageVector = Icons.Default.Edit, contentDescription = null)
                }
            }
        }
    )
}

@Composable
fun RuntimeSettingEditDialog(
    setting: AdminRuntimeSetting,
    onDismiss: () -> Unit,
    onConfirm: (Any) -> Unit
) {
    var text by remember(setting.key) { mutableStateOf(setting.value.toString()) }
    val expectsInt = setting.valueType == "int" || setting.value is Number
    val parsedValue: Any? = if (expectsInt) text.toIntOrNull() else text

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(setting.key) },
        text = {
            Column {
                if (!setting.description.isNullOrBlank()) {
                    Text(setting.description, style = MaterialTheme.typography.bodySmall)
                    Spacer(Modifier.height(8.dp))
                }
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    label = { Text(if (expectsInt) "Число" else "Значение") },
                    isError = parsedValue == null,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                enabled = parsedValue != null,
                onClick = { parsedValue?.let(onConfirm) }
            ) {
                Text("Сохранить")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Отмена") }
        }
    )
}

@Composable
fun NoticeItem(notice: SystemNotice, onToggle: (Boolean) -> Unit, onDelete: () -> Unit) {
    ListItem(
        headlineContent = { Text(notice.title) },
        supportingContent = { Text("${notice.type} • ${notice.showAs}\n${notice.message}") },
        trailingContent = {
            Row {
                Switch(checked = notice.isActive == true, onCheckedChange = onToggle)
                IconButton(onClick = onDelete) {
                    Icon(imageVector = Icons.Default.Delete, contentDescription = null, tint = Color.Red)
                }
            }
        }
    )
}

@Composable
fun UserEditorDialog(
    user: AdminUserDto,
    availableBadges: List<BadgeDto>,
    sessions: List<AccountSession>,
    onDismiss: () -> Unit,
    onRoleToggle: (String, Boolean) -> Unit,
    onBadgeToggle: (String, Boolean, String?) -> Unit,
    onLoadSessions: () -> Unit,
    onRevokeSession: (String) -> Unit
) {
    val roles = listOf("admin", "moderator", "tester", "premium", "plus", "free", "group_leader")

    LaunchedEffect(user.id) {
        onLoadSessions()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Редактировать: ${user.name ?: user.email ?: user.id}") },
        text = {
            LazyColumn(modifier = Modifier.heightIn(max = 500.dp)) {
                item { Text("Роли", style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(vertical = 8.dp)) }
                items(items = roles) { role ->
                    val hasRole = user.roles.any { it.type == role }
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable { onRoleToggle(role, !hasRole) }.padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(checked = hasRole, onCheckedChange = { onRoleToggle(role, it) })
                        Text(role.uppercase(), modifier = Modifier.padding(start = 8.dp))
                    }
                }

                item { Text("Значки", style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(vertical = 8.dp)) }
                items(items = availableBadges) { badge ->
                    val hasBadge = user.badges.any { it.code == badge.code }
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable { onBadgeToggle(badge.code, !hasBadge, null) }.padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(checked = hasBadge, onCheckedChange = { onBadgeToggle(badge.code, it, null) })
                        Text(badge.title, modifier = Modifier.padding(start = 8.dp))
                    }
                }

                item {
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 8.dp)) {
                        Text("Сеансы", style = MaterialTheme.typography.titleSmall)
                        Spacer(Modifier.weight(1f))
                        TextButton(onClick = onLoadSessions) { Text("Обновить") }
                    }
                }
                if (sessions.isEmpty()) {
                    item { Text("Нет активных сеансов", style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(8.dp)) }
                } else {
                    items(items = sessions) { session ->
                        ListItem(
                            headlineContent = { Text(session.deviceName ?: "Устройство", style = MaterialTheme.typography.bodySmall) },
                            supportingContent = { Text("${session.platform} • ${session.safeIpText}", style = MaterialTheme.typography.labelSmall) },
                            trailingContent = {
                                IconButton(onClick = { onRevokeSession(session.id) }) {
                                    Icon(imageVector = Icons.Default.Close, contentDescription = "Revoke", tint = Color.Red, modifier = Modifier.size(16.dp))
                                }
                            }
                        )
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Готово") } }
    )
}

@Composable
fun CreateNoticeDialog(
    onDismiss: () -> Unit,
    onConfirm: (SystemNoticeMutationRequest) -> Unit
) {
    var title by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var type by remember { mutableStateOf("info") }
    var showAs by remember { mutableStateOf("banner") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Новое уведомление") },
        text = {
            Column {
                OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("Заголовок") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = message, onValueChange = { message = it }, label = { Text("Текст") }, modifier = Modifier.fillMaxWidth())

                Text("Тип", modifier = Modifier.padding(top = 8.dp))
                Row {
                    listOf("info", "warning", "maintenance", "critical").forEach {
                        FilterChip(
                            selected = type == it,
                            onClick = { type = it },
                            label = { Text(it) },
                            modifier = Modifier.padding(end = 4.dp)
                        )
                    }
                }

                Text("Показ", modifier = Modifier.padding(top = 8.dp))
                Row {
                    listOf("banner", "modal").forEach {
                        FilterChip(
                            selected = showAs == it,
                            onClick = { showAs = it },
                            label = { Text(it) },
                            modifier = Modifier.padding(end = 4.dp)
                        )
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = {
                onConfirm(SystemNoticeMutationRequest(title, message, type, showAs, true, null, null))
            }) { Text("Создать") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Отмена") } }
    )
}
