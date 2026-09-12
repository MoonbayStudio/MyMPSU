package ru.moonbaystudio.mympsu.service

import ru.moonbaystudio.mympsu.data.model.ScheduleItem

sealed class ScheduleLiveState {
    object NoCache : ScheduleLiveState()
    object NoLessons : ScheduleLiveState()
    data class BeforeLessons(val nextLesson: ScheduleItem) : ScheduleLiveState()
    data class Lesson(val currentLesson: ScheduleItem, val nextLesson: ScheduleItem?, val progress: Float) : ScheduleLiveState()
    data class Break(val nextLesson: ScheduleItem) : ScheduleLiveState()
    object AfterLessons : ScheduleLiveState()
}
