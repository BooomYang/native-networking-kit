package com.aifirst.nativenetkit

import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withTimeout
import okhttp3.Request
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.test.fail

@OptIn(ExperimentalCoroutinesApi::class)
class OkHttpNativeSseEngineTest {
    @Test
    fun sseEngineBuildsOkHttpRequestAndEmitsEvents() = runTest {
        // 验证意图：
        // - 场景：SSE engine 使用 OkHttp EventSource 发起请求并收到事件。
        // - 行为：应构造等价 request，默认声明 `Accept: text/event-stream`，并转发 id/type/data。
        // - 风险：防止 streaming adapter 丢失 SSE request 和 event 语义。
        val eventSourceFactory = FakeEventSourceFactory()
        val engine = OkHttpNativeSseEngine(eventSourceFactory)

        val nextEvent = async {
            engine.stream(NativeRequest(url = "https://example.com/events")).first()
        }
        runCurrent()

        val source = eventSourceFactory.requireSource()
        assertEquals("https://example.com/events", source.observedRequest.url.toString())
        assertEquals("GET", source.observedRequest.method)
        assertEquals("text/event-stream", source.observedRequest.header("Accept"))

        source.listener.onEvent(source, id = "event-1", type = "message", data = "payload")

        assertEquals(
            NativeSseEvent(id = "event-1", type = "message", data = "payload"),
            nextEvent.await(),
        )
    }

    @Test
    fun sseEnginePreservesCallerAcceptHeader() = runTest {
        // 验证意图：
        // - 场景：调用方显式传入 Accept header。
        // - 行为：SSE engine 不应覆盖调用方 request header。
        // - 风险：防止 adapter 破坏上层 API gateway 或模型服务要求的协商语义。
        val eventSourceFactory = FakeEventSourceFactory()
        val engine = OkHttpNativeSseEngine(eventSourceFactory)

        val collection = async {
            engine.stream(
                NativeRequest(
                    url = "https://example.com/events",
                    headers = mapOf("Accept" to listOf("application/json")),
                ),
            ).first()
        }
        runCurrent()

        val source = eventSourceFactory.requireSource()
        assertEquals("application/json", source.observedRequest.header("Accept"))

        source.listener.onEvent(source, id = null, type = null, data = "done")
        collection.await()
    }

    @Test
    fun sseEngineMapsInvalidRequestToInvalidRequest() = runTest {
        // 验证意图：
        // - 场景：SSE 调用方传入无法构造 native platform request 的 URL。
        // - 行为：stream collection 应失败为 `INVALID_REQUEST`。
        // - 风险：防止 streaming API 的输入错误分类偏离普通 HTTP API。
        val engine = OkHttpNativeSseEngine(FakeEventSourceFactory())

        val error = assertFailsWith<NativeNetworkException> {
            engine.stream(NativeRequest(url = "not a url")).first()
        }

        assertEquals(NativeNetworkErrorCode.INVALID_REQUEST, error.code)
        assertEquals("Invalid request", error.message)
    }

    @Test
    fun sseEngineMapsEventSourceFailureToTransportFailure() = runTest {
        // 验证意图：
        // - 场景：OkHttp EventSource 报告底层网络失败。
        // - 行为：stream collection 应失败为 `TRANSPORT_FAILURE` 并保留 raw details。
        // - 风险：防止 SSE transport failure 被吞掉或失去诊断信息。
        val eventSourceFactory = FailingEventSourceFactory(IOException("offline"))
        val engine = OkHttpNativeSseEngine(eventSourceFactory)

        val error = assertFailsWith<NativeNetworkException> {
            engine.stream(NativeRequest(url = "https://example.com/events")).first()
        }
        assertEquals(NativeNetworkErrorCode.TRANSPORT_FAILURE, error.code)
        assertEquals("OkHttp SSE stream failed", error.message)
        assertEquals("offline", error.rawDescription)
    }

