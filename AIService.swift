import Foundation

enum AIServiceError: LocalizedError {
    case networkError(Error)
    case invalidAPIKey
    case rateLimited
    case serverError(statusCode: Int)
    case invalidResponse
    case emptyResponse
    case apiError(message: String)
    case cancelled

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
        }
    }
}

class AIService {
    private var currentTask: URLSessionDataTask?

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    func rewriteDream(
        original: String,
        tone: String,
        completion: @escaping (Result<String, AIServiceError>) -> Void
    ) {
        // Cancel any existing request
        cancel()

        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

        let prompt = """
        Rewrite the following nightmare using Imagery Rehearsal Therapy.
        Make it \(tone), emotionally safe, calming, and positive.
        Keep it first-person and gentle.

        Nightmare:
        \(original)
        """

        let body: [String: Any] = [
            "model": "x-ai/grok-4-fast",
            "messages": [
                ["role": "system", "content": "You are a therapeutic writing assistant for PTSD and nightmare treatment."],
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

            // Handle cancellation
            if let urlError = error as? URLError, urlError.code == .cancelled {
                completion(.failure(.cancelled))
                return
            }

            // Handle network errors
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    break // Success, continue processing
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
                        // Try to parse error message from response
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

            // Parse response
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(.invalidResponse))
                    return
                }

                // Check for API error in response body
                if let errorObj = json["error"] as? [String: Any],
                   let message = errorObj["message"] as? String {
                    completion(.failure(.apiError(message: message)))
                    return
                }

                // Parse successful response
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
