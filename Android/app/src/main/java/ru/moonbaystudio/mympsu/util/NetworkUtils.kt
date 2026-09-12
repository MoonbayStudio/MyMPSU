package ru.moonbaystudio.mympsu.util

import retrofit2.Response

sealed class NetworkResult<out T> {
    data class Success<out T>(val data: T) : NetworkResult<T>()
    data class Error(val code: Int, val message: String?) : NetworkResult<Nothing>()
    data class Exception(val e: Throwable) : NetworkResult<Nothing>()
}

suspend fun <T : Any> safeApiCall(call: suspend () -> Response<T>): NetworkResult<T> {
    return try {
        val response = call()
        if (response.isSuccessful) {
            val body = response.body()
            if (body != null) {
                NetworkResult.Success(body)
            } else {
                NetworkResult.Error(response.code(), "Empty response body")
            }
        } else {
            NetworkResult.Error(response.code(), response.errorBody()?.string())
        }
    } catch (e: Exception) {
        NetworkResult.Exception(e)
    }
}

fun <T> NetworkResult<T>.toResult(): Result<T> {
    return when (this) {
        is NetworkResult.Success -> Result.success(data)
        is NetworkResult.Error -> Result.failure(Exception("Error $code: $message"))
        is NetworkResult.Exception -> Result.failure(e)
    }
}

fun <T> NetworkResult<T>.getOrElse(fallback: (NetworkResult<T>) -> T): T {
    return if (this is NetworkResult.Success) data else fallback(this)
}

inline fun <T> NetworkResult<T>.onSuccess(action: (T) -> Unit): NetworkResult<T> {
    if (this is NetworkResult.Success) action(data)
    return this
}
