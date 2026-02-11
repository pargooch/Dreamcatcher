import Foundation

enum Config {
    /// Reads the OpenRouter API key from a secure location.
    /// Priority: 1) Environment variable, 2) Secrets.plist, 3) Info.plist
    static let openRouterKey: String = {
        // First, try environment variable (useful for CI/CD)
        if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }

        // Second, try Secrets.plist (gitignored)
        if let secretsPath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let secrets = NSDictionary(contentsOfFile: secretsPath),
           let key = secrets["OPENROUTER_API_KEY"] as? String,
           !key.isEmpty {
            return key
        }

        // Third, try Info.plist (for development, should be gitignored)
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String,
           !key.isEmpty {
            return key
        }

        fatalError("Missing OPENROUTER_API_KEY in environment, Secrets.plist, or Info.plist")
    }()

    /// Reads the OpenAI API key for DALL-E image generation (optional).
    /// Priority: 1) Environment variable, 2) Secrets.plist, 3) Info.plist
    static let openAIKey: String? = {
        // First, try environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }

        // Second, try Secrets.plist
        if let secretsPath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let secrets = NSDictionary(contentsOfFile: secretsPath),
           let key = secrets["OPENAI_API_KEY"] as? String,
           !key.isEmpty {
            return key
        }

        // Third, try Info.plist
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !key.isEmpty {
            return key
        }

        return nil
    }()

    /// Check if image generation is available (either via OpenAI or Apple Intelligence)
    static var isImageGenerationAvailable: Bool {
        openAIKey != nil
    }
}
