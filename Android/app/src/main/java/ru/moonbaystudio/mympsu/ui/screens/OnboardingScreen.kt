package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.model.MyGroup
import ru.moonbaystudio.mympsu.ui.viewmodel.AuthViewModel
import ru.moonbaystudio.mympsu.util.performAppleSignIn
import ru.moonbaystudio.mympsu.util.performGoogleSignIn
import ru.moonbaystudio.mympsu.ui.viewmodel.GroupSelectionViewModel
import ru.moonbaystudio.mympsu.ui.viewmodel.OnboardingViewModel
import ru.moonbaystudio.mympsu.ui.viewmodel.SettingsViewModel

private enum class OnboardingAuthFlow {
    Login,
    Signup,
    Social
}

@Composable
fun OnboardingScreen(
    onFinish: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
    authViewModel: AuthViewModel = hiltViewModel(),
    groupViewModel: GroupSelectionViewModel = hiltViewModel(),
    settingsViewModel: SettingsViewModel = hiltViewModel()
) {
    val pagerState = rememberPagerState(pageCount = { 5 })
    val currentStep by viewModel.currentStep.collectAsState()
    val defaultGroupId by groupViewModel.selectedGroupId.collectAsState(initial = null)

    LaunchedEffect(currentStep) {
        if (currentStep < 5) {
            pagerState.animateScrollToPage(currentStep)
        } else {
            onFinish()
        }
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f),
                userScrollEnabled = false
            ) { page ->
                when (page) {
                    0 -> OnboardingAuthStep(
                        viewModel = authViewModel,
                        defaultGroupId = defaultGroupId,
                        onAccountReady = {
                            viewModel.completeOnboarding()
                            onFinish()
                        },
                        onContinue = { viewModel.nextStep() }
                    )
                    1 -> OnboardingGroupStep(groupViewModel) { viewModel.nextStep() }
                    2 -> OnboardingAccessibilityStep(settingsViewModel) { viewModel.nextStep() }
                    3 -> OnboardingCacheStep(settingsViewModel) { viewModel.nextStep() }
                    4 -> OnboardingCompleteStep(onFinish = {
                        viewModel.completeOnboarding()
                        onFinish()
                    })
                }
            }

            // Navigation Bar
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Back Button
                if (currentStep > 0 && currentStep < 4) {
                    OutlinedButton(
                        onClick = { viewModel.prevStep() },
                        shape = CircleShape,
                        modifier = Modifier.size(56.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Icon(imageVector = Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Назад")
                    }
                } else {
                    Spacer(Modifier.size(56.dp))
                }

                // Progress dots
                Row(horizontalArrangement = Arrangement.Center) {
                    repeat(5) { iteration ->
                        val color = if (pagerState.currentPage == iteration) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant
                        Box(
                            modifier = Modifier
                                .padding(4.dp)
                                .size(10.dp)
                                .background(color, RoundedCornerShape(5.dp))
                        )
                    }
                }

                // Next Button
                if (currentStep < 4) {
                    Button(
                        onClick = { viewModel.nextStep() },
                        shape = CircleShape,
                        modifier = Modifier.size(56.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Icon(imageVector = Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "Далее")
                    }
                } else {
                    Spacer(Modifier.size(56.dp))
                }
            }
        }
    }
}

