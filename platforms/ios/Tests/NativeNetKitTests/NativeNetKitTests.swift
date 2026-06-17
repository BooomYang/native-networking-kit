import Foundation
import XCTest
@testable import NativeNetKit

final class NativeNetKitTests: XCTestCase {
    func testClientForwardsRequestToInjectedEngine() async throws {
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

private struct MockEngine: NativeHttpEngine {
    let handler: @Sendable (NativeRequest) async throws -> NativeResponse

    func execute(_ request: NativeRequest) async throws -> NativeResponse {
        try await handler(request)
    }
}
