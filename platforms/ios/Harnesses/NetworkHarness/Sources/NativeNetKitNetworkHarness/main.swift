import Foundation
import NativeNetKit

struct HarnessFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct NativeNetKitNetworkHarness {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let baseURLText = environment["NATIVE_NET_KIT_MOCK_BASE_URL"],
              let baseURL = URL(string: baseURLText) else {
            throw HarnessFailure(description: "NATIVE_NET_KIT_MOCK_BASE_URL is missing or invalid")
        }

        guard let unusedPortText = environment["NATIVE_NET_KIT_UNUSED_PORT"],
              let unusedPort = Int(unusedPortText) else {
            throw HarnessFailure(description: "NATIVE_NET_KIT_UNUSED_PORT is missing or invalid")
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 4
        let client = NativeNetClient(engine: URLSessionNativeHttpEngine(session: URLSession(configuration: configuration)))

        try await verifySuccessResponse(client: client, baseURL: baseURL)
        try await verifyDelayedResponse(client: client, baseURL: baseURL)
        try await verifyClosedConnection(client: client, baseURL: baseURL)
        try await verifyUnusedPort(unusedPort: unusedPort)

        print("NativeNetKit Swift host loopback check passed")
    }

    private static func verifySuccessResponse(client: NativeNetClient, baseURL: URL) async throws {
        let response = try await client.get(try endpoint("/success", baseURL: baseURL))

        try expect(response.statusCode == 200, "success status code should be 200")
        try expect(String(data: response.body, encoding: .utf8) == "success-body", "success body mismatch")
        try expect(header(response, named: "X-NativeNetKit-Harness") == "success", "success header mismatch")
    }

    private static func verifyDelayedResponse(client: NativeNetClient, baseURL: URL) async throws {
        let response = try await client.get(try endpoint("/delay?ms=150", baseURL: baseURL))

        try expect(response.statusCode == 200, "delayed response status code should be 200")
        try expect(String(data: response.body, encoding: .utf8) == "delayed-body", "delayed response body mismatch")
        try expect(response.elapsedMilliseconds != nil, "delayed response should report elapsed time")
    }

    private static func verifyClosedConnection(client: NativeNetClient, baseURL: URL) async throws {
        do {
            _ = try await client.get(try endpoint("/close", baseURL: baseURL))
            throw HarnessFailure(description: "closed connection should throw NativeNetworkError")
        } catch let error as NativeNetworkError {
            try expect(error.code == .transportFailure, "closed connection should map to transportFailure")
            try expect(error.rawDescription?.isEmpty == false, "closed connection should retain rawDescription")
        }
    }

    private static func verifyUnusedPort(unusedPort: Int) async throws {
        guard let url = URL(string: "http://127.0.0.1:\(unusedPort)/unused-port") else {
            throw HarnessFailure(description: "unused port URL could not be constructed")
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1
        configuration.timeoutIntervalForResource = 2
        let client = NativeNetClient(engine: URLSessionNativeHttpEngine(session: URLSession(configuration: configuration)))

        do {
            _ = try await client.get(url)
            throw HarnessFailure(description: "unused local port should throw NativeNetworkError")
        } catch let error as NativeNetworkError {
            try expect(error.code == .transportFailure, "unused port should map to transportFailure")
            try expect(error.rawDescription?.isEmpty == false, "unused port should retain rawDescription")
        }
    }

    private static func endpoint(_ path: String, baseURL: URL) throws -> URL {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw HarnessFailure(description: "Could not create URL for \(path)")
        }
        return url
    }

    private static func header(_ response: NativeResponse, named name: String) -> String? {
        response.headers.first { key, _ in
            key.caseInsensitiveCompare(name) == .orderedSame
        }?.value.first
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw HarnessFailure(description: message)
        }
    }
}
