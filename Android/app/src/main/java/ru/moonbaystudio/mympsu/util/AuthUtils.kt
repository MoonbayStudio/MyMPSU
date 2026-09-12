package ru.moonbaystudio.mympsu.util

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import androidx.credentials.exceptions.GetCredentialException
import ru.moonbaystudio.mympsu.ui.viewmodel.AuthViewModel

suspend fun performGoogleSignIn(context: Context, viewModel: AuthViewModel) {
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
            viewModel.googleLogin(credential.idToken)
        }
    } catch (e: GetCredentialException) {
        android.util.Log.e("AuthUtils", "Google Sign-In failed: ${e.message}")
    }
}

fun performAppleSignIn(context: Context) {
    val authUrl = Uri.parse("https://appleid.apple.com/auth/authorize")
        .buildUpon()
        .appendQueryParameter("client_id", Constants.APPLE_SERVICE_ID)
        .appendQueryParameter("redirect_uri", Constants.APPLE_REDIRECT_URL)
        .appendQueryParameter("response_type", "code id_token")
        .appendQueryParameter("scope", "name email")
        .appendQueryParameter("response_mode", "form_post")
        .build()

    val customTabsIntent = CustomTabsIntent.Builder().build()
    customTabsIntent.launchUrl(context, authUrl)
}

fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