@Composable
fun OnboardingAuthStep(
    viewModel: AuthViewModel,
    defaultGroupId: Int?,
    onAccountReady: () -> Unit,
    onContinue: () -> Unit
) {
    val isLoggedIn by viewModel.isLoggedIn.collectAsState(initial = false)
    val isLoading by viewModel.isLoading.collectAsState()
    val isVerificationRequired by viewModel.isVerificationRequired.collectAsState()
    val error by viewModel.error.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val latestDefaultGroupId by rememberUpdatedState(defaultGroupId)
    var authFlow by remember { mutableStateOf<OnboardingAuthFlow?>(null) }
    var didHandleAuth by remember { mutableStateOf(false) }
    var showEmailAuth by remember { mutableStateOf(false) }
    var isRegisterMode by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var verificationCode by remember { mutableStateOf("") }

    LaunchedEffect(isLoggedIn, isLoading) {
        if (isLoggedIn && !isLoading && !didHandleAuth) {
            didHandleAuth = true
            delay(200)
            if (authFlow == OnboardingAuthFlow.Signup || latestDefaultGroupId == null) {
                onContinue()
            } else {
                onAccountReady()
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.AccountCircle,
            contentDescription = null,
            modifier = Modifier.size(120.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        Spacer(Modifier.height(32.dp))
        Text("Ваш аккаунт", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            "Войдите, чтобы ваши данные всегда были под рукой на любом устройстве.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 16.dp)
        )

        Spacer(Modifier.height(48.dp))

        if (showEmailAuth) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.42f))
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    if (isVerificationRequired) {
                        Text("Подтвердите регистрацию", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                        OutlinedTextField(
                            value = verificationCode,
                            onValueChange = { verificationCode = it.filter(Char::isDigit).take(6) },
                            label = { Text("Код из письма") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                        )
                        Button(
                            onClick = {
                                authFlow = OnboardingAuthFlow.Signup
                                viewModel.verifySignup(verificationCode)
                            },
                            enabled = !isLoading && verificationCode.length == 6,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            if (isLoading) CircularProgressIndicator(modifier = Modifier.size(18.dp))
                            else Text("Подтвердить")
                        }
                    } else {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilterChip(
                                selected = !isRegisterMode,
                                onClick = { isRegisterMode = false },
                                label = { Text("Вход") }
                            )
                            FilterChip(
                                selected = isRegisterMode,
                                onClick = { isRegisterMode = true },
                                label = { Text("Регистрация") }
                            )
                        }

                        if (isRegisterMode) {
                            OutlinedTextField(
                                value = name,
                                onValueChange = { name = it },
                                label = { Text("Имя") },
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true
                            )
                        }
                        OutlinedTextField(
                            value = email,
                            onValueChange = { email = it },
                            label = { Text("Email") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
                        )
                        OutlinedTextField(
                            value = password,
                            onValueChange = { password = it },
                            label = { Text("Пароль") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            visualTransformation = PasswordVisualTransformation(),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password)
                        )
                        Button(
                            onClick = {
                                didHandleAuth = false
                                if (isRegisterMode) {
                                    authFlow = OnboardingAuthFlow.Signup
                                    viewModel.register(name, email, password)
                                } else {
                                    authFlow = OnboardingAuthFlow.Login
                                    viewModel.login(email, password)
                                }
                            },
                            enabled = !isLoading && email.isNotBlank() && password.isNotBlank() && (!isRegisterMode || name.isNotBlank()),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            if (isLoading) CircularProgressIndicator(modifier = Modifier.size(18.dp))
                            else Text(if (isRegisterMode) "Создать аккаунт" else "Войти")
                        }
                    }

                    if (error != null) {
                        Text(
                            error!!,
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        } else {
            OutlinedButton(
                onClick = { showEmailAuth = true },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(16.dp)
            ) {
                Icon(Icons.Default.Email, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Войти или зарегистрироваться по email")
            }
            Spacer(Modifier.height(16.dp))
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Button(
                onClick = {
                    didHandleAuth = false
                    authFlow = OnboardingAuthFlow.Social
                    scope.launch {
                        performGoogleSignIn(context, viewModel)
                    }
                },
                modifier = Modifier.weight(1f).height(56.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.onSurface
                ),
                elevation = ButtonDefaults.buttonElevation(defaultElevation = 2.dp)
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
                onClick = {
                    didHandleAuth = false
                    authFlow = OnboardingAuthFlow.Social
                    performAppleSignIn(context)
                },
                modifier = Modifier.weight(1f).height(56.dp),
                shape = RoundedCornerShape(16.dp),
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

        Spacer(Modifier.height(16.dp))

        TextButton(onClick = onContinue) {
            Text("Пропустить", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun OnboardingGroupStep(viewModel: GroupSelectionViewModel, onNext: () -> Unit) {
    val institutes by viewModel.institutes.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val selectionMessage by viewModel.selectionMessage.collectAsState()
    val isSelectingGroup by viewModel.isSelectingGroup.collectAsState()
    val defaultGroupId by viewModel.selectedGroupId.collectAsState(initial = null)
    var pendingGroup by remember { mutableStateOf<MyGroup?>(null) }
    var pendingWarning by remember { mutableStateOf<GroupSelectionWarning?>(null) }

    fun applyGroupSelection(group: MyGroup) {
        val groupId = group.id.toIntOrNull() ?: return
        viewModel.selectGroup(groupId, group.name) {
            onNext()
        }
    }

    fun requestGroupSelection(group: MyGroup) {
        if (defaultGroupId == null) {
            pendingGroup = group
            pendingWarning = GroupSelectionWarning.InitialDefaultGroup
            return
        }
        applyGroupSelection(group)
    }

    if (pendingWarning != null) {
        AlertDialog(
            onDismissRequest = {
                pendingGroup = null
                pendingWarning = null
            },
            title = { Text("Группа по умолчанию") },
            text = {
                Text("Эта группа будет привязана к аккаунту. По ней будут показываться домашка и участники. Позже сменить её можно будет только через заявку модератору.")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val group = pendingGroup
                        pendingGroup = null
                        pendingWarning = null
                        if (group != null) {
                            applyGroupSelection(group)
                        }
                    }
                ) {
                    Text("Понял")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        pendingGroup = null
                        pendingWarning = null
                    }
                ) {
                    Text("Отмена")
                }
            }
        )
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Ваша группа", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            "Выберите ваш институт и группу для отображения актуального расписания.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp, bottom = 24.dp)
        )

        Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            } else {
                LazyColumn {
                    if (selectionMessage != null || isSelectingGroup) {
                        item {
                            Text(
                                text = selectionMessage ?: "Обновляем группу",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth().padding(12.dp)
                            )
                        }
                    }
                    items(items = institutes) { institute ->
                        var expanded by remember { mutableStateOf(false) }
                        Column {
                            ListItem(
                                headlineContent = { Text(institute.name, fontWeight = FontWeight.Medium) },
                                trailingContent = {
                                    Icon(
                                        imageVector = if (expanded) Icons.Default.ArrowDropUp else Icons.Default.ArrowDropDown,
                                        contentDescription = null
                                    )
                                },
                                modifier = Modifier.clickable { expanded = !expanded }
                            )
                            if (expanded) {
                                institute.groups.forEach { group ->
                                    ListItem(
                                        headlineContent = { Text(group.name) },
                                        modifier = Modifier
                                            .padding(start = 16.dp)
                                            .clickable(enabled = !isSelectingGroup) {
                                                requestGroupSelection(group)
                                            }
                                    )
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
fun OnboardingAccessibilityStep(viewModel: SettingsViewModel, onNext: () -> Unit) {
    val highContrast by viewModel.highContrast.collectAsState()
    val largerText by viewModel.largerText.collectAsState()

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Settings,
            contentDescription = null,
            modifier = Modifier.size(100.dp),
            tint = MaterialTheme.colorScheme.secondary
        )
        Spacer(Modifier.height(32.dp))
        Text("Спец. возможности", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            "Мы заботимся о вашем удобстве. Настройте интерфейс под себя.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 16.dp, bottom = 32.dp)
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
        ) {
            Column(modifier = Modifier.padding(8.dp)) {
                ListItem(
                    headlineContent = { Text("Увеличенный шрифт", fontWeight = FontWeight.SemiBold) },
                    supportingContent = { Text("Сделает расписание более читаемым") },
                    trailingContent = { Switch(checked = largerText, onCheckedChange = { viewModel.updateLargerText(it) }) },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent)
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
                ListItem(
                    headlineContent = { Text("Высокий контраст", fontWeight = FontWeight.SemiBold) },
                    supportingContent = { Text("Улучшит видимость элементов") },
                    trailingContent = { Switch(checked = highContrast, onCheckedChange = { viewModel.updateHighContrast(it) }) },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent)
                )
            }
        }

        Spacer(Modifier.height(32.dp))
        TextButton(onClick = onNext) { Text("Готово") }
    }
}

@Composable
fun OnboardingCacheStep(viewModel: SettingsViewModel, onNext: () -> Unit) {
    val weeks by viewModel.scheduleCacheWeeks.collectAsState()

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Info,
            contentDescription = null,
            modifier = Modifier.size(100.dp),
            tint = MaterialTheme.colorScheme.tertiary
        )
        Spacer(Modifier.height(32.dp))
        Text("Офлайн доступ", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            "Выберите, на сколько недель вперед сохранять расписание в памяти телефона.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 16.dp, bottom = 48.dp)
        )

        Text("Кэшировать на $weeks нед.", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)

        Slider(
            value = weeks.toFloat(),
            onValueChange = { viewModel.updateScheduleCacheWeeks(it.toInt()) },
            valueRange = 1f..4f,
            steps = 2,
            modifier = Modifier.padding(horizontal = 16.dp)
        )

        Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("1 нед.", style = MaterialTheme.typography.labelMedium)
            Text("4 нед.", style = MaterialTheme.typography.labelMedium)
        }

        Spacer(Modifier.height(32.dp))
        TextButton(onClick = onNext) { Text("Продолжить") }
    }
}

@Composable
fun OnboardingCompleteStep(onFinish: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = null,
            modifier = Modifier.size(140.dp),
            tint = Color(0xFF4CAF50)
        )
        Spacer(Modifier.height(40.dp))
        Text("Все готово!", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.ExtraBold)
        Text(
            "Теперь вы готовы к учебе вместе с MyMPSU. Все настройки можно изменить позже в профиле.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 16.dp, bottom = 64.dp)
        )

        Button(
            onClick = onFinish,
            modifier = Modifier.fillMaxWidth().height(64.dp),
            shape = RoundedCornerShape(20.dp),
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
        ) {
            Text("Начать пользоваться", fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
    }
}
