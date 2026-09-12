package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.theme.AppThemeCatalog
import ru.moonbaystudio.mympsu.ui.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemesSettingsScreen(
    onBack: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val selectedThemeId by viewModel.selectedThemeId.collectAsState()
    val followSystemTheme by viewModel.followSystemTheme.collectAsState()
    val selectedThemeFamilyId by viewModel.selectedThemeFamilyId.collectAsState()
    val themes = AppThemeCatalog.themes
    val families = AppThemeCatalog.families

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Темы",
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
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 104.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                ListItem(
                    headlineContent = { Text("Следовать за системой") },
                    supportingContent = { Text("Автоматически переключать светлую и темную тему") },
                    trailingContent = {
                        Switch(
                            checked = followSystemTheme,
                            onCheckedChange = { viewModel.updateFollowSystemTheme(it) }
                        )
                    }
                )
                HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            }

            if (followSystemTheme) {
                item {
                    Text("Выберите стиль", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(bottom = 8.dp))
                }
                items(families) { family ->
                    ThemeFamilyCard(
                        family = family,
                        isSelected = selectedThemeFamilyId == family.id,
                        onClick = { viewModel.updateThemeFamily(family.id) }
                    )
                }
            } else {
                item {
                    Text("Все темы", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(bottom = 8.dp))
                }
                items(themes) { theme ->
                    ThemeCard(
                        theme = theme,
                        isSelected = selectedThemeId == theme.id,
                        onClick = { viewModel.updateTheme(theme.id) }
                    )
                }
            }
        }
    }
}

@Composable
fun ThemeFamilyCard(
    family: ru.moonbaystudio.mympsu.ui.theme.AppThemeFamily,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected)
                MaterialTheme.colorScheme.primaryContainer
            else MaterialTheme.colorScheme.surface
        ),
        border = if (isSelected)
            null
        else androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = family.name, style = MaterialTheme.typography.titleMedium)
                Text(text = family.subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (isSelected) {
                Icon(Icons.Default.Check, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
        }
    }
}

@Composable
fun ThemeCard(
    theme: ru.moonbaystudio.mympsu.ui.theme.AppTheme,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected)
                MaterialTheme.colorScheme.primaryContainer
            else MaterialTheme.colorScheme.surface
        ),
        border = if (isSelected)
            null
        else androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(theme.primaryColor)
            )
            Spacer(Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(text = theme.name, style = MaterialTheme.typography.titleMedium)
            }
            if (isSelected) {
                Icon(Icons.Default.Check, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
        }
    }
}
