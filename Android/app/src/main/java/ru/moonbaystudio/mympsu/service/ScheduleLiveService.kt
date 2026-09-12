package ru.moonbaystudio.mympsu.service

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.first
import ru.moonbaystudio.mympsu.MainActivity
import ru.moonbaystudio.mympsu.R
import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.data.model.ScheduleItem
import java.text.SimpleDateFormat
import java.util.*
import javax.inject.Inject

@AndroidEntryPoint
class ScheduleLiveService : Service() {

    @Inject
    lateinit var stateManager: ScheduleLiveStateManager

    @Inject
    lateinit var userPreferences: UserPreferences

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val CHANNEL_ID = "schedule_live_channel"
    private val NOTIFICATION_ID = 1001

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Start foreground immediately to avoid crash
        val initialNotification = buildNotification(ScheduleLiveState.NoCache)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, initialNotification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, initialNotification)
        }

        updateNotification()
        return START_STICKY
    }

    private fun updateNotification() {
        serviceScope.launch {
            val groupId = userPreferences.selectedGroupId.first() ?: run {
                stopSelf()
                return@launch
            }
            val enabled = userPreferences.liveActivityEnabled.first()

            if (!enabled) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    stopForeground(true)
                }
                stopSelf()
                return@launch
            }

            val state = stateManager.getCurrentState(groupId)
            val notification = buildNotification(state)

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)

            // Schedule next update
            scheduleNextUpdate(state)
        }
    }

    private fun buildNotification(state: ScheduleLiveState): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        val cachedLabel = " (кэш)"

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(ru.moonbaystudio.mympsu.R.drawable.ic_notification)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setOnlyAlertOnce(true)

        when (state) {
            is ScheduleLiveState.Lesson -> {
                builder.setContentTitle("Идёт пара: ${state.currentLesson.title}$cachedLabel")
                    .setContentText("${state.currentLesson.time} • ${state.currentLesson.room}")
                    .setProgress(100, (state.progress * 100).toInt(), false)
                state.nextLesson?.let {
                    builder.setSubText("Далее: ${it.title}")
                }
            }
            is ScheduleLiveState.Break -> {
                builder.setContentTitle("Перерыв$cachedLabel")
                    .setContentText("Следующая: ${state.nextLesson.title} в ${state.nextLesson.time}")
            }
            is ScheduleLiveState.BeforeLessons -> {
                builder.setContentTitle("Пары ещё не начались$cachedLabel")
                    .setContentText("Первая пара: ${state.nextLesson.title} в ${state.nextLesson.time}")
            }
            is ScheduleLiveState.AfterLessons -> {
                builder.setContentTitle("Пары закончились")
                    .setContentText("На сегодня всё!")
            }
            is ScheduleLiveState.NoLessons -> {
                builder.setContentTitle("Нет пар")
                    .setContentText("Сегодня выходной")
            }
            is ScheduleLiveState.NoCache -> {
                builder.setContentTitle("Расписание не загружено")
                    .setContentText("Откройте приложение, чтобы обновить кэш")
            }
        }

        return builder.build()
    }

    private fun scheduleNextUpdate(state: ScheduleLiveState) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, ScheduleUpdateReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)

        val now = System.currentTimeMillis()
        var nextUpdateTime: Long = 0

        // If we want smooth progress, we update every minute during a lesson
        // But instructions say "Без запросов каждую минуту" - refers to API.
        // For UI, we can update every minute locally.

        if (state is ScheduleLiveState.Lesson) {
            nextUpdateTime = now + 60000 // 1 minute
        } else {
            // Wait for next transition
            // This is a simplification. A real manager would find the exact next transition time.
            nextUpdateTime = now + 5 * 60000 // 5 minutes
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextUpdateTime, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, nextUpdateTime, pendingIntent)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Schedule Live Activity"
            val descriptionText = "Shows current lesson and progress"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
