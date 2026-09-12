package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.data.model.Institute
import ru.moonbaystudio.mympsu.data.model.MyGroup
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.viewmodel.GroupSelectionViewModel

enum class GroupSelectionWarning {
    InitialDefaultGroup,
    ChangeDefaultGroup
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GroupSelectionScreen(
    onGroupSelected: () -> Unit,
    onBack: (() -> Unit)? = null,
    changesDefaultGroup: Boolean = false,
    viewModel: GroupSelectionViewModel = hiltViewModel()
) {
    val institutes by viewModel.institutes.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val selectionMessage by viewModel.selectionMessage.collectAsState()
    val isSelectingGroup by viewModel.isSelectingGroup.collectAsState()
    val defaultGroupId by viewModel.selectedGroupId.collectAsState(initial = null)
    var pendingGroup by remember { mutableStateOf<MyGroup?>(null) }
    var pendingWarning by remember { mutableStateOf<GroupSelectionWarning?>(null) }

    fun applyGroupSelection(group: MyGroup) {
        val groupId = group.id.toIntOrNull() ?: return
        if (changesDefaultGroup) {
            viewModel.selectDefaultGroup(groupId, group.name) {
                onGroupSelected()
            }
        } else {
            viewModel.selectGroup(groupId, group.name) {
                onGroupSelected()
            }
        }
    }

    fun requestGroupSelection(group: MyGroup) {
        val groupId = group.id.toIntOrNull() ?: return
        val isFirstDefaultGroup = defaultGroupId == null
        val changesExistingDefaultGroup = changesDefaultGroup && defaultGroupId != null && defaultGroupId != groupId

        if (isFirstDefaultGroup) {
            pendingGroup = group
            pendingWarning = GroupSelectionWarning.InitialDefaultGroup
            return
        }
        if (changesExistingDefaultGroup) {
            pendingGroup = group
            pendingWarning = GroupSelectionWarning.ChangeDefaultGroup
            return
        }

        applyGroupSelection(group)
    }

    val warning = pendingWarning
    if (warning != null) {
        AlertDialog(
            onDismissRequest = {
                pendingGroup = null
                pendingWarning = null
            },
            title = {
                Text(
                    if (warning == GroupSelectionWarning.InitialDefaultGroup) {
                        "Группа по умолчанию"
                    } else {
                        "Смена группы по умолчанию"
                    }
                )
            },
            text = {
                Text(
                    if (warning == GroupSelectionWarning.InitialDefaultGroup) {
                        "Эта группа будет привязана к аккаунту. По ней будут показываться домашка и участники. Позже сменить её можно будет только через заявку модератору."
                    } else {
                        "Группа не поменяется сразу. Мы создадим заявку для модератора, и после одобрения к новой группе будут привязаны домашка и участники."
                    }
                )
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

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = if (changesDefaultGroup) "Группа по умолчанию" else "Выбор группы",
                navigationIcon = if (onBack != null) {
                    { ActionCapsule(icon = Icons.Default.ArrowBack, onClick = onBack) }
                } else null
            )
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 104.dp)
                ) {
                    if (selectionMessage != null || isSelectingGroup) {
                        item {
                            Text(
                                text = selectionMessage ?: "Обновляем группу",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                            )
                        }
                    }
                    items(institutes) { institute ->
                        InstituteItem(institute, enabled = !isSelectingGroup) { group ->
                            requestGroupSelection(group)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun InstituteItem(institute: Institute, enabled: Boolean = true, onGroupClick: (MyGroup) -> Unit) {
    var expanded by remember { mutableStateOf(false) }

    Column {
        ListItem(
            headlineContent = { Text(institute.name) },
            trailingContent = {
                Icon(
                    if (expanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
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
                        .clickable(enabled = enabled) { onGroupClick(group) }
                )
            }
        }
    }
}
