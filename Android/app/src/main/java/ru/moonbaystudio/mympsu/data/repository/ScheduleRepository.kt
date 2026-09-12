package ru.moonbaystudio.mympsu.data.repository

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import ru.moonbaystudio.mympsu.data.local.dao.ScheduleDao
import ru.moonbaystudio.mympsu.data.local.entity.LocalScheduleItem
import ru.moonbaystudio.mympsu.data.model.Institute
import ru.moonbaystudio.mympsu.data.model.MyGroup
import ru.moonbaystudio.mympsu.data.model.ScheduleItem
import ru.moonbaystudio.mympsu.data.remote.MpguScheduleApiService
import ru.moonbaystudio.mympsu.data.remote.MyMPSUApiService
import ru.moonbaystudio.mympsu.data.remote.dto.*
import ru.moonbaystudio.mympsu.util.*
import java.text.SimpleDateFormat
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ScheduleRepository @Inject constructor(
    private val apiService: MpguScheduleApiService,
    private val myMPSUApiService: MyMPSUApiService,
    private val scheduleDao: ScheduleDao
) {
    private val requestDateFormatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    fun getScheduleFlow(groupId: Int, date: java.util.Date, examOnly: Boolean): Flow<List<ScheduleItem>> {
        val dateStr = requestDateFormatter.format(date)
        val flow = if (examOnly) {
            scheduleDao.getSession(groupId)
        } else {
            scheduleDao.getSchedule(groupId, dateStr)
        }
        return flow.map { localItems ->
            localItems.map { it.toDomain() }
        }
    }

    suspend fun getScheduleSync(groupId: Int, date: java.util.Date): List<ScheduleItem> {
        val dateStr = requestDateFormatter.format(date)
        return scheduleDao.getScheduleSync(groupId, dateStr).map { it.toDomain() }
    }

    suspend fun getHomeworks(groupId: Int, date: java.util.Date): List<Homework> {
        val dateStr = requestDateFormatter.format(date)
        return safeApiCall { myMPSUApiService.getGroupHomeworks(groupId, dateStr) }
            .getOrElse { emptyList() }
    }

    suspend fun createHomework(
        groupId: Int,
        lessonDate: String,
        lessonTime: String,
        subject: String,
        teacher: String?,
        room: String?,
        text: String
    ): Result<Homework> {
        val request = HomeworkMutationRequest(
            lessonDate = lessonDate,
            lessonTime = lessonTime,
            subject = subject,
            teacher = teacher,
            room = room,
            text = text
        )
        return safeApiCall { myMPSUApiService.createHomework(groupId, request) }.toResult()
    }

    suspend fun updateHomework(
        groupId: Int,
        homeworkId: String,
        text: String
    ): Result<Homework> {
        val request = HomeworkUpdateRequest(text)
        return safeApiCall { myMPSUApiService.updateHomework(groupId, homeworkId, request) }.toResult()
    }

    suspend fun deleteHomework(groupId: Int, homeworkId: String): Result<Unit> {
        return safeApiCall { myMPSUApiService.deleteHomework(groupId, homeworkId) }.toResult().map { Unit }
    }

    suspend fun refreshSchedule(groupId: Int, date: java.util.Date, examOnly: Boolean) {
        if (examOnly) {
            val calendar = java.util.Calendar.getInstance()
            calendar.time = date
            calendar.add(java.util.Calendar.DAY_OF_YEAR, -120)
            val startDate = calendar.time
            calendar.time = date
            calendar.add(java.util.Calendar.DAY_OF_YEAR, 120)
            val endDate = calendar.time
            refreshScheduleRange(groupId, startDate, endDate, true)
        } else {
            refreshScheduleRange(groupId, date, date, false)
        }
    }

    suspend fun fetchSchedule(groupId: Int, date: java.util.Date, examOnly: Boolean): List<ScheduleItem> {
        val dateStr = requestDateFormatter.format(date)
        return safeApiCall { apiService.getSchedule(groupId, dateStr, dateStr, examOnly) }
            .getOrElse { emptyList() }
            .let { lessonsToDomain(groupId, it, examOnly) }
            .map { it.toDomain() }
    }

    private suspend fun lessonsToDomain(groupId: Int, lessons: List<ScheduleResponseDto>, examOnly: Boolean): List<LocalScheduleItem> {
        if (lessons.isEmpty()) return emptyList()

        val teacherIds = lessons.mapNotNull { it.teacherId }.distinct().joinToString(",")
        val roomIds = lessons.mapNotNull { it.roomId }.distinct().joinToString(",")

        val teachers = if (teacherIds.isNotEmpty()) {
            safeApiCall { apiService.getTeachers(teacherIds) }.getOrElse { emptyList() }.associateBy { it.id }
        } else emptyMap()

        val rooms = if (roomIds.isNotEmpty()) {
            safeApiCall { apiService.getRooms(roomIds) }.getOrElse { emptyList() }.associateBy { it.id }
        } else emptyMap()

        val buildingIds = rooms.values.mapNotNull { it.buildingId }.distinct().joinToString(",")
        val buildings = if (buildingIds.isNotEmpty()) {
            safeApiCall { apiService.getBuildings(buildingIds) }.getOrElse { emptyList() }.associateBy { it.id }
        } else emptyMap()

        return lessons.map { lesson ->
            val teacherName = teachers[lesson.teacherId]?.name ?: ""
            val roomName = rooms[lesson.roomId]?.name ?: ""
            val address = rooms[lesson.roomId]?.buildingId?.let { buildings[it]?.name } ?: ""
            val lessonDate = lesson.startTime.substringBefore("T")

            LocalScheduleItem(
                id = "${lesson.startTime}_${lesson.name}_${teacherName}_${address}_${lesson.type}_${roomName}_${lesson.subGroupId ?: ""}",
                groupId = groupId,
                date = lessonDate,
                sortDateIso = lesson.startTime,
                endDateIso = lesson.endTime,
                time = formatTimeRange(lesson.startTime, lesson.endTime),
                title = lesson.name,
                teacher = teacherName,
                lessonType = lesson.type,
                address = address,
                subgroup = lesson.subGroupId?.toString(),
                period = if (examOnly) lessonDate else "",
                room = roomName,
                classUrl = lesson.classUrl
            )
        }
    }

    suspend fun refreshScheduleRange(groupId: Int, startDate: java.util.Date, endDate: java.util.Date, examOnly: Boolean) {
        val startDateStr = requestDateFormatter.format(startDate)
        val endDateStr = requestDateFormatter.format(endDate)

        val lessons = safeApiCall { apiService.getSchedule(groupId, startDateStr, endDateStr, examOnly) }.getOrElse {
            if (it is NetworkResult.Exception) throw it.e
            if (it is NetworkResult.Error) throw Exception("Network error ${it.code}: ${it.message}")
            emptyList()
        }

        // Safety: If lessons is empty, but we are loading a range, maybe MyMPSU schedule API is just flaky?
        // Let's at least not wipe everything if we expected data.
        // However, if it's a success, we should probably follow it.

        val localItems = lessonsToDomain(groupId, lessons, examOnly)

        if (examOnly) {
            if (localItems.isNotEmpty()) {
                scheduleDao.updateSession(groupId, localItems)
            }
        } else {
            val calendar = java.util.Calendar.getInstance()
            calendar.time = startDate
            while (!calendar.time.after(endDate)) {
                val d = requestDateFormatter.format(calendar.time)
                val itemsForDay = localItems.filter { it.date == d }
                scheduleDao.updateSchedule(groupId, d, itemsForDay)
                calendar.add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
        }
    }

    suspend fun clearCacheAfter(groupId: Int, date: java.util.Date) {
        scheduleDao.deleteScheduleAfter(groupId, requestDateFormatter.format(date))
    }

    suspend fun deleteScheduleBefore(groupId: Int, dateStr: String) {
        scheduleDao.deleteScheduleBefore(groupId, dateStr)
    }

    suspend fun clearCache(groupId: Int) {
        scheduleDao.deleteScheduleCache(groupId)
        scheduleDao.deleteSession(groupId)
    }

    suspend fun hasDataForDate(groupId: Int, date: java.util.Date): Boolean {
        return scheduleDao.hasDataForDate(groupId, requestDateFormatter.format(date))
    }

    suspend fun hasSession(groupId: Int): Boolean {
        return scheduleDao.hasSession(groupId)
    }

    suspend fun getMaxCachedDate(groupId: Int): java.util.Date? {
        return scheduleDao.getMaxDate(groupId)?.let { requestDateFormatter.parse(it) }
    }

    suspend fun getMinCachedDate(groupId: Int): java.util.Date? {
        return scheduleDao.getMinDate(groupId)?.let { requestDateFormatter.parse(it) }
    }

    suspend fun getInstitutesWithGroups(): List<Institute> {
        val faculties = safeApiCall { apiService.getFaculties() }.getOrElse { emptyList() }
        val groups = safeApiCall { apiService.getGroups() }.getOrElse { emptyList() }

        val facultyMap = faculties.associateBy { it.id }

        return groups.groupBy { it.facultyId }
            .map { (facultyId, facultyGroups) ->
                val facultyName = facultyMap[facultyId]?.name ?: "Институт $facultyId"
                Institute(
                    id = facultyId.toString(),
                    name = facultyName,
                    groups = facultyGroups.map { MyGroup(it.id.toString(), it.name) }
                        .sortedBy { it.name }
                )
            }
            .sortedBy { it.name }
    }

    private fun formatTimeRange(start: String, end: String): String {
        val startTime = start.substringAfter("T").take(5)
        val endTime = end.substringAfter("T").take(5)
        return "$startTime-$endTime"
    }

    private fun LocalScheduleItem.toDomain(): ScheduleItem {
        return ScheduleItem(
            id = id,
            sortDateIso = sortDateIso ?: "",
            endDateIso = endDateIso ?: "",
            time = time,
            title = title,
            teacher = teacher,
            lessonType = lessonType,
            address = address,
            subgroup = subgroup,
            period = period,
            room = room,
            classUrl = classUrl
        )
    }
}
