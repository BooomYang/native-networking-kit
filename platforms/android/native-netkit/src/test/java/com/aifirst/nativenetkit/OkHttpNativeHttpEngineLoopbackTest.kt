package com.aifirst.nativenetkit

import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.sse.EventSources
import java.util.concurrent.TimeUnit
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class OkHttpNativeHttpEngineLoopbackTest {
    private val baseUrl: String = requireEnv("NATIVE_NET_KIT_MOCK_BASE_URL").trimEnd('/')
    private val unusedPort: Int = requireEnv("NATIVE_NET_KIT_UNUSED_PORT").toInt()
    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(1, TimeUnit.SECONDS)
        .readTimeout(2, TimeUnit.SECONDS)
        .callTimeout(4, TimeUnit.SECONDS)
        .build()
    private val client = NativeNetClient(
        engine = OkHttpNativeHttpEngine(okHttpClient),
        sseEngine = OkHttpNativeSseEngine(EventSources.createFactory(okHttpClient)),
    )

    @Test
    fun successResponseExposesStatusBodyAndHeaders() = runTest {
        // 验证意图：
        // - 场景：host loopback server 返回成功响应。
        // - 行为：`NativeNetClient` 应暴露 status、body 和 headers。
        // - 风险：防止真实 engine adapter 丢失成功响应的 public response semantics。
        val response = client.get("$baseUrl/success")

        assertEquals(200, response.statusCode)
        assertContentEquals("success-body".encodeToByteArray(), response.body)
        assertEquals("success", response.header("X-NativeNetKit-Harness"))
    }

    @Test
    fun delayedResponseCompletesAndExposesElapsedTime() = runTest {
        // 验证意图：
        // - 场景：host loopback server 返回可控延迟响应。
        // - 行为：`NativeNetClient` 应完成请求并暴露 elapsed time。
        // - 风险：防止真实 transport 边界下延迟响应被误报为失败或丢失耗时信号。
        val response = client.get("$baseUrl/delay?ms=150")

        assertEquals(200, response.statusCode)
        assertContentEquals("delayed-body".encodeToByteArray(), response.body)
        assertNotNull(response.elapsedMilliseconds)
        assertTrue(response.elapsedMilliseconds!! >= 0)
    }

    @Test
    fun closedConnectionMapsToTransportFailureWithRawDescription() = runTest {
        // 验证意图：
        // - 场景：host loopback server 在响应前关闭连接。
        // - 行为：`NativeNetClient` 应抛出 `TRANSPORT_FAILURE` 并保留 raw details。
        // - 风险：防止真实 socket 断连被误分类或丢失诊断信息。
        val error = assertFailsWith<NativeNetworkException> {
            client.get("$baseUrl/close")
        }

        assertEquals(NativeNetworkErrorCode.TRANSPORT_FAILURE, error.code)
        assertFalse(error.rawDescription.isNullOrEmpty())
    }

    @Test
    fun unusedPortMapsToTransportFailureWithRawDescription() = runTest {
        // 验证意图：
        // - 场景：请求本机未监听端口。
        // - 行为：`NativeNetClient` 应抛出 `TRANSPORT_FAILURE` 并保留 raw details。
        // - 风险：防止连接拒绝被误分类或丢失诊断信息。
        val error = assertFailsWith<NativeNetworkException> {
            client.get("http://127.0.0.1:$unusedPort/unused-port")
        }

        assertEquals(NativeNetworkErrorCode.TRANSPORT_FAILURE, error.code)
        assertFalse(error.rawDescription.isNullOrEmpty())
    }

    @Test
    fun mockModelApiSseResponseEmitsOrderedEvents() = runTest {
        // 验证意图：
        // - 场景：host loopback server 模拟大模型 API 的 `text/event-stream` 响应。
        // - 行为：`NativeNetClient.stream` 应通过真实 OkHttp SSE adapter 按顺序暴露 event type 和 JSON data。
        // - 风险：防止标准 SSE 请求在真实 transport 边界下退化为一次性 body 读取或丢失事件顺序。
        val requestBody = """
            {"model":"native-netkit-mock-model","stream":true,"messages":[{"role":"user","content":"Say hello"}]}
        """.trimIndent().encodeToByteArray()

        val events = client.stream(
            NativeRequest(
                method = "POST",
                url = "$baseUrl/v1/chat/completions",
                headers = mapOf(
                    "Authorization" to listOf("Bearer loopback-token"),
                    "Accept" to listOf("text/event-stream"),
                ),
                body = requestBody,
            ),
        ).toList()

        assertEquals(
            listOf(
                "response.created",
                "response.output_text.delta",
                "response.output_text.delta",
                "response.completed",
            ),
            events.map { it.type },
        )
        assertTrue(events[0].data.contains("resp_mock_1"))
        assertTrue(events[1].data.contains("\"delta\":\"Hel\""))
        assertTrue(events[2].data.contains("\"delta\":\"lo\""))
        assertTrue(events[3].data.contains("\"output_text\":\"Hello\""))
    }

    private fun NativeResponse.header(name: String): String? {
        return headers.entries.firstOrNull { (key, _) -> key.equals(name, ignoreCase = true) }
            ?.value
            ?.firstOrNull()
    }

    private fun requireEnv(name: String): String {
        return requireNotNull(System.getenv(name)) {
            "$name is required. Run ./scripts/verify-android-network-harness.sh."
        }
    }
}
