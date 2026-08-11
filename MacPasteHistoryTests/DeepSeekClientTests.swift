import Foundation
import XCTest
@testable import MacPasteHistory

final class DeepSeekClientTests: XCTestCase {
    override func tearDown() {
        DeepSeekMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testPolish_shouldSendConfiguredModelAuthorizationAndPolishingMessages() async throws {
        var capturedRequest: URLRequest?
        DeepSeekMockURLProtocol.handler = { request in
            capturedRequest = request
            return Self.response(status: 200, body: Self.successBody)
        }
        let client = makeClient()

        let result = try await client.polish(
            text: "draft text",
            modelIdentifier: "deepseek-v4-flash",
            apiKey: "fake-api-key"
        )

        XCTAssertEqual(result.polishedText, "Polished text")
        XCTAssertEqual(result.usage, DeepSeekTokenUsage(inputTokens: 12, outputTokens: 4, totalTokens: 16, cachedInputTokens: 3))
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer fake-api-key")
        let body = try XCTUnwrap(Self.bodyData(from: capturedRequest))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "deepseek-v4-flash")
        XCTAssertEqual((json["thinking"] as? [String: String])?["type"], "disabled")
        XCTAssertEqual((json["messages"] as? [[String: String]])?.last?["content"], "draft text")
    }

    func testPolish_whenUsageIsMissing_shouldReturnUsableResultWithoutEstimate() async throws {
        DeepSeekMockURLProtocol.handler = { _ in
            Self.response(status: 200, body: """
            {"id":"response-2","model":"deepseek-v4-flash","choices":[{"message":{"role":"assistant","content":"Usable output"}}]}
            """)
        }

        let result = try await makeClient().polish(text: "draft", modelIdentifier: "model", apiKey: "key")

        XCTAssertEqual(result.polishedText, "Usable output")
        XCTAssertNil(result.usage)
    }

    func testPolish_shouldMapAuthenticationRateLimitAndNetworkErrors() async {
        await assertError(status: 401, expected: .authenticationFailed)
        await assertError(status: 429, expected: .rateLimited)

        DeepSeekMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await assertClientError(.networkUnavailable)
    }

    func testPolish_shouldRejectMalformedEmptyAndOversizedResponses() async {
        DeepSeekMockURLProtocol.handler = { _ in Self.response(status: 200, body: "not-json") }
        await assertClientError(.invalidResponse)

        DeepSeekMockURLProtocol.handler = { _ in
            Self.response(status: 200, body: """
            {"id":"empty","model":"model","choices":[{"message":{"role":"assistant","content":"  "}}]}
            """)
        }
        await assertClientError(.emptyResult)

        DeepSeekMockURLProtocol.handler = { _ in
            let data = Data(repeating: 65, count: DeepSeekClient.maxResponseBytes + 1)
            return (Self.httpResponse(status: 200), data)
        }
        await assertClientError(.responseTooLarge)
    }

    func testPolish_shouldMapTimeoutAndCancellationWithoutSensitiveErrorText() async {
        DeepSeekMockURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await assertClientError(.timedOut)

        DeepSeekMockURLProtocol.handler = { _ in throw URLError(.cancelled) }
        do {
            _ = try await makeClient().polish(text: "private synthetic text", modelIdentifier: "model", apiKey: "fake-secret")
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
            let description = String(describing: error)
            XCTAssertFalse(description.contains("private synthetic text"))
            XCTAssertFalse(description.contains("fake-secret"))
        }
    }

    private func assertError(status: Int, expected: DeepSeekClientError) async {
        DeepSeekMockURLProtocol.handler = { _ in Self.response(status: status, body: "{}") }
        await assertClientError(expected)
    }

    private func assertClientError(_ expected: DeepSeekClientError) async {
        do {
            _ = try await makeClient().polish(text: "draft", modelIdentifier: "model", apiKey: "key")
            XCTFail("Expected \(expected)")
        } catch let error as DeepSeekClientError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeClient() -> DeepSeekClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeepSeekMockURLProtocol.self]
        return DeepSeekClient(session: URLSession(configuration: configuration))
    }

    private static func response(status: Int, body: String) -> (HTTPURLResponse, Data) {
        (httpResponse(status: status), Data(body.utf8))
    }

    private static func bodyData(from request: URLRequest?) -> Data? {
        guard let request else { return nil }
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private static func httpResponse(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: DeepSeekClient.endpoint ?? URL(fileURLWithPath: "/"),
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ) ?? HTTPURLResponse()
    }

    private static let successBody = """
    {"id":"response-1","model":"deepseek-v4-flash","choices":[{"message":{"role":"assistant","content":"Polished text"}}],"usage":{"prompt_tokens":12,"completion_tokens":4,"total_tokens":16,"prompt_cache_hit_tokens":3}}
    """
}

private final class DeepSeekMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
