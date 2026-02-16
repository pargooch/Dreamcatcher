import Foundation
import SwiftUI
import Combine

// MARK: - Image Generation Error

enum ImageGenerationError: LocalizedError {
    case notSupported
    case unavailable
    case cancelled
    case modelNotLoaded
    case creationFailed(String)
    case noImagesGenerated

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Image generation requires Apple Silicon device."
        case .unavailable:
            return "MLX image generation is unavailable. Please ensure the model is downloaded."
        case .cancelled:
            return "Image generation was cancelled."
        case .modelNotLoaded:
            return "MLX model not loaded. Please wait for initialization."
        case .creationFailed(let message):
            return "Image creation failed: \(message)"
        case .noImagesGenerated:
            return "No images were generated. Please try again."
        }
    }
}

// MARK: - Image Style (Maps to MLX styles)

enum DreamImageStyle: String, CaseIterable, Identifiable {
    case comicBook = "Comic Book"
    case popArt = "Pop Art"
    case graphicNovel = "Graphic Novel"
    case lineArt = "Line Art"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .comicBook: return "book.pages"
        case .popArt: return "sparkles.rectangle.stack"
        case .graphicNovel: return "text.book.closed"
        case .lineArt: return "pencil.and.outline"
        }
    }

    var description: String {
        switch self {
        case .comicBook: return "Bold lines, halftone dots, action effects"
        case .popArt: return "Vibrant colors, high contrast, stylized"
        case .graphicNovel: return "Dramatic shadows, strong composition"
        case .lineArt: return "Clean outlines, minimal shading"
        }
    }

    /// Convert to MLX style
    var mlxStyle: MLXImageStyle {
        switch self {
        case .comicBook: return .comicBook
        case .popArt: return .popArt
        case .graphicNovel: return .graphicNovel
        case .lineArt: return .lineArt
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

    /// Initialize from MLX generated image
    init(from mlxImage: GeneratedMLXImage) {
        self.id = mlxImage.id
        self.imageData = mlxImage.imageData
        self.prompt = mlxImage.prompt
        self.style = mlxImage.style
        self.sequenceIndex = mlxImage.sequenceIndex
        self.createdAt = mlxImage.createdAt
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
    @Published var statusMessage: String = ""
    @Published var generatedImages: [GeneratedDreamImage] = []
    @Published var error: ImageGenerationError?
    @Published var isModelLoaded = false

    private var isCancelled = false
    private var currentTask: Task<Void, Never>?
    private let mlxService = MLXImageService.shared

    /// Check if image generation is available (backend when authenticated, MLX when not)
    static var isAvailable: Bool {
        return AuthManager.shared.isAuthenticated || MLXImageService.isAvailable
    }

    init() {
        // Observe MLX service state
        Task {
            await observeMLXService()
        }
    }

    private func observeMLXService() async {
        // Keep model loaded state in sync
        for await _ in mlxService.$isModelLoaded.values {
            self.isModelLoaded = mlxService.isModelLoaded
        }
    }

    /// Load the MLX model
    func loadModel() async throws {
        statusMessage = "Loading MLX model..."
        try await mlxService.loadModel()
        isModelLoaded = true
        statusMessage = ""
    }

    func cancel() {
        isCancelled = true
        mlxService.cancel()
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    /// Generate sequence images from a rewritten dream
    /// When authenticated: fully backend (images generated server-side)
    /// When not authenticated: fully local (AI prompts + MLX rendering)
    func generateSequenceImages(
        from text: String,
        style: DreamImageStyle
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

        defer {
            isGenerating = false
            statusMessage = ""
        }

        if AuthManager.shared.isAuthenticated {
            return try await generateWithBackend(text: text, style: style)
        } else {
            return try await generateLocally(text: text, style: style)
        }
    }

    // MARK: - Backend Image Generation (authenticated)

    private func generateWithBackend(text: String, style: DreamImageStyle) async throws -> [GeneratedDreamImage] {
        // Step 1: Get panel prompts (text descriptions) from backend
        statusMessage = "Creating comic panels..."

        let response = try await BackendService.shared.generateImages(
            prompt: text,
            style: style.rawValue,
            numberOfPanels: 4
        )

        if isCancelled { throw ImageGenerationError.cancelled }

        guard !response.panel_prompts.isEmpty else {
            throw ImageGenerationError.noImagesGenerated
        }

        // Step 2: Render each panel prompt into an image via backend
        var images: [GeneratedDreamImage] = []
        let totalPanels = response.panel_prompts.count

        for (index, panelPrompt) in response.panel_prompts.enumerated() {
            if isCancelled { throw ImageGenerationError.cancelled }

            statusMessage = "Generating image \(index + 1)/\(totalPanels)..."
            progress = Double(index + 1) / Double(totalPanels)

            let imageResponse = try await BackendService.shared.generateImage(prompt: panelPrompt)

            // Decode base64 from image_url (format: "data:image/png;base64,...")
            let imageUrl = imageResponse.image_url
            let cleanBase64 = imageUrl.contains(",")
                ? String(imageUrl.split(separator: ",").last ?? "")
                : imageUrl

            guard let imageData = Data(base64Encoded: cleanBase64, options: .ignoreUnknownCharacters) else {
                print("Failed to decode image at index \(index)")
                continue
            }

            let image = GeneratedDreamImage(
                imageData: imageData,
                prompt: panelPrompt,
                style: style,
                sequenceIndex: index
            )
            images.append(image)
        }

        guard !images.isEmpty else {
            throw ImageGenerationError.noImagesGenerated
        }

        self.generatedImages = images
        return images
    }

    // MARK: - Local Image Generation (not authenticated)

    private func generateLocally(text: String, style: DreamImageStyle) async throws -> [GeneratedDreamImage] {
        // Load MLX model if needed
        if !mlxService.isModelLoaded {
            statusMessage = "Loading MLX model..."
            try await mlxService.loadModel()
        }

        // Phase 1: Generate scene descriptions using local AI
        statusMessage = "Creating comic panels..."
        let aiService = AIService()
        let scenes: [String]

        do {
            let generatedScenes = try await aiService.generateComicScenes(from: text)
            if generatedScenes.isEmpty {
                scenes = generateFallbackScenes(count: 3)
            } else {
                scenes = generatedScenes
            }
        } catch {
            print("AI scene generation failed: \(error), using fallback")
            scenes = generateFallbackScenes(count: 3)
        }

        if isCancelled { throw ImageGenerationError.cancelled }

        // Phase 2: Render images locally using MLX
        statusMessage = "Generating \(scenes.count) images..."
        let mlxImages = try await mlxService.generateComicSequence(
            scenes: scenes,
            style: style.mlxStyle
        )

        let images = mlxImages.map { GeneratedDreamImage(from: $0) }
        self.generatedImages = images

        if images.isEmpty { throw ImageGenerationError.noImagesGenerated }
        return images
    }

    /// Legacy method for backward compatibility (numberOfImages is ignored - AI decides)
    func generateSequenceImages(
        from text: String,
        style: DreamImageStyle,
        numberOfImages: Int
    ) async throws -> [GeneratedDreamImage] {
        // Ignore numberOfImages - AI Visual Director decides based on story
        return try await generateSequenceImages(from: text, style: style)
    }

    /// Generate flat vector style fallback scenes
    private func generateFallbackScenes(count: Int) -> [String] {
        let vectorStyle = "flat vector comic panel, graphic design style, thick black vector outlines, simple geometric shapes, two-dimensional, no depth, no shading, solid flat colors only, high contrast color blocks, clean poster-like composition, bold centered subject, minimal background, symbolic silhouette characters, screen print look, no gradients, no lighting, no texture, no realism, no 3D"

        let fallbacks = [
            "Silhouette figure running through doorway, SMASH! text, yellow and orange background, \(vectorStyle)",
            "Dark shadow shape with lightning bolt, purple and blue color blocks, \(vectorStyle)",
            "Explosion circle with BOOM! text, red and orange shapes, centered composition, \(vectorStyle)",
            "Standing figure with cape, arms raised, POW! text, gold and blue background, \(vectorStyle)",
            "Monster silhouette roaring, CRASH! text, green and black shapes, \(vectorStyle)",
            "Figure landing pose, BAM! text, red and yellow color blocks, \(vectorStyle)"
        ]

        return (0..<count).map { fallbacks[$0 % fallbacks.count] }
    }

    /// Generate a single image from a prompt using MLX
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

        // Check if model is loaded
        if !mlxService.isModelLoaded {
            statusMessage = "Loading MLX model..."
            try await mlxService.loadModel()
        }

        let mlxImage = try await mlxService.generateImage(
            prompt: prompt,
            style: style.mlxStyle,
            sequenceIndex: 0
        )

        return GeneratedDreamImage(from: mlxImage)
    }

    // MARK: - Comic Page Layout

    /// Layout style for combining images into a comic page
    enum ComicLayoutStyle {
        case vertical       // Stacked vertically
        case grid           // Grid layout
        case dynamic        // Varied panel sizes for visual interest
        case widescreen     // Wide horizontal panels
    }

    /// Combine multiple images into a single comic page
    func createComicPage(
        from images: [GeneratedDreamImage],
        style: ComicLayoutStyle = .dynamic,
        pageSize: CGSize = CGSize(width: 1024, height: 1536)
    ) -> UIImage? {
        let uiImages = images.compactMap { $0.uiImage }
        guard !uiImages.isEmpty else { return nil }

        // Use MLX comic panel layout
        let mlxLayoutStyle: MLXComicPanelLayout.LayoutStyle
        switch style {
        case .vertical: mlxLayoutStyle = .vertical
        case .grid: mlxLayoutStyle = .grid
        case .dynamic: mlxLayoutStyle = .dynamic
        case .widescreen: mlxLayoutStyle = .widescreen
        }

        return MLXComicPanelLayout.createComicPage(
            images: uiImages,
            style: mlxLayoutStyle,
            pageSize: pageSize
        )
    }

    // MARK: - Backend Upload

    /// Upload generated images to the backend
    /// Called after images are generated, if user is signed in
    func uploadImagesToBackend(
        images: [GeneratedDreamImage],
        rewrittenDreamId: String,
        style: DreamImageStyle
    ) async throws -> APIVisualization {
        guard AuthManager.shared.isAuthenticated else {
            throw ImageGenerationError.notSupported
        }

        statusMessage = "Uploading to cloud..."

        // Convert images to base64 URLs
        var imageUrls: [String] = []
        for image in images {
            let url = try await BackendService.shared.uploadImage(
                data: image.imageData,
                filename: "panel_\(image.sequenceIndex).png"
            )
            imageUrls.append(url)
        }

        // Create visualization on backend
        let visualization = try await BackendService.shared.createVisualization(
            rewrittenDreamId: rewrittenDreamId,
            visualizationType: "comic_panels",
            imageAssets: imageUrls,
            status: "completed"
        )

        statusMessage = ""
        return visualization
    }

    /// Check if backend upload is available
    var canUploadToBackend: Bool {
        AuthManager.shared.isAuthenticated
    }
}
