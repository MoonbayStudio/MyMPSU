package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp

import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MenuScreen(
    onNavigate: (String) -> Unit
) {
    Scaffold(
        topBar = { CapsuleHeader(title = "Меню") }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(bottom = 104.dp)
        ) {
            item {
                MenuItem(icon = Icons.Default.List, title = "Институты и группы", onClick = { onNavigate("group_selection") })
            }
            item {
                MenuItem(icon = Icons.Default.Settings, title = "Настройки приложения", onClick = { onNavigate("settings") })
            }
            item {
                MenuItem(icon = Icons.Default.Info, title = "О приложении", onClick = { onNavigate("about") })
            }
        }
    }
}

@Composable
fun MenuItem(icon: ImageVector, title: String, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(title) },
        leadingContent = { Icon(icon, contentDescription = null) },
        modifier = Modifier.clickable(onClick = onClick)
    )
}
