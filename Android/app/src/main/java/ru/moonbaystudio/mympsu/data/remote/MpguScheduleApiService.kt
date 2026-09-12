package ru.moonbaystudio.mympsu.data.remote

import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.Query
import ru.moonbaystudio.mympsu.data.remote.dto.*

interface MpguScheduleApiService {
    @GET("faculties")
    suspend fun getFaculties(): Response<List<FacultyDto>>

    @GET("groups")
    suspend fun getGroups(): Response<List<GroupDto>>

    @GET("schedule")
    suspend fun getSchedule(
        @Query("group_id") groupId: Int,
        @Query("start_date") dateStart: String,
        @Query("end_date") dateEnd: String,
        @Query("exam_only") exam: Boolean
    ): Response<List<ScheduleResponseDto>>

    @GET("teachers")
    suspend fun getTeachers(@Query("teacher_ids") ids: String): Response<List<TeacherDto>>

    @GET("rooms")
    suspend fun getRooms(@Query("room_ids") ids: String): Response<List<RoomDto>>

    @GET("buildings")
    suspend fun getBuildings(@Query("building_ids") ids: String): Response<List<BuildingDto>>
}
