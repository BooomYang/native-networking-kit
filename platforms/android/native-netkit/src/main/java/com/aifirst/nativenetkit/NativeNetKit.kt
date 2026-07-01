package com.aifirst.nativenetkit

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.channels.trySendBlocking
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.withContext
import okhttp3.Call
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener
import okhttp3.sse.EventSources
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

data class NativeSseEvent(
    val id: String? = null,
    val type: String? = null,
    val data: String,
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

fun interface NativeSseEngine {
    fun stream(request: NativeRequest): Flow<NativeSseEvent>
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
}

class OkHttpNativeSseEngine(
    private val eventSourceFactory: EventSource.Factory = EventSources.createFactory(OkHttpClient()),
) : NativeSseEngine {
    override fun stream(request: NativeRequest): Flow<NativeSseEvent> = callbackFlow {
        val okhttpRequest = try {
            request.toOkHttpRequest(defaultAccept = "text/event-stream")
        } catch (error: IllegalArgumentException) {
            close(
                NativeNetworkException(
                    code = NativeNetworkErrorCode.INVALID_REQUEST,
                    message = "Invalid request",
                    rawDescription = error.message,
                    cause = error,
                ),
            )
            return@callbackFlow
        }

        val eventSource = eventSourceFactory.newEventSource(
            okhttpRequest,
            object : EventSourceListener() {
                override fun onEvent(eventSource: EventSource, id: String?, type: String?, data: String) {
                    val result = trySendBlocking(NativeSseEvent(id = id, type = type, data = data))
                    if (result.isFailure) {
                        eventSource.cancel()
                    }
                }

                override fun onClosed(eventSource: EventSource) {
                    close()
                }

                override fun onFailure(eventSource: EventSource, t: Throwable?, response: Response?) {
                    close(
                        NativeNetworkException(
                            code = NativeNetworkErrorCode.TRANSPORT_FAILURE,
                            message = "OkHttp SSE stream failed",
                            rawDescription = t?.message ?: response?.let { "HTTP ${it.code}" },
                            cause = t,
                        ),
                    )
                }
            },
        )

        awaitClose { eventSource.cancel() }
    }
}

class NativeNetClient(
    private val engine: NativeHttpEngine = OkHttpNativeHttpEngine(),
    private val sseEngine: NativeSseEngine = OkHttpNativeSseEngine(),
) {
    constructor(engine: NativeHttpEngine) : this(engine, OkHttpNativeSseEngine())

    suspend fun execute(request: NativeRequest): NativeResponse {
        return engine.execute(request)
    }

    suspend fun get(url: String, headers: Map<String, List<String>> = emptyMap()): NativeResponse {
        return execute(NativeRequest(method = "GET", url = url, headers = headers))
    }

    fun stream(request: NativeRequest): Flow<NativeSseEvent> {
        return sseEngine.stream(request)
    }

    fun stream(url: String, headers: Map<String, List<String>> = emptyMap()): Flow<NativeSseEvent> {
        return stream(NativeRequest(method = "GET", url = url, headers = headers))
    }
}

private fun NativeRequest.toOkHttpRequest(defaultAccept: String? = null): Request {
    val builder = Request.Builder().url(url)

    headers.forEach { (name, values) ->
        values.forEach { value -> builder.addHeader(name, value) }
    }

    if (defaultAccept != null && headers.keys.none { it.equals("Accept", ignoreCase = true) }) {
        builder.addHeader("Accept", defaultAccept)
    }

    val requestBody = body?.toRequestBody("application/octet-stream".toMediaTypeOrNull())
    builder.method(method, requestBody)
    return builder.build()
}
