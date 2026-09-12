package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.components.UserBadgeRow
import ru.moonbaystudio.mympsu.ui.viewmodel.GroupMembersViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GroupMembersScreen(
    onBack: () -> Unit,
    viewModel: GroupMembersViewModel = hiltViewModel()
) {
    val users by viewModel.users.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val selectedGroupId by viewModel.selectedGroupId.collectAsState(initial = null)

    LaunchedEffect(selectedGroupId) {
        viewModel.loadUsers()
    }

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Моя группа",
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
                }
            )
        }
    ) { padding ->
        if (isLoading) {
            Box(modifier = Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else if (selectedGroupId == null) {
            EmptyGroupState(padding, "Группа не выбрана")
        } else if (users.isEmpty()) {
            EmptyGroupState(padding, "В этой группе еще нет участников")
        } else {
            LazyColumn(
                modifier = Modifier
                    .padding(padding)
                    .fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 104.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(items = users) { user ->
                    ListItem(
                        headlineContent = {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(user.name ?: "Без имени", fontWeight = FontWeight.SemiBold)
                                if (user.badges.isNotEmpty()) {
                                    Spacer(Modifier.width(8.dp))
                                    val rarityScore = mapOf("legendary" to 4, "epic" to 3, "rare" to 2, "common" to 1)
                                    val sortedBadges = user.badges.sortedByDescending { rarityScore[it.rarity] ?: 0 }
                                    UserBadgeRow(badges = sortedBadges, maxBadges = 2)
                                }
                            }
                        },
                        supportingContent = {
                            Column {
                                Text(user.email ?: "Email не указан", style = MaterialTheme.typography.bodySmall)
                                if (user.roles.isNotEmpty()) {
                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                                        modifier = Modifier.padding(top = 4.dp)
                                    ) {
                                        user.roles.forEach { role ->
                                            SuggestionChip(
                                                onClick = {},
                                                label = { Text(role.title, style = MaterialTheme.typography.labelSmall) }
                                            )
                                        }
                                    }
                                }
                            }
                        },
                        leadingContent = { Icon(imageVector = Icons.Default.AccountCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(32.dp)) }
                    )
                }
            }
        }
    }
}

@Composable
fun EmptyGroupState(padding: PaddingValues, message: String) {
    Box(modifier = Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
            Icon(
                imageVector = Icons.Default.Person,
                contentDescription = null,
                modifier = Modifier.size(80.dp),
                tint = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f)
            )
            Spacer(Modifier.height(16.dp))
            Text(
                text = message,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Пригласите своих одногруппников скачать MyMPSU!",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )
        }
    }
}
