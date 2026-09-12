package ru.moonbaystudio.mympsu.service

import ru.moonbaystudio.mympsu.data.model.ScheduleItem
import ru.moonbaystudio.mympsu.data.repository.ScheduleRepository
import java.text.SimpleDateFormat
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ScheduleLiveStateManager @Inject constructor(
    private val repository: ScheduleRepository
) {
    private val isoFormatters = listOf(
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US),
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US),
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        },
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        },
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
    )

    suspend fun getCurrentState(groupId: Int): ScheduleLiveState {
        val now = Date()
        val calendar = Calendar.getInstance()
        calendar.time = now
        
        // We only care about lessons for today
        val lessons = repository.getScheduleSync(groupId, now)
        
        if (lessons.isEmpty()) {
            val hasData = repository.hasDataForDate(groupId, now)
            return if (hasData) ScheduleLiveState.NoLessons else ScheduleLiveState.NoCache
        }

        // Sort by start time just in case
        val sortedLessons = lessons.sortedBy { it.sortDateIso }

        for (i in sortedLessons.indices) {
            val lesson = sortedLessons[i]
            val startTime = parseIsoDate(lesson.sortDateIso) ?: continue
            val endTime = parseIsoDate(lesson.endDateIso) ?: continue

            if (now.before(startTime)) {
                // If it's before the first lesson or between lessons (break)
                return if (i == 0) {
                    ScheduleLiveState.BeforeLessons(lesson)
                } else {
                    ScheduleLiveState.Break(lesson)
                }
            } else if (now.after(startTime) && now.before(endTime)) {
                // Currently in lesson
                val progress = (now.time - startTime.time).toFloat() / (endTime.time - startTime.time).toFloat()
                val nextLesson = if (i + 1 < sortedLessons.size) sortedLessons[i + 1] else null
                return ScheduleLiveState.Lesson(lesson, nextLesson, progress)
            }
        }

        return ScheduleLiveState.AfterLessons
    }

    private fun parseIsoDate(value: String): Date? {
        for (formatter in isoFormatters) {
            try {
                return formatter.parse(value)
            } catch (_: Exception) {
            }
        }
        return null
    }
}
