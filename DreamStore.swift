import Foundation
import Combine

class DreamStore: ObservableObject {
    @Published var dreams: [Dream] = []

    private static let fileName = "dreams.json"

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    init() {
        loadDreams()
    }

    func addDream(_ dream: Dream) {
        dreams.insert(dream, at: 0)
        saveDreams()
    }

    func updateDream(_ dream: Dream) {
        if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
            dreams[index] = dream
            saveDreams()
        }
    }

    func deleteDream(_ dream: Dream) {
        dreams.removeAll { $0.id == dream.id }
        saveDreams()
    }

    private func saveDreams() {
        do {
            let data = try JSONEncoder().encode(dreams)
            try data.write(to: Self.fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("Failed to save dreams: \(error.localizedDescription)")
        }
    }

    private func loadDreams() {
        do {
            let data = try Data(contentsOf: Self.fileURL)
            dreams = try JSONDecoder().decode([Dream].self, from: data)
        } catch {
            // File doesn't exist yet or is corrupted - start with empty array
            dreams = []
        }
    }
}
