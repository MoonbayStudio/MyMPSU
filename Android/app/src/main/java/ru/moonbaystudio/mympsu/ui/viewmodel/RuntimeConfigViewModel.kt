package ru.moonbaystudio.mympsu.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.repository.RuntimeConfigRepository
import javax.inject.Inject

@HiltViewModel
class RuntimeConfigViewModel @Inject constructor(
    private val repository: RuntimeConfigRepository
) : ViewModel() {
    val state = repository.state

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            repository.refresh()
        }
    }

    fun dismissNotice(id: Int) {
        viewModelScope.launch {
            repository.dismissNotice(id)
        }
    }
}
