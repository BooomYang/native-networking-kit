package com.aifirst.nativenetkit

import kotlinx.coroutines.test.runTest
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import okio.Timeout
import java.io.IOException
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse

class OkHttpNativeHttpEngineTest {
    @Test
    fun engineMapsHttpResponseIntoNativeResponse() = runTest {
        // 验证意图：
        // - 场景：native engine 收到 HTTP 503。
        // - 行为：应返回 `NativeResponse` 而不是抛 transport error。
        // - 风险：防止业务 HTTP 状态被误分类为网络故障。
        val engine = OkHttpNativeHttpEngine(FakeCallFactory { request ->
            Response.Builder()
                .request(request)
                .protocol(Protocol.HTTP_1_1)
                .code(503)
                .message("Service Unavailable")
                .header("X-NativeNetKit-Test", "non-2xx")
                .body("service-unavailable".toResponseBody("text/plain".toMediaType()))
                .build()
        })

        val response = engine.execute(NativeRequest(url = "https://example.com/status"))

        assertEquals(503, response.statusCode)
        assertEquals(listOf("non-2xx"), response.headers["X-NativeNetKit-Test"])
        assertContentEquals("service-unavailable".encodeToByteArray(), response.body)
    }

    @Test
    fun engineBuildsOkHttpRequestFromNativeRequest() = runTest {
        // 验证意图：
        // - 场景：调用方传入 method、headers 和 body。
        // - 行为：native engine 应构造等价 OkHttp request。
        // - 风险：防止 adapter 丢失影响请求语义的字段。
        lateinit var observedRequest: Request
        val engine = OkHttpNativeHttpEngine(FakeCallFactory { request ->
            observedRequest = request
            Response.Builder()
                .request(request)
                .protocol(Protocol.HTTP_1_1)
                .code(201)
                .message("Created")
                .body(ByteArray(0).toResponseBody("application/octet-stream".toMediaType()))
                .build()
        })
        val requestBody = "payload".encodeToByteArray()

        val response = engine.execute(
            NativeRequest(
                method = "POST",
                url = "https://example.com/upload",
                headers = mapOf("X-Trace-ID" to listOf("trace-1")),
                body = requestBody,
            ),
        )

        assertEquals(201, response.statusCode)
        assertEquals("POST", observedRequest.method)
        assertEquals("https://example.com/upload", observedRequest.url.toString())
        assertEquals("trace-1", observedRequest.header("X-Trace-ID"))
        assertContentEquals(requestBody, observedRequest.bodyBytes())
    }

    @Test
    fun engineMapsIOExceptionToTransportFailureWithRawDescription() = runTest {
        // 验证意图：
        // - 场景：OkHttp 抛出底层网络错误。
        // - 行为：native engine 应映射为 `TRANSPORT_FAILURE` 并保留 raw details。
        // - 风险：防止诊断信息丢失。
        val engine = OkHttpNativeHttpEngine(FakeCallFactory { throw IOException("offline") })

        val error = assertFailsWith<NativeNetworkException> {
            engine.execute(NativeRequest(url = "https://example.com/offline"))
        }

        assertEquals(NativeNetworkErrorCode.TRANSPORT_FAILURE, error.code)
        assertEquals("OkHttp request failed", error.message)
        assertFalse(error.rawDescription.isNullOrEmpty())
    }

    @Test
    fun engineMapsInvalidRequestToInvalidRequest() = runTest {
        // 验证意图：
        // - 场景：调用方传入无法构造 native platform request 的 URL。
        // - 行为：native engine 应映射为 `INVALID_REQUEST`。
        // - 风险：防止无效输入被误分类为 transport failure。
        val engine = OkHttpNativeHttpEngine(FakeCallFactory { request ->
            Response.Builder()
                .request(request)
                .protocol(Protocol.HTTP_1_1)
                .code(200)
                .message("OK")
                .body(ByteArray(0).toResponseBody("application/octet-stream".toMediaType()))
                .build()
        })

        val error = assertFailsWith<NativeNetworkException> {
            engine.execute(NativeRequest(url = "not a url"))
        }

        assertEquals(NativeNetworkErrorCode.INVALID_REQUEST, error.code)
        assertEquals("Invalid request", error.message)
        assertFalse(error.rawDescription.isNullOrEmpty())
    }
}

private class FakeCallFactory(
    private val executeBlock: (Request) -> Response,
) : Call.Factory {
    override fun newCall(request: Request): Call {
        return FakeCall(request, executeBlock)
    }
}

private class FakeCall(
    private val request: Request,
    private val executeBlock: (Request) -> Response,
) : Call {
    override fun request(): Request = request

    override fun execute(): Response = executeBlock(request)

    override fun enqueue(responseCallback: Callback) {
        throw UnsupportedOperationException("FakeCall only supports synchronous execute")
    }

    override fun cancel() {}

    override fun isExecuted(): Boolean = false

    override fun isCanceled(): Boolean = false

    override fun timeout(): Timeout = Timeout.NONE

    override fun clone(): Call = FakeCall(request, executeBlock)
}

private fun Request.bodyBytes(): ByteArray? {
    val body = body ?: return null
    val buffer = Buffer()
    body.writeTo(buffer)
    return buffer.readByteArray()
}
