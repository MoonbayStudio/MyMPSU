package ru.moonbaystudio.mympsu.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import ru.moonbaystudio.mympsu.data.local.preferences.UserPreferences
import ru.moonbaystudio.mympsu.data.remote.MpguScheduleApiService
import ru.moonbaystudio.mympsu.data.remote.MyMPSUApiService
import javax.inject.Singleton
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    private const val MPGU_SCHEDULE_BASE_URL = "https://api.mympsu.moonbaystudio.ru/schedule/v1/"
    private const val MYMPSU_BASE_URL = "https://api.mympsu.moonbaystudio.ru/"

    @Provides
    @Singleton
    fun provideAuthInterceptor(userPreferences: UserPreferences): Interceptor {
        return Interceptor { chain ->
            val request = chain.request()
            val host = request.url.host

            val newRequest = if (host.contains("moonbaystudio.ru")) {
                val token = runBlocking { userPreferences.authToken.first() }
                request.newBuilder().apply {
                    if (token != null) {
                        header("Authorization", "Bearer $token")
                    }
                }.build()
            } else {
                request
            }
            chain.proceed(newRequest)
        }
    }

    @Provides
    @Singleton
    fun provideOkHttpClient(authInterceptor: Interceptor): OkHttpClient {
        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        }
        return OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .addInterceptor(logging)
            .connectTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
            .writeTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideMpguScheduleApiService(okHttpClient: OkHttpClient): MpguScheduleApiService {
        return Retrofit.Builder()
            .baseUrl(MPGU_SCHEDULE_BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(MpguScheduleApiService::class.java)
    }

    @Provides
    @Singleton
    fun provideMyMPSUApiService(okHttpClient: OkHttpClient): MyMPSUApiService {
        return Retrofit.Builder()
            .baseUrl(MYMPSU_BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(MyMPSUApiService::class.java)
    }
}
