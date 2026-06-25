import Foundation

// MARK: - Request / Response types

private struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [ClaudeMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, system, messages, stream
        case maxTokens = "max_tokens"
    }
}

private struct ClaudeMessage: Encodable {
    let role: String
    let content: String
}

private struct SSEEvent: Decodable {
    let type: String
    let delta: SSEDelta?
    let error: SSEError?
}

private struct SSEDelta: Decodable {
    let type: String?
    let text: String?
}

private struct SSEError: Decodable {
    let type: String
    let message: String
}

// MARK: - Errors

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case decodingError
    case rateLimited
    case streamCancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:           return "Service unavailable. Please try again later."
        case .httpError(let c, let m): return "API error \(c): \(m)"
        case .decodingError:           return "Failed to parse the API response."
        case .rateLimited:             return "Rate limited — please wait a moment."
        case .streamCancelled:         return "Request was cancelled."
        }
    }
}

// MARK: - Service

/// Streams text from Claude. Routes through the backend proxy when configured,
/// falls back to direct Anthropic calls in development.
actor AnthropicService {

    static let shared = AnthropicService()

    private let directEndpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"
    private let model      = "claude-haiku-4-5-20251001"
    private let maxTokens  = 300

    // MARK: - Public streaming API

    func streamCompletion(
        systemPrompt: String,
        messages: [(role: String, content: String)]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(system: systemPrompt, messages: messages)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        var bodyData = Data()
                        for try await byte in bytes { bodyData.append(byte) }
                        let body = String(data: bodyData, encoding: .utf8) ?? "<non-UTF-8 error body>"
                        if http.statusCode == 429 {
                            continuation.finish(throwing: AnthropicError.rateLimited)
                        } else {
                            continuation.finish(throwing: AnthropicError.httpError(http.statusCode, body))
                        }
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }

                        guard let data = payload.data(using: .utf8),
                              let event = try? JSONDecoder().decode(SSEEvent.self, from: data) else { continue }

                        if let err = event.error {
                            continuation.finish(throwing: AnthropicError.httpError(0, err.message))
                            return
                        }
                        if event.type == "content_block_delta", let text = event.delta?.text {
                            continuation.yield(text)
                        }
                        if event.type == "message_stop" { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Request builder

    private func buildRequest(
        system: String,
        messages: [(role: String, content: String)]
    ) throws -> URLRequest {
        let useBackend = !Config.backendURL.isEmpty && !Config.appSecret.isEmpty
        let url = useBackend
            ? URL(string: "\(Config.backendURL)/api/chat")!
            : directEndpoint

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        if useBackend {
            req.setValue(Config.appSecret, forHTTPHeaderField: "x-app-secret")
        } else {
            // Dev fallback — direct Anthropic call
            let key = Config.anthropicAPIKey
            guard !key.isEmpty else { throw AnthropicError.missingAPIKey }
            req.setValue(key,          forHTTPHeaderField: "x-api-key")
            req.setValue(apiVersion,   forHTTPHeaderField: "anthropic-version")
        }

        let payload = ClaudeRequest(
            model: model,
            maxTokens: maxTokens,
            system: system,
            messages: messages.map { ClaudeMessage(role: $0.role, content: $0.content) },
            stream: true
        )
        req.httpBody = try JSONEncoder().encode(payload)
        return req
    }
}
