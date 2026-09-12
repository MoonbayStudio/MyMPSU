package ru.moonbaystudio.mympsu.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import ru.moonbaystudio.mympsu.data.remote.dto.BadgeDto

@Composable
fun BadgeIcon(
    badge: BadgeDto,
    size: Int = 20,
    onClick: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val resourceId = remember(badge.iconName) {
        context.resources.getIdentifier(badge.iconName, "drawable", context.packageName)
    }

    if (resourceId != 0) {
        Image(
            painter = painterResource(id = resourceId),
            contentDescription = badge.title,
            modifier = Modifier
                .size(size.dp)
                .let { if (onClick != null) it.clickable { onClick() } else it }
        )
    }
}

@Composable
fun UserBadgeRow(
    badges: List<BadgeDto>,
    maxBadges: Int = 3
) {
    var selectedBadge by remember { mutableStateOf<BadgeDto?>(null) }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        badges.take(maxBadges).forEach { badge ->
            BadgeIcon(badge) {
                selectedBadge = badge
            }
        }
    }

    selectedBadge?.let { badge ->
        BadgeDetailDialog(badge = badge, onDismiss = { selectedBadge = null })
    }
}

@Composable
fun BadgeDetailDialog(
    badge: BadgeDto,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Закрыть")
            }
        },
        title = {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                BadgeIcon(badge, size = 32)
                Text(badge.title)
            }
        },
        text = {
            Column {
                Text(badge.description ?: "Нет описания", style = MaterialTheme.typography.bodyMedium)
                Spacer(modifier = Modifier.height(8.dp))
                val rarityColor = when(badge.rarity) {
                    "common" -> Color.Gray
                    "rare" -> Color(0xFF2196F3)
                    "epic" -> Color(0xFF9C27B0)
                    "legendary" -> Color(0xFFFF9800)
                    else -> MaterialTheme.colorScheme.secondary
                }
                val rarityText = when(badge.rarity) {
                    "common" -> "Обычный"
                    "rare" -> "Редкий"
                    "epic" -> "Эпический"
                    "legendary" -> "Легендарный"
                    else -> badge.rarity
                }
                Text(
                    text = rarityText.uppercase(),
                    style = MaterialTheme.typography.labelSmall,
                    color = rarityColor,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    )
}