    @Test
    fun sseEngineBackpressuresBurstEventsWithoutCancellingEventSource() {
        // 验证意图：
        // - 场景：SSE 服务端快速发送超过默认 Flow buffer 的事件，collector 慢速消费。
        // - 行为：adapter 应通过背压保留事件并保持连接，不应把临时 buffer full 当作取消。
        // - 风险：防止模型流式输出或高频事件流被静默截断。
        val eventSourceFactory = FakeEventSourceFactory()
        val engine = OkHttpNativeSseEngine(eventSourceFactory)
        val eventCount = 100
        val collectedEvents = AtomicReference<List<NativeSseEvent>>()
        val collectorError = AtomicReference<Throwable?>()

        val collectorThread = thread(name = "native-netkit-sse-collector") {
            try {
                val events = runBlocking {
                    withTimeout(5_000) {
                        engine.stream(NativeRequest(url = "https://example.com/events"))
                            .take(eventCount)
                            .onEach { Thread.sleep(1) }
                            .toList()
                    }
                }
                collectedEvents.set(events)
            } catch (error: Throwable) {
                collectorError.set(error)
            }
        }

        val source = eventSourceFactory.awaitSource()
        var cancelledBeforeAllEventsWereSent = false
        repeat(eventCount) { index ->
            source.listener.onEvent(source, id = index.toString(), type = "message", data = "event-$index")
            if (index < eventCount - 1 && source.cancelled) {
                cancelledBeforeAllEventsWereSent = true
            }
        }
        assertFalse(cancelledBeforeAllEventsWereSent)

        collectorThread.join(5_000)
        if (collectorThread.isAlive) {
            fail("Timed out waiting for SSE collector")
        }
        collectorError.get()?.let { error ->
            throw AssertionError("SSE collector failed", error)
        }

        val events = requireNotNull(collectedEvents.get()) { "Expected collected events" }
        assertEquals(eventCount, events.size)
        assertEquals("event-0", events.first().data)
        assertEquals("event-${eventCount - 1}", events.last().data)
    }

    @Test
    fun cancellingSseCollectionCancelsEventSource() = runTest {
        // 验证意图：
        // - 场景：调用方取消 SSE event collection。
        // - 行为：底层 OkHttp EventSource 应被取消。
        // - 风险：防止 streaming connection 在 caller 生命周期结束后泄漏。
        val eventSourceFactory = FakeEventSourceFactory()
        val engine = OkHttpNativeSseEngine(eventSourceFactory)

        val collection = launch {
            engine.stream(NativeRequest(url = "https://example.com/events")).collect()
        }
        runCurrent()

        val source = eventSourceFactory.requireSource()
        collection.cancelAndJoin()

        assertTrue(source.cancelled)
    }
}

private class FakeEventSourceFactory : EventSource.Factory {
    private val createdLatch = CountDownLatch(1)
    private var source: FakeEventSource? = null

    override fun newEventSource(request: Request, listener: EventSourceListener): EventSource {
        return FakeEventSource(request, listener).also {
            source = it
            createdLatch.countDown()
        }
    }

    fun requireSource(): FakeEventSource {
        return requireNotNull(source) { "Expected EventSource to be created" }
    }

    fun awaitSource(): FakeEventSource {
        if (!createdLatch.await(5, TimeUnit.SECONDS)) {
            error("Timed out waiting for EventSource to be created")
        }
        return requireSource()
    }
}

private class FailingEventSourceFactory(
    private val failure: IOException,
) : EventSource.Factory {
    override fun newEventSource(request: Request, listener: EventSourceListener): EventSource {
        return FakeEventSource(request, listener).also {
            listener.onFailure(it, failure, response = null)
        }
    }
}

private class FakeEventSource(
    val observedRequest: Request,
    val listener: EventSourceListener,
) : EventSource {
    var cancelled: Boolean = false
        private set

    override fun request(): Request {
        return observedRequest
    }

    override fun cancel() {
        cancelled = true
    }
}
