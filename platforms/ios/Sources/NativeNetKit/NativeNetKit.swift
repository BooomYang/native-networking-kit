import Foundation

public struct NativeRequest: Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: [String]]
    public var body: Data?

    public init(
        method: String = "GET",
        url: URL,
        headers: [String: [String]] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct NativeResponse: Sendable, Equatable {
    public var statusCode: Int
    public var headers: [String: [String]]
    public var body: Data
    public var elapsedMilliseconds: Int64?

    public init(
        statusCode: Int,
        headers: [String: [String]] = [:],
        body: Data = Data(),
        elapsedMilliseconds: Int64? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.elapsedMilliseconds = elapsedMilliseconds
    }
}

public enum NativeNetworkErrorCode: String, Sendable, Equatable {
    case invalidRequest
    case transportFailure
    case cancelled
    case unknown
}

public struct NativeNetworkError: Error, Sendable, Equatable {
    public var code: NativeNetworkErrorCode
    public var message: String
    public var rawDescription: String?

    public init(
        code: NativeNetworkErrorCode,
        message: String,
        rawDescription: String? = nil
    ) {
        self.code = code
        self.message = message
        self.rawDescription = rawDescription
    }
}

public protocol NativeHttpEngine: Sendable {
    func execute(_ request: NativeRequest) async throws -> NativeResponse
}

public final class URLSessionNativeHttpEngine: NativeHttpEngine {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func execute(_ request: NativeRequest) async throws -> NativeResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body

        for (name, values) in request.headers {
            for value in values {
                urlRequest.addValue(value, forHTTPHeaderField: name)
            }
        }

        let start = Date()

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NativeNetworkError(
                    code: .transportFailure,
                    message: "Response was not an HTTP response"
                )
            }

            let elapsedMilliseconds = Int64(Date().timeIntervalSince(start) * 1_000)
            return NativeResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields.reduce(into: [:]) { result, item in
                    guard let key = item.key as? String else { return }
                    result[key, default: []].append(String(describing: item.value))
                },
                body: data,
                elapsedMilliseconds: elapsedMilliseconds
            )
        } catch is CancellationError {
            throw NativeNetworkError(code: .cancelled, message: "Request was cancelled")
        } catch let error as NativeNetworkError {
            throw error
        } catch {
            throw NativeNetworkError(
                code: .transportFailure,
                message: "URLSession request failed",
                rawDescription: String(describing: error)
            )
        }
    }
}

public final class NativeNetClient: Sendable {
    private let engine: NativeHttpEngine

    public init(engine: NativeHttpEngine = URLSessionNativeHttpEngine()) {
        self.engine = engine
    }

    public func execute(_ request: NativeRequest) async throws -> NativeResponse {
        try await engine.execute(request)
    }

    public func get(_ url: URL, headers: [String: [String]] = [:]) async throws -> NativeResponse {
        try await execute(NativeRequest(method: "GET", url: url, headers: headers))
    }
}
