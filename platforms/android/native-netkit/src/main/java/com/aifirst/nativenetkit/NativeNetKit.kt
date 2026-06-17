package com.aifirst.nativenetkit

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Call
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import kotlin.system.measureTimeMillis

data class NativeRequest(
    val method: String = "GET",
    val url: String,
    val headers: Map<String, List<String>> = emptyMap(),
    val body: ByteArray? = null,
)

data class NativeResponse(
    val statusCode: Int,
    val headers: Map<String, List<String>> = emptyMap(),
    val body: ByteArray = ByteArray(0),
    val elapsedMilliseconds: Long? = null,
)

enum class NativeNetworkErrorCode {
    INVALID_REQUEST,
    TRANSPORT_FAILURE,
    CANCELLED,
    UNKNOWN,
}

class NativeNetworkException(
    val code: NativeNetworkErrorCode,
    override val message: String,
    val rawDescription: String? = null,
    cause: Throwable? = null,
) : Exception(message, cause)

fun interface NativeHttpEngine {
    suspend fun execute(request: NativeRequest): NativeResponse
}

class OkHttpNativeHttpEngine(
    private val callFactory: Call.Factory = OkHttpClient(),
) : NativeHttpEngine {
    override suspend fun execute(request: NativeRequest): NativeResponse = withContext(Dispatchers.IO) {
        val okhttpRequest = try {
            request.toOkHttpRequest()
        } catch (error: IllegalArgumentException) {
            throw NativeNetworkException(
                code = NativeNetworkErrorCode.INVALID_REQUEST,
                message = "Invalid request",
                rawDescription = error.message,
                cause = error,
            )
        }

        var responseBytes = ByteArray(0)
        var statusCode = -1
        var headers: Map<String, List<String>> = emptyMap()
        val elapsed = try {
            measureTimeMillis {
                callFactory.newCall(okhttpRequest).execute().use { response ->
                    statusCode = response.code
                    headers = response.headers.toMultimap()
                    responseBytes = response.body?.bytes() ?: ByteArray(0)
                }
            }
        } catch (error: IOException) {
            throw NativeNetworkException(
                code = NativeNetworkErrorCode.TRANSPORT_FAILURE,
                message = "OkHttp request failed",
                rawDescription = error.message,
                cause = error,
            )
        }

        NativeResponse(
            statusCode = statusCode,
            headers = headers,
            body = responseBytes,
            elapsedMilliseconds = elapsed,
        )
    }

    private fun NativeRequest.toOkHttpRequest(): Request {
        val builder = Request.Builder().url(url)

        headers.forEach { (name, values) ->
            values.forEach { value -> builder.addHeader(name, value) }
        }

        val requestBody = body?.toRequestBody("application/octet-stream".toMediaTypeOrNull())
        builder.method(method, requestBody)
        return builder.build()
    }
}

class NativeNetClient(
    private val engine: NativeHttpEngine = OkHttpNativeHttpEngine(),
) {
    suspend fun execute(request: NativeRequest): NativeResponse {
        return engine.execute(request)
    }

    suspend fun get(url: String, headers: Map<String, List<String>> = emptyMap()): NativeResponse {
        return execute(NativeRequest(method = "GET", url = url, headers = headers))
    }
}
