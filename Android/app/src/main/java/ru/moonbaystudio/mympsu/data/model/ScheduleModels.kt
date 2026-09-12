package ru.moonbaystudio.mympsu.data.model

data class Institute(
    val id: String,
    val name: String,
    val groups: List<MyGroup>
)

data class MyGroup(
    val id: String,
    val name: String
)

data class ScheduleItem(
    val id: String,
    val sortDateIso: String,
    val endDateIso: String,
    val time: String,
    val title: String,
    val teacher: String,
    val lessonType: String,
    val address: String,
    val subgroup: String?,
    val period: String,
    val room: String,
    val classUrl: String?
)
