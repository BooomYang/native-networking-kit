import Foundation
import XCTest
@testable import NativeNetKit

final class NativeNetKitTests: XCTestCase {
    func testClientForwardsRequestToInjectedEngine() async throws {
        // 验证意图：当调用方通过 `NativeNetClient.get` 发起 GET 时，client 应把 method、url 和 headers 交给 injected engine；防止 client 层破坏统一 request contract。
        let url = try XCTUnwrap(URL(string: "https://example.com/status"))
        let engine = MockEngine { request in
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.headers["Accept"], ["application/json"])
            return NativeResponse(statusCode: 204, body: Data("ok".utf8), elapsedMilliseconds: 12)
        }

        let client = NativeNetClient(engine: engine)
        let response = try await client.get(url, headers: ["Accept": ["application/json"]])

        XCTAssertEqual(response.statusCode, 204)
        XCTAssertEqual(response.body, Data("ok".utf8))
        XCTAssertEqual(response.elapsedMilliseconds, 12)
    }

    func testClientPropagatesNativeNetworkError() async throws {
        // 验证意图：当 injected engine 抛出 `NativeNetworkError` 时，client 应原样传播；防止 client 层吞掉或重写统一错误语义。
        let url = try XCTUnwrap(URL(string: "https://example.com/fail"))
        let expected = NativeNetworkError(code: .transportFailure, message: "mock failure")
        let client = NativeNetClient(engine: MockEngine { _ in throw expected })

        do {
            _ = try await client.get(url)
            XCTFail("Expected request to fail")
        } catch let error as NativeNetworkError {
            XCTAssertEqual(error, expected)
        }
    }
}

final class URLSessionNativeHttpEngineTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testEngineMapsHTTPResponseIntoNativeResponse() async throws {
        // 验证意图：当 native engine 收到 HTTP 503 时，应返回 `NativeResponse` 而不是抛 transport error；防止业务 HTTP 状态被误分类为网络故障。
        let url = try XCTUnwrap(URL(string: "https://example.com/status"))
        let engine = makeClient { request in
            XCTAssertEqual(request.url, url)

            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 503,
                httpVersion: "HTTP/1.1",
                headerFields: ["X-NativeNetKit-Test": "non-2xx"]
            ))
            return StubbedURLSessionResponse(
                response: response,
                data: Data("service-unavailable".utf8)
            )
        }

        let response = try await engine.get(url)

        XCTAssertEqual(response.statusCode, 503)
        XCTAssertEqual(response.body, Data("service-unavailable".utf8))
        XCTAssertEqual(response.headers["X-NativeNetKit-Test"], ["non-2xx"])
    }

    func testEngineMapsNonHTTPResponseToTransportFailure() async throws {
        // 验证意图：当 `URLSession` 返回非 HTTP response 时，native engine 应映射为 `.transportFailure`；防止 adapter 向上层暴露无法解释的 response。
        let url = try XCTUnwrap(URL(string: "https://example.com/non-http"))
        let engine = makeClient { _ in
            StubbedURLSessionResponse(
                response: URLResponse(
                    url: url,
                    mimeType: "text/plain",
                    expectedContentLength: 0,
                    textEncodingName: nil
                ),
                data: Data()
            )
        }

        do {
            _ = try await engine.get(url)
            XCTFail("Expected non-HTTP response to fail")
        } catch let error as NativeNetworkError {
            XCTAssertEqual(error.code, .transportFailure)
            XCTAssertEqual(error.message, "Response was not an HTTP response")
        }
    }

    func testEngineMapsURLSessionErrorToTransportFailureWithRawDescription() async throws {
        // 验证意图：当 `URLSession` 抛出底层网络错误时，native engine 应映射为 `.transportFailure` 并保留 raw details；防止诊断信息丢失。
        let url = try XCTUnwrap(URL(string: "https://example.com/offline"))
        let engine = makeClient { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await engine.get(url)
            XCTFail("Expected URLSession error to fail")
        } catch let error as NativeNetworkError {
            XCTAssertEqual(error.code, .transportFailure)
            XCTAssertEqual(error.message, "URLSession request failed")
            XCTAssertEqual(error.rawDescription?.isEmpty, false)
        }
    }

    func testEngineBuildsURLRequestFromNativeRequest() async throws {
        // 验证意图：当调用方传入 method、headers 和 body 时，native engine 应构造等价 `URLRequest`；防止 adapter 丢失影响请求语义的字段。
        let url = try XCTUnwrap(URL(string: "https://example.com/upload"))
        let requestBody = Data("payload".utf8)
        let engine = makeClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Trace-ID"), "trace-1")
            XCTAssertEqual(Self.bodyData(from: request), requestBody)

            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 201,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            ))
            return StubbedURLSessionResponse(response: response, data: Data())
        }

        let response = try await engine.execute(NativeRequest(
            method: "POST",
            url: url,
            headers: ["X-Trace-ID": ["trace-1"]],
            body: requestBody
        ))

        XCTAssertEqual(response.statusCode, 201)
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count > 0 {
                data.append(buffer, count: count)
            } else if count < 0 {
                return nil
            } else {
                break
            }
        }

        return data
    }

    private func makeClient(
        handler: @escaping (URLRequest) throws -> StubbedURLSessionResponse
    ) -> NativeNetClient {
        StubURLProtocol.handler = handler

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return NativeNetClient(engine: URLSessionNativeHttpEngine(session: URLSession(configuration: configuration)))
    }
}

private struct MockEngine: NativeHttpEngine {
    let handler: @Sendable (NativeRequest) async throws -> NativeResponse

    func execute(_ request: NativeRequest) async throws -> NativeResponse {
        try await handler(request)
    }
}

private struct StubbedURLSessionResponse {
    let response: URLResponse
    let data: Data
}

private enum StubURLProtocolError: Error {
    case missingHandler
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> StubbedURLSessionResponse)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw StubURLProtocolError.missingHandler
            }

            let stub = try handler(request)
            client?.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
