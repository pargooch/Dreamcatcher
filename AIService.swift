import Foundation
import FoundationModels

// MARK: - AI Service Error

enum AIServiceError: LocalizedError {
    case networkError(Error)
    case invalidAPIKey
    case rateLimited
    case serverError(statusCode: Int)
    case invalidResponse
    case emptyResponse
    case apiError(message: String)
    case cancelled
    case notSupported

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidAPIKey:
            return "Invalid API key. Please check your OpenRouter API key."
        case .rateLimited:
            return "Rate limited. Please wait a moment and try again."
        case .serverError(let statusCode):
            return "Server error (HTTP \(statusCode)). Please try again later."
        case .invalidResponse:
            return "Invalid response from AI service."
        case .emptyResponse:
            return "AI returned an empty response. Please try again."
        case .apiError(let message):
            return "API error: \(message)"
        case .cancelled:
            return "Request was cancelled."
        case .notSupported:
            return "On-device AI requires iOS 26+ with Apple Intelligence."
        }
    }
}

// MARK: - AI Provider

enum AIProvider {
    case appleFoundationModels  // On-device, free, private (iOS 26+)
    case openRouter             // Cloud API (requires API key)
}

// MARK: - AI Service

class AIService {
    private var currentTask: URLSessionDataTask?

    /// Check if Apple Foundation Models is available
    @available(iOS 26.0, *)
    static var isOnDeviceAvailable: Bool {
        let model = SystemLanguageModel.default
        if case .available = model.availability {
            return true
        }
        return false
    }

    /// Check availability with fallback for older iOS
    static var canUseOnDevice: Bool {
        if #available(iOS 26.0, *) {
            return isOnDeviceAvailable
        }
        return false
    }

    /// Get the current AI provider
    static var currentProvider: AIProvider {
        if canUseOnDevice {
            return .appleFoundationModels
        }
        return .openRouter
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    func rewriteDream(
        original: String,
        tone: String,
        completion: @escaping (Result<String, AIServiceError>) -> Void
    ) {
        if #available(iOS 26.0, *), Self.isOnDeviceAvailable {
            rewriteWithFoundationModels(original: original, tone: tone, completion: completion)
        } else {
            rewriteWithOpenRouter(original: original, tone: tone, completion: completion)
        }
    }

    // MARK: - Foundation Models Implementation

    @available(iOS 26.0, *)
    private func rewriteWithFoundationModels(
        original: String,
        tone: String,
        completion: @escaping (Result<String, AIServiceError>) -> Void
    ) {
        Task {
            do {
                let session = LanguageModelSession(
                    instructions: """
                    You are a creative writing assistant that transforms stories.
                    Your role is to rewrite narratives into peaceful, positive versions.
                    """
                )

                let prompt = """
                Transform this dream story into a \(tone), peaceful, and uplifting version.
                Keep it in first-person perspective. Make the ending safe and comforting.
                Focus on feelings of safety, warmth, and joy.

                Original story:
                \(original)
                """

                let response = try await session.respond(to: prompt)
                let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

                if content.isEmpty {
                    completion(.failure(.emptyResponse))
                } else {
                    completion(.success(content))
                }
            } catch {
                completion(.failure(.apiError(message: error.localizedDescription)))
            }
        }
    }

    // MARK: - OpenRouter Implementation

    private func rewriteWithOpenRouter(
        original: String,
        tone: String,
        completion: @escaping (Result<String, AIServiceError>) -> Void
    ) {
        cancel()

        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

        let prompt = """
        Transform this dream story into a \(tone), peaceful, and uplifting version.
        Keep it in first-person perspective. Make the ending safe and comforting.
        Focus on feelings of safety, warmth, and joy.

        Original story:
        \(original)
        """

        let body: [String: Any] = [
            "model": "x-ai/grok-4-fast",
            "messages": [
                ["role": "system", "content": "You are a creative writing assistant that transforms stories into peaceful, positive versions."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Config.openRouterKey)", forHTTPHeaderField: "Authorization")
        request.addValue("Dreamcatcher", forHTTPHeaderField: "X-Title")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.invalidResponse))
            return
        }

        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.currentTask = nil }

            if let urlError = error as? URLError, urlError.code == .cancelled {
                completion(.failure(.cancelled))
                return
            }

            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    break
                case 401:
                    completion(.failure(.invalidAPIKey))
                    return
                case 429:
                    completion(.failure(.rateLimited))
                    return
                case 500...599:
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                    return
                default:
                    if httpResponse.statusCode != 200 {
                        if let data = data,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorObj = json["error"] as? [String: Any],
                           let message = errorObj["message"] as? String {
                            completion(.failure(.apiError(message: message)))
                            return
                        }
                        completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                        return
                    }
                }
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(.invalidResponse))
                    return
                }

                if let errorObj = json["error"] as? [String: Any],
                   let message = errorObj["message"] as? String {
                    completion(.failure(.apiError(message: message)))
                    return
                }

                guard let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion(.failure(.invalidResponse))
                    return
                }

                let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedContent.isEmpty {
                    completion(.failure(.emptyResponse))
                    return
                }

                completion(.success(trimmedContent))
            } catch {
                completion(.failure(.invalidResponse))
            }
        }

        currentTask?.resume()
    }
}

