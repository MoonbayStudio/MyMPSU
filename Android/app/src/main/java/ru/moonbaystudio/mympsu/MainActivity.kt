package ru.moonbaystudio.mympsu

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.ui.viewmodel.AuthViewModel
import ru.moonbaystudio.mympsu.ui.components.ThemedBackground
import ru.moonbaystudio.mympsu.ui.screens.AboutScreen
import ru.moonbaystudio.mympsu.ui.screens.AccessibilitySettingsScreen
import ru.moonbaystudio.mympsu.ui.screens.AccountScreen
import ru.moonbaystudio.mympsu.ui.screens.AccountSessionsScreen
import ru.moonbaystudio.mympsu.ui.screens.AdminPanelScreen
import ru.moonbaystudio.mympsu.ui.viewmodel.AdminViewModel
import ru.moonbaystudio.mympsu.ui.viewmodel.RuntimeConfigViewModel
import ru.moonbaystudio.mympsu.ui.screens.AssistantScreen
import ru.moonbaystudio.mympsu.ui.screens.EmailChangeScreen
import ru.moonbaystudio.mympsu.ui.screens.GroupMembersScreen
import ru.moonbaystudio.mympsu.ui.screens.GroupSelectionScreen
import ru.moonbaystudio.mympsu.ui.screens.LaunchScreen
import ru.moonbaystudio.mympsu.ui.screens.LoginScreen
import ru.moonbaystudio.mympsu.ui.screens.MenuScreen
import ru.moonbaystudio.mympsu.ui.screens.OnboardingScreen
import ru.moonbaystudio.mympsu.ui.screens.PasswordSetupScreen
import ru.moonbaystudio.mympsu.ui.screens.PremiumScreen
import ru.moonbaystudio.mympsu.ui.screens.ProfileEditorScreen
import ru.moonbaystudio.mympsu.ui.screens.ScheduleScreen
import ru.moonbaystudio.mympsu.ui.screens.SessionScreen
import ru.moonbaystudio.mympsu.ui.screens.SecurityScreen
import ru.moonbaystudio.mympsu.ui.screens.SettingsScreen
import ru.moonbaystudio.mympsu.ui.screens.ThemesSettingsScreen
import ru.moonbaystudio.mympsu.ui.theme.AppThemeCatalog
import ru.moonbaystudio.mympsu.ui.theme.MyMPSUTheme
import ru.moonbaystudio.mympsu.service.ScheduleLiveService
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject
    lateinit var userPreferences: UserPreferences

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)

        // Обработка Deep Link при запуске
        intent?.data?.let { handleAuthDeepLink(it) }

        setContent {
            var showLaunchScreen by remember { mutableStateOf(true) }
            val selectedThemeId by userPreferences.selectedThemeId.collectAsState(initial = "classic")
            val followSystemTheme by userPreferences.followSystemTheme.collectAsState(initial = true)
            val selectedThemeFamilyId by userPreferences.selectedThemeFamilyId.collectAsState(initial = "standard")
            val isSystemDark = isSystemInDarkTheme()

            val appTheme = remember(selectedThemeId, followSystemTheme, selectedThemeFamilyId, isSystemDark) {
                if (followSystemTheme) {
                    val family = AppThemeCatalog.families.find { it.id == selectedThemeFamilyId }
                        ?: AppThemeCatalog.families[0]
                    AppThemeCatalog.theme(if (isSystemDark) family.darkThemeID else family.lightThemeID)
                } else {
                    AppThemeCatalog.theme(selectedThemeId)
                }
            }

            val liveActivityEnabled by userPreferences.liveActivityEnabled.collectAsState(initial = true)
            val highContrast by userPreferences.highContrast.collectAsState(initial = false)
            val largerText by userPreferences.largerText.collectAsState(initial = false)
            val selectedGroupId by userPreferences.selectedGroupId.collectAsState(initial = null)
            val scheduleGroupId by userPreferences.scheduleGroupId.collectAsState(initial = null)
            val onboardingCompleted by userPreferences.onboardingCompleted.collectAsState(initial = null)

            LaunchedEffect(liveActivityEnabled, selectedGroupId) {
                val intent = android.content.Intent(this@MainActivity, ScheduleLiveService::class.java)
                if (liveActivityEnabled && selectedGroupId != null) {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                } else {
                    stopService(intent)
                }
            }

            MyMPSUTheme(
                appTheme = appTheme,
                highContrast = highContrast,
                largerText = largerText
            ) {
                ThemedBackground(theme = appTheme) {
                    if (showLaunchScreen) {
                        LaunchScreen(onFinished = { showLaunchScreen = false })
                    } else {
                        AppNavigation(selectedGroupId, scheduleGroupId ?: selectedGroupId, onboardingCompleted)
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: android.content.Intent?) {
        super.onNewIntent(intent)
        intent?.data?.let { handleAuthDeepLink(it) }
    }

    private fun handleAuthDeepLink(uri: android.net.Uri) {
        if (uri.scheme == "mympsu" && uri.host == "auth") {
            val token = uri.getQueryParameter("token")
            if (token != null) {
                CoroutineScope(Dispatchers.Main).launch {
                    userPreferences.saveAuthToken(token)
                }
            }
        }
    }

}

sealed class Screen(val route: String, val label: String, val icon: ImageVector) {
    object Schedule : Screen("schedule", "Пары", Icons.Default.Home)
    object Pelikasha : Screen("pelikasha", "Помощник МПГУ", Icons.Default.Face)
    object Session : Screen("session", "Сессия", Icons.Default.DateRange)
    object Account : Screen("account", "Аккаунт", Icons.Default.AccountCircle)
    object Menu : Screen("menu", "Меню", Icons.Default.Menu)
}

@Composable
fun AppNavigation(selectedGroupId: Int?, scheduleGroupId: Int?, onboardingCompleted: Boolean?) {
    if (onboardingCompleted == null) return // Wait for preferences to load

    val navController = rememberNavController()
    val runtimeConfigViewModel: RuntimeConfigViewModel = hiltViewModel()
    val runtimeState by runtimeConfigViewModel.state.collectAsState()
    val lifecycleOwner = LocalLifecycleOwner.current
    val startDestination = if (onboardingCompleted == false) "onboarding"
                          else if (scheduleGroupId != null) Screen.Schedule.route
                          else "group_selection"

    val items = listOf(
        Screen.Schedule,
        Screen.Pelikasha,
        Screen.Session,
        Screen.Account,
        Screen.Menu
    )

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START) {
                runtimeConfigViewModel.refresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Box(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        NavHost(
            navController = navController,
            startDestination = startDestination,
            modifier = Modifier.fillMaxSize(),
            enterTransition = { fadeIn(animationSpec = tween(300)) },
            exitTransition = { fadeOut(animationSpec = tween(300)) },
            popEnterTransition = { fadeIn(animationSpec = tween(300)) },
            popExitTransition = { fadeOut(animationSpec = tween(300)) }
        ) {
            composable("onboarding") {
                OnboardingScreen(
                    onFinish = {
                        navController.navigate(if (scheduleGroupId != null) Screen.Schedule.route else "group_selection") {
                            popUpTo("onboarding") { inclusive = true }
                        }
                    }
                )
            }
            composable("group_selection") {
                GroupSelectionScreen(
                    onGroupSelected = {
                        navController.navigate(Screen.Schedule.route) {
                            popUpTo("group_selection") { inclusive = true }
                        }
                    },
                    onBack = if (selectedGroupId != null) {
                        { navController.popBackStack() }
                    } else null
                )
            }
            composable("default_group_selection") {
                GroupSelectionScreen(
                    onGroupSelected = { navController.popBackStack() },
                    onBack = { navController.popBackStack() },
                    changesDefaultGroup = true
                )
            }
            composable(Screen.Schedule.route) {
                if (scheduleGroupId != null) {
                    ScheduleScreen(
                        groupId = scheduleGroupId
                    )
                }
            }
            composable(Screen.Pelikasha.route) {
                AssistantScreen()
            }
            composable(Screen.Session.route) {
                if (scheduleGroupId != null) {
                    SessionScreen(
                        groupId = scheduleGroupId
                    )
                }
            }
            composable(Screen.Account.route) {
                AccountScreen(
                    onNavigateToLogin = { navController.navigate("login") },
                    onNavigate = { route: String -> navController.navigate(route) }
                )
            }
            composable(Screen.Menu.route) {
                MenuScreen(onNavigate = { route: String ->
                    navController.navigate(route)
                })
            }
            composable("settings") {
                SettingsScreen(
                    onNavigate = { route: String -> navController.navigate(route) },
                    onBack = { navController.popBackStack() }
                )
            }
            composable("themes") {
                ThemesSettingsScreen(onBack = { navController.popBackStack() })
            }
            composable("accessibility") {
                AccessibilitySettingsScreen(onBack = { navController.popBackStack() })
            }
            composable("about") {
                AboutScreen(onBack = { navController.popBackStack() })
            }
            composable("group_members") {
                GroupMembersScreen(onBack = { navController.popBackStack() })
            }
            composable("profile_editor") {
                ProfileEditorScreen(
                    onBack = { navController.popBackStack() },
                    onNavigate = { route: String -> navController.navigate(route) }
                )
            }
            composable("admin") {
                AdminPanelScreen(
                    onBack = { navController.popBackStack() }
                )
            }
            composable("security") {
                SecurityScreen(
                    onNavigate = { route: String -> navController.navigate(route) },
                    onBack = { navController.popBackStack() }
                )
            }
            composable("sessions") {
                AccountSessionsScreen(onBack = { navController.popBackStack() })
            }
            composable("email_change") {
                EmailChangeScreen(onBack = { navController.popBackStack() })
            }
            composable("password_setup") {
                PasswordSetupScreen(onBack = { navController.popBackStack() })
            }
            composable("premium") {
                PremiumScreen(onBack = { navController.popBackStack() })
            }
            composable("login") {
                LoginScreen(onLoginSuccess = {
                    navController.navigate(Screen.Schedule.route) {
                        popUpTo("login") { inclusive = true }
                    }
                })
            }
        }

        if (selectedGroupId != null) {
            BottomIsland(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 24.dp),
                navController = navController,
                items = items
            )
        }

        RuntimeNoticeOverlay(
            state = runtimeState,
            onDismissNotice = runtimeConfigViewModel::dismissNotice
        )
    }
}

@Composable
fun RuntimeNoticeOverlay(
    state: ru.moonbaystudio.mympsu.data.repository.RuntimeConfigState,
    onDismissNotice: (Int) -> Unit
) {
    val notice = state.notice

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (state.config.maintenanceMode) {
            RuntimeBanner(
                title = "Технические работы",
                message = "Часть функций может быть временно недоступна.",
                color = MaterialTheme.colorScheme.errorContainer,
                onDismiss = null
            )
        }

        if (notice != null && notice.showAs == "banner") {
            RuntimeBanner(
                title = notice.title,
                message = notice.message,
                color = when (notice.type) {
                    "critical", "maintenance" -> MaterialTheme.colorScheme.errorContainer
                    "warning" -> MaterialTheme.colorScheme.tertiaryContainer
                    else -> MaterialTheme.colorScheme.secondaryContainer
                },
                onDismiss = if (notice.dismissible) ({ onDismissNotice(notice.id) }) else null
            )
        }
    }

    if (notice != null && notice.showAs == "modal") {
        AlertDialog(
            onDismissRequest = {
                if (notice.dismissible) onDismissNotice(notice.id)
            },
            title = { Text(notice.title) },
            text = { Text(notice.message) },
            confirmButton = {
                if (notice.dismissible) {
                    TextButton(onClick = { onDismissNotice(notice.id) }) {
                        Text("Понятно")
                    }
                }
            },
            properties = DialogProperties(dismissOnBackPress = notice.dismissible, dismissOnClickOutside = notice.dismissible)
        )
    }
}

