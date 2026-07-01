package com.aifirst.nativenetkit

import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class NativeNetKitTest {
    @Test
    fun clientForwardsRequestToInjectedEngine() = runTest {
        // 验证意图：
        // - 场景：调用方通过 `NativeNetClient.get` 发起 GET。
        // - 行为：client 应把 method、url 和 headers 交给 injected engine。
        // - 风险：防止 client 层破坏统一 request contract。
        val engine = NativeHttpEngine { request ->
            assertEquals("GET", request.method)
            assertEquals("https://example.com/status", request.url)
            assertEquals(listOf("application/json"), request.headers["Accept"])
            NativeResponse(
                statusCode = 204,
                body = "ok".encodeToByteArray(),
                elapsedMilliseconds = 12,
            )
        }

        val client = NativeNetClient(engine)
        val response = client.get(
            url = "https://example.com/status",
            headers = mapOf("Accept" to listOf("application/json")),
        )

        assertEquals(204, response.statusCode)
        assertContentEquals("ok".encodeToByteArray(), response.body)
        assertEquals(12, response.elapsedMilliseconds)
    }

    @Test
    fun clientPropagatesNativeNetworkException() = runTest {
        // 验证意图：
        // - 场景：injected engine 抛出 `NativeNetworkException`。
        // - 行为：client 应原样传播统一错误语义。
        // - 风险：防止 client 层吞掉或重写 `NativeNetworkException`。
        val expected = NativeNetworkException(
            code = NativeNetworkErrorCode.TRANSPORT_FAILURE,
            message = "mock failure",
        )
        val client = NativeNetClient(NativeHttpEngine { throw expected })

        val actual = assertFailsWith<NativeNetworkException> {
            client.get("https://example.com/fail")
        }

        assertEquals(expected.code, actual.code)
        assertEquals(expected.message, actual.message)
    }

    @Test
    fun clientKeepsSingleEngineJvmConstructor() {
        // 验证意图：
        // - 场景：已有 JVM 调用方只注入 `NativeHttpEngine` 构造 `NativeNetClient`。
        // - 行为：class 应继续暴露 `NativeNetClient(NativeHttpEngine)` public constructor。
        // - 风险：防止新增 SSE engine dependency 破坏已编译 consumer 的 binary compatibility。
        val constructor = NativeNetClient::class.java.getConstructor(NativeHttpEngine::class.java)

        assertEquals(NativeNetClient::class.java, constructor.declaringClass)
    }

    @Test
    fun clientForwardsSseRequestToInjectedEngine() = runTest {
        // 验证意图：
        // - 场景：调用方通过 `NativeNetClient.stream` 发起 SSE 请求。
        // - 行为：client 应把 request 交给 injected SSE engine 并暴露事件流。
        // - 风险：防止 client 层绕过可替换的 streaming engine boundary。
        val sseEngine = NativeSseEngine { request ->
            assertEquals("GET", request.method)
            assertEquals("https://example.com/events", request.url)
            assertEquals(listOf("Bearer token"), request.headers["Authorization"])
            flowOf(NativeSseEvent(id = "1", type = "message", data = "ok"))
        }
        val client = NativeNetClient(
            engine = NativeHttpEngine { error("HTTP engine should not be used") },
            sseEngine = sseEngine,
        )

        val event = client.stream(
            url = "https://example.com/events",
            headers = mapOf("Authorization" to listOf("Bearer token")),
        ).first()

        assertEquals(NativeSseEvent(id = "1", type = "message", data = "ok"), event)
    }
}
