package ru.moonbaystudio.mympsu.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.model.Institute
import ru.moonbaystudio.mympsu.data.repository.GroupSelectionResult
import ru.moonbaystudio.mympsu.data.repository.ScheduleRepository
import ru.moonbaystudio.mympsu.data.repository.SettingsRepository
import javax.inject.Inject

@HiltViewModel
class GroupSelectionViewModel @Inject constructor(
    private val scheduleRepository: ScheduleRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _institutes = MutableStateFlow<List<Institute>>(emptyList())
    val institutes: StateFlow<List<Institute>> = _institutes.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _selectionMessage = MutableStateFlow<String?>(null)
    val selectionMessage: StateFlow<String?> = _selectionMessage.asStateFlow()

    private val _isSelectingGroup = MutableStateFlow(false)
    val isSelectingGroup: StateFlow<Boolean> = _isSelectingGroup.asStateFlow()

    val selectedGroupId = settingsRepository.selectedGroupId

    init {
        loadInstitutes()
    }

    private fun loadInstitutes() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _institutes.value = scheduleRepository.getInstitutesWithGroups()
            } catch (e: Exception) {
                // Handle error
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun selectGroup(groupId: Int, groupName: String, onApplied: () -> Unit = {}) {
        viewModelScope.launch {
            _isSelectingGroup.value = true
            _selectionMessage.value = null
            when (val result = settingsRepository.selectScheduleGroup(groupId, groupName)) {
                GroupSelectionResult.Applied -> {
                    _selectionMessage.value = null
                    onApplied()
                }
                GroupSelectionResult.ChangeRequestCreated -> {
                    _selectionMessage.value = "Заявка на смену группы отправлена модератору."
                }
                is GroupSelectionResult.Error -> {
                    _selectionMessage.value = result.message
                }
            }
            _isSelectingGroup.value = false
        }
    }

    fun selectDefaultGroup(groupId: Int, groupName: String, onApplied: () -> Unit = {}) {
        viewModelScope.launch {
            _isSelectingGroup.value = true
            _selectionMessage.value = null
            when (val result = settingsRepository.saveSelectedGroup(groupId, groupName)) {
                GroupSelectionResult.Applied -> {
                    _selectionMessage.value = null
                    onApplied()
                }
                GroupSelectionResult.ChangeRequestCreated -> {
                    _selectionMessage.value = "Заявка на смену группы по умолчанию отправлена модератору."
                }
                is GroupSelectionResult.Error -> {
                    _selectionMessage.value = result.message
                }
            }
            _isSelectingGroup.value = false
        }
    }
}
