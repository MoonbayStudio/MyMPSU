package ru.moonbaystudio.mympsu.di

import android.content.Context
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import ru.moonbaystudio.mympsu.data.local.AppDatabase
import ru.moonbaystudio.mympsu.data.local.dao.ScheduleDao
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    private val MIGRATION_1_2 = object : Migration(1, 2) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS `schedule_cache_days` (
                    `groupId` INTEGER NOT NULL,
                    `date` TEXT NOT NULL,
                    `examOnly` INTEGER NOT NULL,
                    PRIMARY KEY(`groupId`, `date`, `examOnly`)
                )
                """.trimIndent()
            )
        }
    }

    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            "mympsu_db"
        ).addMigrations(MIGRATION_1_2).build()
    }

    @Provides
    fun provideScheduleDao(database: AppDatabase): ScheduleDao {
        return database.scheduleDao()
    }
}