@Composable
private fun RuntimeBanner(
    title: String,
    message: String,
    color: Color,
    onDismiss: (() -> Unit)?
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = color,
        tonalElevation = 6.dp,
        shadowElevation = 8.dp
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(2.dp))
                Text(message, style = MaterialTheme.typography.bodyMedium)
            }
            if (onDismiss != null) {
                IconButton(onClick = onDismiss) {
                    Icon(imageVector = Icons.Default.Close, contentDescription = "Закрыть")
                }
            }
        }
    }
}

@Composable
fun BottomIsland(
    modifier: Modifier = Modifier,
    navController: androidx.navigation.NavController,
    items: List<Screen>
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    Surface(
        modifier = modifier
            .padding(horizontal = 16.dp)
            .height(64.dp)
            .clip(RoundedCornerShape(32.dp)),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.95f),
        tonalElevation = 8.dp,
        shadowElevation = 12.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.CenterVertically
        ) {
            items.forEach { screen ->
                val selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true
                IconButton(
                    onClick = {
                        navController.navigate(screen.route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = false
                            }
                            launchSingleTop = true
                            restoreState = false
                        }
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = screen.icon,
                            contentDescription = screen.label,
                            tint = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        if (selected) {
                            Box(
                                modifier = Modifier
                                    .size(4.dp)
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(MaterialTheme.colorScheme.primary)
                            )
                        }
                    }
                }
            }
        }
    }

}
