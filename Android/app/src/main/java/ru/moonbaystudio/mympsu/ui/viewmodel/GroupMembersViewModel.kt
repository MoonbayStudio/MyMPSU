package ru.moonbaystudio.mympsu.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.data.remote.dto.GroupUserDto
import ru.moonbaystudio.mympsu.data.repository.AuthRepository
import javax.inject.Inject

@HiltViewModel
class GroupMembersViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val userPreferences: UserPreferences
) : ViewModel() {
    private val _users = MutableStateFlow<List<GroupUserDto>>(emptyList())
    val users: StateFlow<List<GroupUserDto>> = _users.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    val selectedGroupId = userPreferences.selectedGroupId

    fun loadUsers() {
        viewModelScope.launch {
            val groupId = userPreferences.selectedGroupId.first()
            if (groupId != null) {
                _isLoading.value = true
                authRepository.syncLocalSelectedGroup()
                _users.value = authRepository.getGroupUsers(groupId)
                _isLoading.value = false
            } else {
                _users.value = emptyList()
            }
        }
    }

    fun loadUsers(groupId: Int) {
        viewModelScope.launch {
            _isLoading.value = true
            authRepository.syncLocalSelectedGroup()
            _users.value = authRepository.getGroupUsers(groupId)
            _isLoading.value = false
        }
    }
}
