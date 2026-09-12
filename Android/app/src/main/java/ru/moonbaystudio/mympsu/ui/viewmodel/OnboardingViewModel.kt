package ru.moonbaystudio.mympsu.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.data.repository.AuthRepository
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val userPreferences: UserPreferences,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _currentStep = MutableStateFlow(0)
    val currentStep: StateFlow<Int> = _currentStep.asStateFlow()

    fun nextStep() {
        _currentStep.value += 1
    }

    fun prevStep() {
        if (_currentStep.value > 0) {
            _currentStep.value -= 1
        }
    }

    fun completeOnboarding() {
        viewModelScope.launch {
            if (authRepository.isLoggedIn.firstOrNull() == true) {
                authRepository.pushLocalSettingsToAccount()
            }
            userPreferences.setOnboardingCompleted(true)
        }
    }
}
