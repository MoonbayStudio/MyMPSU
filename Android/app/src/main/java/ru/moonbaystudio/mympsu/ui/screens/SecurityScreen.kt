package ru.moonbaystudio.mympsu.ui.screens

import android.content.Context
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import androidx.hilt.navigation.compose.hiltViewModel
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.ui.components.ActionCapsule
import ru.moonbaystudio.mympsu.ui.components.CapsuleHeader
import ru.moonbaystudio.mympsu.ui.viewmodel.AuthViewModel
import ru.moonbaystudio.mympsu.util.Constants
import ru.moonbaystudio.mympsu.util.findActivity
import ru.moonbaystudio.mympsu.util.performAppleSignIn

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SecurityScreen(
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel()
) {
    val currentUser by viewModel.currentUser.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            CapsuleHeader(
                title = "Безопасность",
                navigationIcon = {
                    ActionCapsule(icon = Icons.AutoMirrored.Filled.ArrowBack, onClick = onBack)
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 104.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            item {
                Text("Учетная запись", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(bottom = 8.dp))
                SecurityItem(icon = Icons.Default.Email, title = "Электронная почта", onClick = { onNavigate("email_change") })
                SecurityItem(icon = Icons.Default.Lock, title = "Пароль", onClick = { onNavigate("password_setup") })
            }

            item {
                Spacer(modifier = Modifier.height(16.dp))
                Text("Привязки", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(bottom = 8.dp))
                
                // Apple Link
                val isAppleLinked = currentUser?.linkedProviders?.contains("apple") == true
                ListItem(
                    headlineContent = { Text("Apple ID") },
                    leadingContent = { Icon(Icons.Default.AccountCircle, contentDescription = null, tint = if (isAppleLinked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant) },
                    supportingContent = { Text(if (isAppleLinked) "Привязан" else "Не привязан") },
                    trailingContent = {
                        if (!isAppleLinked) {
                            TextButton(onClick = { performAppleSignIn(context) }) { Text("Привязать") }
                        }
                    }
                )

                // Google Link
                val isGoogleLinked = currentUser?.linkedProviders?.contains("google") == true
                ListItem(
                    headlineContent = { Text("Google") },
                    leadingContent = { Icon(Icons.Default.AccountCircle, contentDescription = null, tint = if (isGoogleLinked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant) },
                    supportingContent = { Text(if (isGoogleLinked) "Привязан" else "Не привязан") },
                    trailingContent = {
                        if (!isGoogleLinked) {
                            TextButton(onClick = {
                                scope.launch {
                                    handleGoogleLink(context, viewModel)
                                }
                            }) { Text("Привязать") }
                        }
                    }
                )
            }

            item {
                Spacer(modifier = Modifier.height(16.dp))
                Text("Сеансы", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(bottom = 8.dp))
                SecurityItem(icon = Icons.Default.Build, title = "Активные устройства", onClick = { onNavigate("sessions") })
            }
        }
    }
}

private suspend fun handleGoogleLink(context: Context, viewModel: AuthViewModel) {
    val activity = context.findActivity() ?: return
    val credentialManager = CredentialManager.create(activity)
    val googleIdOption = GetSignInWithGoogleOption.Builder(Constants.GOOGLE_WEB_CLIENT_ID)
        .build()

    val request = GetCredentialRequest.Builder()
        .addCredentialOption(googleIdOption)
        .build()

    try {
        val result = credentialManager.getCredential(activity, request)
        val credential = result.credential
        if (credential is GoogleIdTokenCredential) {
            viewModel.linkGoogle(credential.idToken)
        }
    } catch (e: GetCredentialException) {
        android.util.Log.e("SecurityScreen", "Google link failed: ${e.message}", e)
    }
}

@Composable
fun SecurityItem(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(title) },
        leadingContent = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
        trailingContent = { Icon(Icons.Default.KeyboardArrowRight, contentDescription = null) },
        modifier = Modifier.clickable(onClick = onClick)
    )
}
