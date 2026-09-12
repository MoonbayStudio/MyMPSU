package ru.moonbaystudio.mympsu.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.viewmodel.AuthViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EmailChangeScreen(
    onBack: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel()
) {
    val currentUser by viewModel.currentUser.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.error.collectAsState()
    val success by viewModel.success.collectAsState()

    var email by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var step by remember { mutableStateOf(1) }

    LaunchedEffect(success) {
        if (success) {
            if (step == 1) {
                step = 2
                viewModel.resetStatus()
            } else {
                onBack()
            }
        }
    }

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Смена Email",
                navigationIcon = {
                    ActionCapsule(icon = Icons.Default.ArrowBack, onClick = onBack)
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (step == 1) {
                Text("Текущий Email: ${currentUser?.email ?: "не указан"}")
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Новый Email") },
                    modifier = Modifier.fillMaxWidth()
                )
                if (error != null) {
                    Text(error!!, color = MaterialTheme.colorScheme.error)
                }
                Button(
                    onClick = { viewModel.requestEmailChange(email) },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = email.isNotBlank() && !isLoading
                ) {
                    if (isLoading) CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    else Text("Отправить код подтверждения")
                }
            } else {
                Text("Код подтверждения отправлен на $email")
                OutlinedTextField(
                    value = code,
                    onValueChange = { code = it },
                    label = { Text("Код") },
                    modifier = Modifier.fillMaxWidth()
                )
                if (error != null) {
                    Text(error!!, color = MaterialTheme.colorScheme.error)
                }
                Button(
                    onClick = { viewModel.confirmEmailChange(code) },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = code.isNotBlank() && !isLoading
                ) {
                    if (isLoading) CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    else Text("Подтвердить")
                }
            }
        }
    }
}
