import Foundation
import SwiftUI
import Combine
import ImagePlayground

// MARK: - Image Generation Error

enum ImageGenerationError: LocalizedError {
    case notSupported
    case unavailable
    case cancelled
    case unsupportedLanguage
    case creationFailed(String)
    case noImagesGenerated

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Image generation requires iOS 18.4+ with Apple Intelligence."
        case .unavailable:
            return "Image Playground is unavailable. Please ensure Apple Intelligence models are downloaded."
        case .cancelled:
            return "Image generation was cancelled."
        case .unsupportedLanguage:
            return "The text language is not supported for image generation."
        case .creationFailed(let message):
            return "Image creation failed: \(message)"
        case .noImagesGenerated:
            return "No images were generated. Please try again."
        }
    }
}

// MARK: - Image Style

enum DreamImageStyle: String, CaseIterable, Identifiable {
    case animation = "Animation"
    case illustration = "Illustration"
    case sketch = "Sketch"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .animation: return "film"
        case .illustration: return "paintbrush"
        case .sketch: return "pencil.and.outline"
        }
    }

    var description: String {
        switch self {
        case .animation: return "3D animated movie style"
        case .illustration: return "Flat 2D illustration"
        case .sketch: return "Hand-drawn sketch"
        }
    }

    @available(iOS 18.4, *)
    var imagePlaygroundStyle: ImagePlaygroundStyle {
        switch self {
        case .animation: return .animation
        case .illustration: return .illustration
        case .sketch: return .sketch
        }
    }
}

// MARK: - Generated Image

struct GeneratedDreamImage: Identifiable, Codable, Equatable {
    let id: UUID
    let imageData: Data
    let prompt: String
    let style: String
    let sequenceIndex: Int
    let createdAt: Date

    init(imageData: Data, prompt: String, style: DreamImageStyle, sequenceIndex: Int) {
        self.id = UUID()
        self.imageData = imageData
        self.prompt = prompt
        self.style = style.rawValue
        self.sequenceIndex = sequenceIndex
        self.createdAt = Date()
    }

    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}

// MARK: - Image Generation Service

@MainActor
class ImageGenerationService: ObservableObject {
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var generatedImages: [GeneratedDreamImage] = []
    @Published var error: ImageGenerationError?

    private var isCancelled = false
    private var currentTask: Task<Void, Never>?

