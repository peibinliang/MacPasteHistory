import Foundation

protocol DeepSeekClientProtocol: Sendable {
    func polish(text: String, modelIdentifier: String, apiKey: String) async throws -> DeepSeekPolishingResult
}

final class DeepSeekClient: DeepSeekClientProtocol, @unchecked Sendable {
    static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")
    static let requestTimeout: TimeInterval = 30
    static let maxInputCharacters = 100_000
    static let maxOutputCharacters = 100_000
    static let maxResponseBytes = 2 * 1024 * 1024
    static let maxOutputTokens = 8_192
    static let polishingInstructionVersion = "v1"
    static let polishingInstruction = """
    [polishing-instruction:\(polishingInstructionVersion)]
    Improve the clarity, fluency, grammar, and wording of the user's text while preserving its meaning and language. Return only the polished text, with no explanation or quotation marks.
    """

    private let session: URLSession
    private let endpoint: URL?

    init(session: URLSession = .shared, endpoint: URL? = DeepSeekClient.endpoint) {
        self.session = session
        self.endpoint = endpoint
    }

    func polish(text: String, modelIdentifier: String, apiKey: String) async throws -> DeepSeekPolishingResult {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.isEmpty == false,
              normalizedText.count <= Self.maxInputCharacters,
              normalizedModel.isEmpty == false,
              normalizedKey.isEmpty == false else {
            throw DeepSeekClientError.invalidInput
        }
        guard let endpoint else {
            throw DeepSeekClientError.invalidRequest
        }

        let request = try makeRequest(
            endpoint: endpoint,
            text: normalizedText,
            modelIdentifier: normalizedModel,
            apiKey: normalizedKey
        )
        do {
            let (data, response) = try await session.data(for: request)
            return try decode(data: data, response: response, requestedModel: normalizedModel)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DeepSeekClientError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw CancellationError()
            case .timedOut:
                throw DeepSeekClientError.timedOut
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dnsLookupFailed:
                throw DeepSeekClientError.networkUnavailable
            default:
                throw DeepSeekClientError.serviceUnavailable
            }
        } catch {
            throw DeepSeekClientError.serviceUnavailable
        }
    }

    private func makeRequest(
        endpoint: URL,
        text: String,
        modelIdentifier: String,
        apiKey: String
    ) throws -> URLRequest {
        let body = ChatCompletionRequest(
            model: modelIdentifier,
            messages: [
                Message(role: "system", content: Self.polishingInstruction),
                Message(role: "user", content: text)
            ],
            maxTokens: Self.maxOutputTokens,
            stream: false,
            thinking: Thinking(type: "disabled")
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw DeepSeekClientError.invalidRequest
        }
        return request
    }

    private func decode(
        data: Data,
        response: URLResponse,
        requestedModel: String
    ) throws -> DeepSeekPolishingResult {
        guard let response = response as? HTTPURLResponse else {
            throw DeepSeekClientError.invalidResponse
        }
        switch response.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw DeepSeekClientError.authenticationFailed
        case 429:
            throw DeepSeekClientError.rateLimited
        default:
            throw DeepSeekClientError.serviceUnavailable
        }
        guard data.count <= Self.maxResponseBytes else {
            throw DeepSeekClientError.responseTooLarge
        }
        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw DeepSeekClientError.invalidResponse
        }
        let output = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard output.isEmpty == false else {
            throw DeepSeekClientError.emptyResult
        }
        guard output.count <= Self.maxOutputCharacters else {
            throw DeepSeekClientError.responseTooLarge
        }
        return DeepSeekPolishingResult(
            requestID: decoded.id.isEmpty ? UUID().uuidString : decoded.id,
            modelIdentifier: decoded.model.isEmpty ? requestedModel : decoded.model,
            polishedText: output,
            usage: decoded.usage.map {
                DeepSeekTokenUsage(
                    inputTokens: $0.promptTokens,
                    outputTokens: $0.completionTokens,
                    totalTokens: $0.totalTokens,
                    cachedInputTokens: $0.promptCacheHitTokens
                )
            }
        )
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let stream: Bool
    let thinking: Thinking

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, thinking
        case maxTokens = "max_tokens"
    }
}

private struct Message: Codable {
    let role: String
    let content: String
}

private struct Thinking: Encodable {
    let type: String
}

private struct ChatCompletionResponse: Decodable {
    let id: String
    let model: String
    let choices: [Choice]
    let usage: Usage?

    private enum CodingKeys: String, CodingKey {
        case id, model, choices, usage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        choices = try container.decode([Choice].self, forKey: .choices)
        usage = try container.decodeIfPresent(Usage.self, forKey: .usage)
    }
}

private struct Choice: Decodable {
    let message: Message
}

private struct Usage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let promptCacheHitTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case promptCacheHitTokens = "prompt_cache_hit_tokens"
    }
}
