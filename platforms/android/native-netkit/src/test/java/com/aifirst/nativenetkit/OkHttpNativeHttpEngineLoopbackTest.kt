package com.aifirst.nativenetkit

import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
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
    private val client = NativeNetClient(
        OkHttpNativeHttpEngine(
            OkHttpClient.Builder()
                .connectTimeout(1, TimeUnit.SECONDS)
                .readTimeout(2, TimeUnit.SECONDS)
                .callTimeout(4, TimeUnit.SECONDS)
                .build(),
        ),
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