    /// Check if Image Playground is available
    static var isAvailable: Bool {
        if #available(iOS 18.4, *) {
            return true
        }
        return false
    }

    func cancel() {
        isCancelled = true
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    /// Generate sequence images from a rewritten dream
    @available(iOS 18.4, *)
    func generateSequenceImages(
        from text: String,
        style: DreamImageStyle,
        numberOfImages: Int = 4
    ) async throws -> [GeneratedDreamImage] {
        // Cancel any existing task
        currentTask?.cancel()
        currentTask = nil

        // Small delay to ensure previous resources are released
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second

        isGenerating = true
        isCancelled = false
        progress = 0
        generatedImages = []

        defer { isGenerating = false }

        let scenes = splitIntoScenes(text: text, count: numberOfImages)
        var images: [GeneratedDreamImage] = []

        for (index, scene) in scenes.enumerated() {
            if isCancelled { throw ImageGenerationError.cancelled }

            // Create a fresh ImageCreator for each image to avoid state issues
            let image = try await generateSingleImageWithRetry(
                prompt: scene,
                style: style,
                sequenceIndex: index,
                maxRetries: 2
            )

            images.append(image)
            progress = Double(index + 1) / Double(scenes.count)
            self.generatedImages = images

            // Small delay between images to avoid overwhelming the API
            if index < scenes.count - 1 {
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second
            }
        }

        if images.isEmpty { throw ImageGenerationError.noImagesGenerated }
        return images
    }

    /// Generate a single image with retry logic
    @available(iOS 18.4, *)
    private func generateSingleImageWithRetry(
        prompt: String,
        style: DreamImageStyle,
        sequenceIndex: Int,
        maxRetries: Int
    ) async throws -> GeneratedDreamImage {
        var lastError: Error?

        for attempt in 0...maxRetries {
            if isCancelled { throw ImageGenerationError.cancelled }

            do {
                // Create a fresh ImageCreator for each attempt
                let imageCreator = try await ImageCreator()
                let concept = ImagePlaygroundConcept.text(prompt)
                let imageStream = imageCreator.images(for: [concept], style: style.imagePlaygroundStyle, limit: 1)

                for try await createdImage in imageStream {
                    let uiImage = UIImage(cgImage: createdImage.cgImage)
                    if let imageData = uiImage.pngData() {
                        print("SUCCESS - Prompt: \(prompt)")
                        return GeneratedDreamImage(
                            imageData: imageData,
                            prompt: prompt,
                            style: style,
                            sequenceIndex: sequenceIndex
                        )
                    }
                }
                throw ImageGenerationError.noImagesGenerated
            } catch {
                lastError = error
                print("Image generation attempt \(attempt + 1) failed: \(error)")

                if isCancelled { throw ImageGenerationError.cancelled }

                // Wait before retry (exponential backoff)
                if attempt < maxRetries {
                    let delay = UInt64((attempt + 1) * 1_000_000_000) // 1s, 2s
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw ImageGenerationError.creationFailed(lastError?.localizedDescription ?? "Unknown error after \(maxRetries + 1) attempts")
    }

    /// Generate a single image from a prompt
    @available(iOS 18.4, *)
    func generateSingleImage(
        prompt: String,
        style: DreamImageStyle
    ) async throws -> GeneratedDreamImage {
        // Cancel any existing task
        currentTask?.cancel()
        currentTask = nil

        // Small delay to ensure previous resources are released
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second

        isGenerating = true
        isCancelled = false
        defer { isGenerating = false }

        return try await generateSingleImageWithRetry(
            prompt: prompt,
            style: style,
            sequenceIndex: 0,
            maxRetries: 2
        )
    }

    /// Split dream text into scenes for sequence generation
    private func splitIntoScenes(text: String, count: Int) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count > 0 else { return [convertToScenicPrompt(text)] }

        if sentences.count <= count {
            return sentences.map { convertToScenicPrompt($0) }
        }

        // Group sentences into scenes
        let sentencesPerScene = max(1, sentences.count / count)
        var scenes: [String] = []

        for i in 0..<count {
            let startIndex = i * sentencesPerScene
            let endIndex = (i == count - 1) ? sentences.count : min(startIndex + sentencesPerScene, sentences.count)
            if startIndex < sentences.count {
                let sceneText = sentences[startIndex..<endIndex].joined(separator: ". ")
                scenes.append(convertToScenicPrompt(sceneText))
            }
        }

        return scenes
    }

    /// Convert first-person dream text to a scenic description without people
    /// Image Playground requires a face image to generate people, so we focus on scenery
    private func convertToScenicPrompt(_ text: String) -> String {
        // Extract scenic keywords from the text
        let scenicElements = extractScenicElements(from: text)

        if scenicElements.isEmpty {
            // Fallback to generic peaceful scene
            return "A peaceful dreamscape with soft light and serene atmosphere"
        }

        // Build a scenic prompt from extracted elements
        let prompt = "A dreamy landscape featuring " + scenicElements.joined(separator: ", ")
        return prompt
    }

    /// Extract only scenic/environmental elements from text, removing all human references
    private func extractScenicElements(from text: String) -> [String] {
        let lowercased = text.lowercased()
        var elements: [String] = []

        // Nature elements to look for
        let natureKeywords: [String: String] = [
            "forest": "a mystical forest",
            "tree": "towering trees",
            "trees": "towering trees",
            "garden": "a lush garden",
            "flower": "colorful flowers",
            "flowers": "blooming flowers",
            "ocean": "a vast ocean",
            "sea": "a calm sea",
            "beach": "a sandy beach",
            "wave": "gentle waves",
            "waves": "rolling waves",
            "mountain": "majestic mountains",
            "mountains": "snow-capped mountains",
            "hill": "rolling hills",
            "hills": "green hills",
            "sky": "an expansive sky",
            "cloud": "fluffy clouds",
            "clouds": "drifting clouds",
            "star": "twinkling stars",
            "stars": "a starry night",
            "moon": "a glowing moon",
            "sun": "warm sunlight",
            "sunrise": "a golden sunrise",
            "sunset": "a vibrant sunset",
            "rain": "gentle rain",
            "snow": "softly falling snow",
            "river": "a flowing river",
            "lake": "a serene lake",
            "pond": "a tranquil pond",
            "waterfall": "a cascading waterfall",
            "meadow": "a peaceful meadow",
            "field": "an open field",
            "valley": "a verdant valley",
            "cave": "a mysterious cave",
            "island": "a tropical island",
            "desert": "golden sand dunes",
            "jungle": "a dense jungle",
            "path": "a winding path",
            "road": "a scenic road",
            "bridge": "an arching bridge"
        ]

        // Weather/atmosphere elements
        let atmosphereKeywords: [String: String] = [
            "fog": "misty fog",
            "mist": "ethereal mist",
            "rainbow": "a bright rainbow",
            "storm": "dramatic storm clouds",
            "lightning": "distant lightning",
            "thunder": "stormy skies",
            "wind": "windswept landscapes",
            "aurora": "northern lights",
            "twilight": "twilight glow"
        ]

        // Time of day
        let timeKeywords: [String: String] = [
            "night": "nighttime atmosphere",
            "morning": "early morning light",
            "evening": "evening ambiance",
            "dawn": "the break of dawn",
            "dusk": "dusky twilight"
        ]

        // Places/structures (without people)
        let placeKeywords: [String: String] = [
            "house": "a cozy cottage",
            "home": "a warm dwelling",
            "castle": "a grand castle",
            "tower": "a tall tower",
            "palace": "an ornate palace",
            "temple": "an ancient temple",
            "church": "a peaceful sanctuary",
            "city": "a distant cityscape",
            "village": "a quaint village",
            "room": "a cozy interior",
            "window": "light through a window",
            "door": "an inviting doorway",
            "stairs": "winding stairs",
            "garden": "a blooming garden",
            "park": "a serene park",
            "street": "a quiet street",
            "library": "shelves of books",
            "school": "an old building"
        ]

        // Colors and qualities
        let qualityKeywords: [String: String] = [
            "golden": "golden light",
            "silver": "silver shimmer",
            "blue": "shades of blue",
            "green": "lush greenery",
            "purple": "purple hues",
            "pink": "soft pink tones",
            "red": "warm red accents",
            "white": "pristine white",
            "dark": "mysterious shadows",
            "bright": "bright illumination",
            "warm": "warm glow",
            "cool": "cool tones",
            "peaceful": "peaceful serenity",
            "calm": "calming atmosphere",
            "magical": "magical sparkles",
            "dreamy": "dreamlike quality",
            "soft": "soft lighting",
            "gentle": "gentle ambiance",
            "beautiful": "natural beauty",
            "quiet": "quiet stillness"
        ]

        // Objects
        let objectKeywords: [String: String] = [
            "light": "ethereal light",
            "lantern": "glowing lanterns",
            "candle": "candlelight",
            "fire": "a warm fire",
            "flame": "dancing flames",
            "mirror": "a reflective mirror",
            "book": "old books",
            "key": "an ornate key",
            "clock": "an antique clock",
            "boat": "a drifting boat",
            "ship": "a sailing ship",
            "balloon": "floating balloons",
            "bird": "birds in flight",
            "butterfly": "colorful butterflies",
            "cat": "a curious cat",
            "dog": "a friendly dog",
            "horse": "a majestic horse",
            "fish": "swimming fish",
            "deer": "a gentle deer",
            "rabbit": "a small rabbit",
            "owl": "a wise owl"
        ]

        // Check all keyword categories
        let allKeywords = [natureKeywords, atmosphereKeywords, timeKeywords,
                          placeKeywords, qualityKeywords, objectKeywords]

        var foundElements = Set<String>()

        for keywords in allKeywords {
            for (keyword, scenic) in keywords {
                if lowercased.contains(keyword) && !foundElements.contains(scenic) {
                    foundElements.insert(scenic)
                    elements.append(scenic)
                    if elements.count >= 4 {
                        return elements
                    }
                }
            }
        }

        // If we found very few elements, add some default dreamy qualities
        if elements.count < 2 {
            elements.append("soft ethereal light")
            elements.append("peaceful atmosphere")
        }

        return elements
    }
}

