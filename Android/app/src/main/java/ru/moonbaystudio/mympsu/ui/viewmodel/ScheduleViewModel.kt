package ru.moonbaystudio.mympsu.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import ru.moonbaystudio.mympsu.data.model.ScheduleItem
import ru.moonbaystudio.mympsu.data.remote.dto.Homework
import ru.moonbaystudio.mympsu.data.repository.AuthRepository
import ru.moonbaystudio.mympsu.data.repository.ScheduleRepository
import ru.moonbaystudio.mympsu.data.repository.SettingsRepository
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import javax.inject.Inject

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
@HiltViewModel
class ScheduleViewModel @Inject constructor(
    private val repository: ScheduleRepository,
    private val authRepository: AuthRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    sealed class RefreshStatus {
        object Success : RefreshStatus()
        data class Error(val message: String) : RefreshStatus()
    }

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _refreshStatus = MutableStateFlow<RefreshStatus?>(null)
    val refreshStatus: StateFlow<RefreshStatus?> = _refreshStatus.asStateFlow()

    private val _showLastDayWarning = MutableStateFlow(false)
    val showLastDayWarning: StateFlow<Boolean> = _showLastDayWarning.asStateFlow()

    private val _isOffline = MutableStateFlow(false)
    val isOffline: StateFlow<Boolean> = _isOffline.asStateFlow()

    private val _groupId = MutableStateFlow<Int?>(null)
    val selectedGroupId: StateFlow<Int?> = _groupId.asStateFlow()
    private val _selectedDate = MutableStateFlow(Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.time)
    val selectedDate: StateFlow<Date> = _selectedDate.asStateFlow()
    private val _examOnly = MutableStateFlow(false)

    private val _homeworks = MutableStateFlow<Map<String, Homework>>(emptyMap())
    val homeworks: StateFlow<Map<String, Homework>> = _homeworks.asStateFlow()

    private val requestDateFormatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    val currentUser = authRepository.currentUser
    val defaultGroupId = settingsRepository.selectedGroupId

    val scheduleItems: StateFlow<List<ScheduleItem>> = combine(
        _groupId,
        _selectedDate,
        _examOnly
    ) { id, date, exam ->
        DataState(id, date, exam)
    }.flatMapLatest { state ->
        if (state.id != null) {
            repository.getScheduleFlow(state.id, state.date, state.examOnly)
                .map { local ->
                    local
                }
                .scan(emptyList<ScheduleItem>()) { previous, next ->
                    // If next is empty but we are loading OR we had data and Room hasn't emitted yet, keep previous
                    if (next.isEmpty() && (_isLoading.value || previous.isNotEmpty())) previous else next
                }
        } else {
            flowOf(emptyList())
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(30000), emptyList())

    data class DataState(
        val id: Int?,
        val date: Date,
        val examOnly: Boolean
    )

    fun loadSchedule(groupId: Int, examOnly: Boolean = false) {
        if (_groupId.value == groupId && _examOnly.value == examOnly) {
            return
        }
        _groupId.value = groupId
        _examOnly.value = examOnly
        checkCacheAndLoad()
    }

    fun setDate(date: Date) {
        val normalizedDate = Calendar.getInstance().apply {
            time = date
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time

        if (_selectedDate.value == normalizedDate) return

        _selectedDate.value = normalizedDate
        // Clear warning and offline status on date change
        _showLastDayWarning.value = false
        _isOffline.value = false
        checkCacheAndLoad()
    }

    fun manualRefresh() {
        val groupId = _groupId.value ?: return
        val date = _selectedDate.value
        val examOnly = _examOnly.value

        viewModelScope.launch {
            _isLoading.value = true
            try {
                // Ensure we are in "loading" state for scan operator
                kotlinx.coroutines.delay(50)
                val offlineScheduleEnabled = settingsRepository.offlineScheduleEnabled.first()
                val cacheWeeks = settingsRepository.scheduleCacheWeeks.first().coerceIn(1, 4)
                val maxCached = if (!examOnly && offlineScheduleEnabled) repository.getMaxCachedDate(groupId) else null
                val extendsCachedWindow = maxCached != null &&
                    requestDateFormatter.format(maxCached) == requestDateFormatter.format(date)

                repository.refreshScheduleRange(groupId, date, date, examOnly)
                if (extendsCachedWindow) {
                    loadCacheRange(groupId, date, cacheWeeks)
                }

                if (!examOnly) {
                    loadHomeworksForVisibleSchedule(date)
                }
                _refreshStatus.value = RefreshStatus.Success
                _isOffline.value = false
            } catch (e: Exception) {
                val errorMsg = when {
                    e is retrofit2.HttpException && e.code() == 400 -> "Ошибка 400: Неверный запрос к API"
                    e is java.net.UnknownHostException -> "Нет интернета"
                    e is java.net.ConnectException -> "Сервер недоступен"
                    else -> e.message ?: "Ошибка обновления"
                }
                _refreshStatus.value = RefreshStatus.Error(errorMsg)
            } finally {
                _isLoading.value = false
                kotlinx.coroutines.delay(2000)
                _refreshStatus.value = null
            }
        }
    }

    private fun checkCacheAndLoad() {
        val groupId = _groupId.value ?: return
        val date = _selectedDate.value
        val examOnly = _examOnly.value

        viewModelScope.launch {
            try {
                val offlineScheduleEnabled = settingsRepository.offlineScheduleEnabled.first()
                val cacheWeeks = if (offlineScheduleEnabled) {
                    settingsRepository.scheduleCacheWeeks.first().coerceIn(1, 4)
                } else {
                    0
                }

                if (examOnly) {
                    val hasSession = repository.hasSession(groupId)
                    if (!hasSession) {
                        try {
                            repository.refreshSchedule(groupId, date, true)
                            _isOffline.value = false
                        } catch (e: Exception) {
                            _isOffline.value = true
                        }
                    }
                } else {
                    val hasData = repository.hasDataForDate(groupId, date)
                    val maxCached = repository.getMaxCachedDate(groupId)

                    if (!offlineScheduleEnabled) {
                        _isLoading.value = true
                        try {
                            repository.refreshScheduleRange(groupId, date, date, false)
                            _isOffline.value = false
                        } catch (e: Exception) {
                            _isOffline.value = true
                            _refreshStatus.value = RefreshStatus.Error("Ошибка загрузки")
                        } finally {
                            _isLoading.value = false
                        }
                    } else if (!hasData) {
                        val today = Calendar.getInstance().apply {
                            set(Calendar.HOUR_OF_DAY, 0)
                            set(Calendar.MINUTE, 0)
                            set(Calendar.SECOND, 0)
                            set(Calendar.MILLISECOND, 0)
                        }.time

                        val (rangeStart, rangeEnd) = offlineCacheWindow(today, cacheWeeks)

                        if (date.before(rangeStart) || date.after(rangeEnd)) {
                            _isLoading.value = true
                            try {
                                repository.refreshScheduleRange(groupId, date, date, false)
                                _isOffline.value = false
                            } catch (e: Exception) {
                                _isOffline.value = true
                                _refreshStatus.value = RefreshStatus.Error("Ошибка загрузки")
                            } finally {
                                _isLoading.value = false
                            }
                        } else {
                            try {
                                loadCacheRange(groupId, today, cacheWeeks)
                                _isOffline.value = false
                            } catch (e: Exception) {
                                _isOffline.value = true
                            }
                        }
                    }

                    if (offlineScheduleEnabled && maxCached != null) {
                        val maxDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(maxCached)
                        val currentDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(date)

                        if (maxDateStr == currentDateStr) {
                            try {
                                // Load next weeks BEFORE deleting old ones to avoid gap
                                loadCacheRange(groupId, date, cacheWeeks)

                                val oneWeekAgo = Calendar.getInstance().apply {
                                    add(Calendar.WEEK_OF_YEAR, -1)
                                }
                                repository.deleteScheduleBefore(groupId, SimpleDateFormat("yyyy-MM-dd", Locale.US).format(oneWeekAgo.time))
                                _isOffline.value = false
                            } catch (e: Exception) {
                                _showLastDayWarning.value = true
                            }
                        }
                    }

                    try {
                        loadHomeworksForVisibleSchedule(date)
                    } catch (e: Exception) {}
                }
            } catch (e: Exception) {
                _refreshStatus.value = RefreshStatus.Error("Ошибка: ${e.message}")
            }
        }
    }

    private suspend fun loadCacheRange(groupId: Int, startDate: Date, weeks: Int) {
        try {
            _isLoading.value = true
            val cal = Calendar.getInstance()
            val normalizedWeeks = weeks.coerceIn(1, 4)
            cal.time = startDate
            cal.add(Calendar.DAY_OF_YEAR, -7)
            val rangeStart = cal.time
            cal.time = startDate
            cal.add(Calendar.DAY_OF_YEAR, normalizedWeeks * 7 - 1)
            val rangeEnd = cal.time

            repository.refreshScheduleRange(groupId, rangeStart, rangeEnd, false)
            repository.refreshSchedule(groupId, startDate, true)
            _isOffline.value = false
        } catch (e: Exception) {
            _isOffline.value = true
            throw e
        } finally {
            _isLoading.value = false
        }
    }

    private fun offlineCacheWindow(anchorDate: Date, weeks: Int): Pair<Date, Date> {
        val normalizedWeeks = weeks.coerceIn(1, 4)
        val calendar = Calendar.getInstance()
        calendar.time = anchorDate
        calendar.add(Calendar.DAY_OF_YEAR, -7)
        val rangeStart = calendar.time
        calendar.time = anchorDate
        calendar.add(Calendar.DAY_OF_YEAR, normalizedWeeks * 7 - 1)
        return rangeStart to calendar.time
    }

    fun dismissWarning() {
        _showLastDayWarning.value = false
    }

    private fun refresh() {
        val groupId = _groupId.value ?: return
        val date = _selectedDate.value
        val examOnly = _examOnly.value
        viewModelScope.launch {
            _isLoading.value = true
            try {
                repository.refreshSchedule(groupId, date, examOnly)
                if (!examOnly) {
                    loadHomeworksForVisibleSchedule(date)
                } else {
                    _homeworks.value = emptyMap()
                }
            } catch (e: Exception) {
            } finally {
                _isLoading.value = false
            }
        }
    }

    private fun homeworkKey(date: String, time: String, subject: String): String {
        return "$date|$time|$subject"
    }

    fun getHomeworkForKey(date: String, time: String, subject: String): Homework? {
        return _homeworks.value[homeworkKey(date, time, subject)]
    }

    fun saveHomework(lesson: ScheduleItem, text: String) {
        _groupId.value ?: return
        val dateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(_selectedDate.value)
        val existing = _homeworks.value[homeworkKey(dateStr, lesson.time, lesson.title)]

        viewModelScope.launch {
            _isLoading.value = true
            val homeworkGroupId = homeworkGroupIdForVisibleSchedule() ?: run {
                _isLoading.value = false
                return@launch
            }
            val result = if (existing != null) {
                repository.updateHomework(homeworkGroupId, existing.id, text)
            } else {
                repository.createHomework(
                    groupId = homeworkGroupId,
                    lessonDate = dateStr,
                    lessonTime = lesson.time,
                    subject = lesson.title,
                    teacher = lesson.teacher.ifBlank { null },
                    room = lesson.room.ifBlank { null },
                    text = text
                )
            }
            if (result.isSuccess) {
                refresh()
            }
            _isLoading.value = false
        }
    }

    fun deleteHomework(homeworkId: String) {
        _groupId.value ?: return
        viewModelScope.launch {
            _isLoading.value = true
            val homeworkGroupId = homeworkGroupIdForVisibleSchedule() ?: run {
                _isLoading.value = false
                return@launch
            }
            if (repository.deleteHomework(homeworkGroupId, homeworkId).isSuccess) {
                refresh()
            }
            _isLoading.value = false
        }
    }

    private suspend fun loadHomeworksForVisibleSchedule(date: Date) {
        val homeworkGroupId = homeworkGroupIdForVisibleSchedule()
        if (homeworkGroupId == null) {
            _homeworks.value = emptyMap()
            return
        }

        val homeworkList = repository.getHomeworks(homeworkGroupId, date)
        _homeworks.value = homeworkList.associateBy { homeworkKey(it.lessonDate, it.lessonTime, it.subject) }
    }

    private suspend fun homeworkGroupIdForVisibleSchedule(): Int? {
        val scheduleGroupId = _groupId.value ?: return null
        if (!authRepository.isLoggedIn.first()) return null
        val defaultGroupId = settingsRepository.selectedGroupId.first() ?: return null
        return defaultGroupId.takeIf { it == scheduleGroupId }
    }
}
