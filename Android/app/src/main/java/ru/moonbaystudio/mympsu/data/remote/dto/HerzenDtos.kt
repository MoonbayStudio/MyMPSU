package ru.moonbaystudio.mympsu.data.remote.dto

import com.google.gson.annotations.SerializedName

data class FacultyDto(
    val id: Int,
    val name: String
)

data class GroupDto(
    val id: Int,
    val name: String,
    @SerializedName("faculty_id") val facultyId: Int
)

data class ScheduleResponseDto(
    val name: String,
    val type: String,
    @SerializedName("start_time") val startTime: String,
    @SerializedName("end_time") val endTime: String,
    @SerializedName("teacher_id") val teacherId: Int?,
    @SerializedName("room_id") val roomId: Int?,
    @SerializedName("sub_group_id") val subGroupId: Int?,
    @SerializedName("class_url") val classUrl: String?
)

data class TeacherDto(
    val id: Int,
    val name: String
)

data class RoomDto(
    val id: Int,
    val name: String,
    @SerializedName("building_id") val buildingId: Int?
)

data class BuildingDto(
    val id: Int,
    val name: String
)
