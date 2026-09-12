package ru.moonbaystudio.mympsu.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "schedule_items")
data class LocalScheduleItem(
    @PrimaryKey val id: String,
    val groupId: Int,
    val date: String, // yyyy-MM-dd for indexing
    val sortDateIso: String?,
    val endDateIso: String?,
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
