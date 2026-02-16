import Foundation

struct APIUser: Codable {
    let _id: String
    let email: String
    let status: String
    let profile: UserProfile?
    let created_at: String
    let updated_at: String
}

struct UserProfile: Codable {
    let gender: String?
    let age: Int?
    let timezone: String?
}

struct AuthResponse: Codable {
    let token: String
    let user: APIUser
}

struct APIDream: Codable {
    let _id: String
    let user_id: String
    let original_text: String
    let title: String?
    let emotional_intensity_score: Int?
    let is_recurring: Bool?
    let archived: Bool?
    let tags: [String]?
    let created_at: String
    let updated_at: String
}

struct APIRewrittenDream: Codable {
    let _id: String
    let dream_id: String
    let mood_type: String
    let rewritten_text: String
    let version_number: Int?
    let user_feedback_score: Int?
    let created_at: String
}

struct APIVisualization: Codable {
    let _id: String
    let rewritten_dream_id: String
    let visualization_type: String
    let panel_structure: PanelStructure?
    let image_assets: [String]?
    let status: String
    let created_at: String
}

struct PanelStructure: Codable {
    let panelCount: Int
    let panels: [Panel]?
}

struct Panel: Codable {
    let panel: Int
    let storyPart: String?
    let prompt: String?
}

struct AIModel: Codable {
    let id: String
    let name: String
    let provider: String?
    let description: String?
}

enum BackendError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case noData
    case unauthorized
    case conflict(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return message ?? "Server error (HTTP \(statusCode))"
        case .decodingError:
            return "Failed to decode server response"
        case .noData:
            return "Server returned no data"
        case .unauthorized:
            return "Unauthorized request"
        case .conflict(let message):
            return message
        case .notFound(let message):
            return message
        }
    }
}

