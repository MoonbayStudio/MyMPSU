package ru.moonbaystudio.mympsu.ui.screens

import android.content.Context
import android.util.Log
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import ru.moonbaystudio.mympsu.R
import androidx.compose.ui.unit.dp
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import androidx.hilt.navigation.compose.hiltViewModel
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.remote.dto.RoleRequest
import ru.moonbaystudio.mympsu.data.remote.dto.GroupChangeRequestDto
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.BadgeDetailDialog
import ru.moonbaystudio.mympsu.ui.components.BadgeIcon
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.components.UserBadgeRow
import ru.moonbaystudio.mympsu.ui.viewmodel.AuthViewModel
import ru.moonbaystudio.mympsu.ui.viewmodel.SettingsViewModel
import ru.moonbaystudio.mympsu.util.performAppleSignIn
import ru.moonbaystudio.mympsu.util.performGoogleSignIn

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun AccountScreen(
    onNavigateToLogin: () -> Unit,
    onNavigate: (String) -> Unit,
    viewModel: AuthViewModel = hiltViewModel()
) {
    val currentUser by viewModel.currentUser.collectAsState()
    val isLoggedIn by viewModel.isLoggedIn.collectAsState(initial = false)
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.error.collectAsState()
    val roleRequests by viewModel.roleRequests.collectAsState()
    val groupChangeRequests by viewModel.groupChangeRequests.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    
    val settingsViewModel: SettingsViewModel = hiltViewModel()
    val selectedGroupName by settingsViewModel.selectedGroupName.collectAsState()

    LaunchedEffect(isLoggedIn) {
        if (isLoggedIn) {
            viewModel.loadMyRequests()
        }
    }

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Аккаунт"
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(horizontal = 16.dp)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) {
            if (isLoggedIn) {
                if (currentUser == null && isLoading) {
                    Box(modifier = Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                } else {
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
                        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.AccountCircle,
                                contentDescription = null,
                                modifier = Modifier.size(48.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                            Spacer(Modifier.width(16.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(text = currentUser?.name ?: "Пользователь", style = MaterialTheme.typography.titleLarge)
                                    if (currentUser?.badges?.isNotEmpty() == true) {
                                        Spacer(Modifier.width(8.dp))
                                        UserBadgeRow(badges = currentUser!!.badges)
                                    }
                                }

                                Row(modifier = Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                                    currentUser?.roles?.forEach { role ->
                                        Surface(
                                            color = MaterialTheme.colorScheme.primaryContainer,
                                            shape = RoundedCornerShape(4.dp)
                                        ) {
                                            Text(
                                                text = role.title,
                                                style = MaterialTheme.typography.labelSmall,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                            )
                                        }
                                    }

                                    if (selectedGroupName != null) {
                                        Surface(
                                            color = MaterialTheme.colorScheme.secondaryContainer,
                                            shape = RoundedCornerShape(4.dp)
                                        ) {
                                            Text(
                                                text = selectedGroupName!!,
                                                style = MaterialTheme.typography.labelSmall,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                            )
                                        }
                                    }
                                }
                            }

                            IconButton(onClick = { onNavigate("profile_editor") }) {
                                Icon(
                                    Icons.Default.Edit,
                                    contentDescription = "Редактировать профиль",
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    error?.let {
                        Text(
                            text = it,
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(bottom = 8.dp)
                        )
                    }

                    if (currentUser?.contactEmail != null && !currentUser!!.contactEmailVerified) {
                        EmailVerificationBanner(
                            email = currentUser!!.contactEmail!!,
                            onResend = { viewModel.resendEmailVerification() }
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                    } else if (currentUser?.needsContactEmail == true) {
                        EmailRequestCard(
                            onSendRequest = { viewModel.requestEmailVerification(it) }
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                    }

                    AccountOption(icon = Icons.Default.Lock, title = "Безопасность", onClick = { onNavigate("security") })
                    AccountOption(icon = Icons.Default.Group, title = "Моя группа", onClick = { onNavigate("group_members") })
                    AccountOption(icon = Icons.Default.Star, title = "Мой МПГУ Плюс/Премиум", onClick = { onNavigate("premium") })

                    if (currentUser?.isAdmin == true || currentUser?.isModerator == true) {
                        AccountOption(icon = Icons.Default.Settings, title = "Админка", onClick = { onNavigate("admin") })
                    }

                    Spacer(modifier = Modifier.height(24.dp))

                    Button(
                        onClick = { viewModel.logout() },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer,
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Text("Выйти из аккаунта")
                    }
                }
            } else {
                Column(
                    modifier = Modifier.padding(vertical = 32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        Icons.Default.AccountCircle,
                        contentDescription = null,
                        modifier = Modifier.size(80.dp),
                        tint = MaterialTheme.colorScheme.outline
                    )
                    Spacer(Modifier.height(16.dp))
                    Text(
                        text = "Войдите в аккаунт",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "Чтобы синхронизировать расписание и настройки между устройствами",
                        style = MaterialTheme.typography.bodyMedium,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    
                    Spacer(modifier = Modifier.height(32.dp))

                    Button(
                        onClick = onNavigateToLogin,
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Войти или Создать аккаунт")
                    }
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        OutlinedButton(
                            onClick = { 
                                scope.launch {
                                    performGoogleSignIn(context, viewModel)
                                }
                            },
                            modifier = Modifier.weight(1f).height(50.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.outlinedButtonColors(
                                contentColor = MaterialTheme.colorScheme.onSurface
                            )
                        ) {
                            Icon(
                                painter = painterResource(id = R.drawable.ic_google_logo),
                                contentDescription = null,
                                tint = Color.Unspecified,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(Modifier.width(8.dp))
                            Text("Google")
                        }

                        Button(
                            onClick = { performAppleSignIn(context) },
                            modifier = Modifier.weight(1f).height(50.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color.Black,
                                contentColor = Color.White
                            )
                        ) {
                            Icon(
                                painter = painterResource(id = R.drawable.ic_apple_logo),
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(Modifier.width(8.dp))
                            Text("Apple")
                        }
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(120.dp))
        }
    }
}

@Composable
fun MyRequestsCard(
    requests: List<RoleRequest>,
    groupChangeRequests: List<GroupChangeRequestDto>,
    isLoading: Boolean,
    canRequestTester: Boolean,
    onRequestTester: () -> Unit,
    onCancelRoleRequest: (String) -> Unit,
    onCancelGroupChangeRequest: (Int) -> Unit
) {
    val testerRequest = requests.firstOrNull { it.roleType == "tester" }
    val hasPendingTesterRequest = testerRequest?.status == "pending"
    val hasRequests = requests.isNotEmpty() || groupChangeRequests.isNotEmpty()

    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Мои заявки", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)

            if (!hasRequests) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = "Здесь появятся заявки на роли и смену группы.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            if (requests.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                requests.forEach { request ->
                    UserRoleRequestRow(
                        request = request,
                        isLoading = isLoading,
                        onCancel = { onCancelRoleRequest(request.id) }
                    )
                }
            }

            if (groupChangeRequests.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                groupChangeRequests.forEach { request ->
                    GroupChangeRequestRow(
                        request = request,
                        isLoading = isLoading,
                        onCancel = { onCancelGroupChangeRequest(request.id) }
                    )
                }
            }

            if (canRequestTester) {
                Spacer(Modifier.height(12.dp))
                Button(
                    onClick = onRequestTester,
                    enabled = !isLoading && !hasPendingTesterRequest,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(if (hasPendingTesterRequest) "Заявка тестера отправлена" else "Запросить роль тестера")
                }
            }
        }
    }
}

@Composable
fun UserRoleRequestRow(
    request: RoleRequest,
    isLoading: Boolean,
    onCancel: () -> Unit
) {
    RequestStatusRow(
        title = "Роль: ${roleTitle(request.roleType)}",
        subtitle = request.comment ?: request.createdAt,
        status = request.status,
        reviewComment = request.reviewComment,
        isLoading = isLoading,
        onCancel = onCancel
    )
}

@Composable
fun GroupChangeRequestRow(
    request: GroupChangeRequestDto,
    isLoading: Boolean,
    onCancel: () -> Unit
) {
    val currentGroup = request.currentGroupName ?: request.currentGroupId?.toString() ?: "не выбрана"
    val requestedGroup = request.requestedGroupName ?: request.requestedGroupId.toString()
    RequestStatusRow(
        title = "Смена группы",
        subtitle = "$currentGroup -> $requestedGroup",
        status = request.status,
        reviewComment = request.reviewComment,
        isLoading = isLoading,
        onCancel = onCancel
    )
}

@Composable
fun RequestStatusRow(
    title: String,
    subtitle: String,
    status: String,
    reviewComment: String?,
    isLoading: Boolean,
    onCancel: () -> Unit
) {
    val normalizedStatus = status.lowercase()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Surface(
                color = requestStatusColor(normalizedStatus),
                shape = RoundedCornerShape(6.dp)
            ) {
                Text(
                    text = requestStatusText(normalizedStatus),
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    style = MaterialTheme.typography.labelSmall
                )
            }
        }

        if (!reviewComment.isNullOrBlank()) {
            Text(
                text = reviewComment,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp)
            )
        }

        if (normalizedStatus == "pending") {
            TextButton(
                onClick = onCancel,
                enabled = !isLoading,
                modifier = Modifier.align(Alignment.End)
            ) {
                Text("Отменить")
            }
        }
    }
}

@Composable
fun requestStatusColor(status: String): Color {
    return when (status) {
        "approved" -> MaterialTheme.colorScheme.primaryContainer
        "rejected" -> MaterialTheme.colorScheme.errorContainer
        "cancelled" -> MaterialTheme.colorScheme.surfaceVariant
        else -> MaterialTheme.colorScheme.secondaryContainer
    }
}

fun requestStatusText(status: String): String {
    return when (status) {
        "approved" -> "Одобрена"
        "rejected" -> "Отклонена"
        "cancelled" -> "Отменена"
        else -> "На рассмотрении"
    }
}

fun roleTitle(role: String): String {
    return when (role) {
        "tester" -> "тестер"
        "group_leader" -> "староста"
        "moderator" -> "модератор"
        "premium" -> "Premium"
        "plus" -> "Plus"
        else -> role
    }
}

@Composable
fun AccountOption(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(title) },
        leadingContent = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
        trailingContent = { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null) },
        modifier = Modifier.clickable(onClick = onClick)
    )
}

@Composable
fun EmailVerificationBanner(email: String, onResend: () -> Unit) {
    Surface(
        color = MaterialTheme.colorScheme.errorContainer,
        shape = MaterialTheme.shapes.medium
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = "Email не подтвержден", style = MaterialTheme.typography.titleSmall)
            Text(text = "Проверьте почту $email и перейдите по ссылке.", style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = onResend) {
                Text("Отправить письмо еще раз")
            }
        }
    }
}

@Composable
fun EmailRequestCard(onSendRequest: (String) -> Unit) {
    var email by remember { mutableStateOf("") }
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = "Укажите контактный Email", style = MaterialTheme.typography.titleSmall)
            Text(text = "Он нужен для входа по паролю и восстановления доступа.", style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email") },
                modifier = Modifier.fillMaxWidth()
            )
            Button(
                onClick = { onSendRequest(email) },
                modifier = Modifier.padding(top = 8.dp),
                enabled = email.isNotBlank()
            ) {
                Text("Отправить код")
            }
        }
    }
}
