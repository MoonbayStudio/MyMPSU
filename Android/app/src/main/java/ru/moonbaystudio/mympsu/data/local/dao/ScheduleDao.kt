package ru.moonbaystudio.mympsu.data.local.dao

import androidx.room.*
import kotlinx.coroutines.flow.Flow
import ru.moonbaystudio.mympsu.data.local.entity.LocalScheduleCacheDay
import ru.moonbaystudio.mympsu.data.local.entity.LocalScheduleItem

@Dao
interface ScheduleDao {
    @Query("SELECT * FROM schedule_items WHERE groupId = :groupId AND date = :date AND period = ''")
    fun getSchedule(groupId: Int, date: String): Flow<List<LocalScheduleItem>>

    @Query("SELECT * FROM schedule_items WHERE groupId = :groupId AND date = :date AND period = '' ORDER BY sortDateIso ASC")
    suspend fun getScheduleSync(groupId: Int, date: String): List<LocalScheduleItem>

    @Query("SELECT * FROM schedule_items WHERE groupId = :groupId AND period != ''")
    fun getSession(groupId: Int): Flow<List<LocalScheduleItem>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(items: List<LocalScheduleItem>)

    @Query("DELETE FROM schedule_items WHERE groupId = :groupId AND date = :date AND period = ''")
    suspend fun deleteSchedule(groupId: Int, date: String)

    @Query("DELETE FROM schedule_items WHERE groupId = :groupId AND date < :date AND period = ''")
    suspend fun deleteScheduleItemsBefore(groupId: Int, date: String)

    @Query("DELETE FROM schedule_items WHERE groupId = :groupId AND date > :date AND period = ''")
    suspend fun deleteScheduleItemsAfter(groupId: Int, date: String)

    @Query("DELETE FROM schedule_cache_days WHERE groupId = :groupId AND date < :date AND examOnly = 0")
    suspend fun deleteCachedScheduleDaysBefore(groupId: Int, date: String)

    @Query("DELETE FROM schedule_cache_days WHERE groupId = :groupId AND date > :date AND examOnly = 0")
    suspend fun deleteCachedScheduleDaysAfter(groupId: Int, date: String)

    @Query("DELETE FROM schedule_cache_days WHERE groupId = :groupId AND examOnly = 0")
    suspend fun deleteCachedScheduleDays(groupId: Int)

    @Query("""
        SELECT MAX(date) FROM (
            SELECT date FROM schedule_items WHERE groupId = :groupId AND period = ''
            UNION
            SELECT date FROM schedule_cache_days WHERE groupId = :groupId AND examOnly = 0
        )
    """)
    suspend fun getMaxDate(groupId: Int): String?

    @Query("""
        SELECT MIN(date) FROM (
            SELECT date FROM schedule_items WHERE groupId = :groupId AND period = ''
            UNION
            SELECT date FROM schedule_cache_days WHERE groupId = :groupId AND examOnly = 0
        )
    """)
    suspend fun getMinDate(groupId: Int): String?

    @Query("""
        SELECT EXISTS(SELECT 1 FROM schedule_cache_days WHERE groupId = :groupId AND date = :date AND examOnly = 0)
            OR EXISTS(SELECT 1 FROM schedule_items WHERE groupId = :groupId AND date = :date AND period = '')
    """)
    suspend fun hasDataForDate(groupId: Int, date: String): Boolean

    @Query("SELECT EXISTS(SELECT 1 FROM schedule_items WHERE groupId = :groupId AND period != '')")
    suspend fun hasSession(groupId: Int): Boolean

    @Query("DELETE FROM schedule_items WHERE groupId = :groupId AND period != ''")
    suspend fun deleteSession(groupId: Int)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun markScheduleDayCached(day: LocalScheduleCacheDay)

    @Transaction
    suspend fun deleteScheduleBefore(groupId: Int, date: String) {
        deleteScheduleItemsBefore(groupId, date)
        deleteCachedScheduleDaysBefore(groupId, date)
    }

    @Transaction
    suspend fun deleteScheduleAfter(groupId: Int, date: String) {
        deleteScheduleItemsAfter(groupId, date)
        deleteCachedScheduleDaysAfter(groupId, date)
    }

    @Transaction
    suspend fun deleteScheduleCache(groupId: Int) {
        deleteScheduleItemsBefore(groupId, "9999-99-99")
        deleteCachedScheduleDays(groupId)
    }

    @Transaction
    suspend fun updateSchedule(groupId: Int, date: String, items: List<LocalScheduleItem>) {
        deleteSchedule(groupId, date)
        insertAll(items)
        markScheduleDayCached(LocalScheduleCacheDay(groupId, date, false))
    }

    @Transaction
    suspend fun updateSession(groupId: Int, items: List<LocalScheduleItem>) {
        deleteSession(groupId)
        insertAll(items)
    }
}
