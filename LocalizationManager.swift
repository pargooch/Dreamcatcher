import Foundation
import Observation

@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    struct Language: Identifiable, Hashable {
        let code: String
        let name: String
        let nativeName: String
        var id: String { code }
    }

    static let supportedLanguages: [Language] = [
        Language(code: "en", name: "English", nativeName: "English"),
        Language(code: "it", name: "Italian", nativeName: "Italiano"),
        Language(code: "de", name: "German", nativeName: "Deutsch"),
        Language(code: "nl", name: "Dutch", nativeName: "Nederlands"),
        Language(code: "pl", name: "Polish", nativeName: "Polski"),
        Language(code: "es", name: "Spanish", nativeName: "Español"),
        Language(code: "uk", name: "Ukrainian", nativeName: "Українська"),
        Language(code: "el", name: "Greek", nativeName: "Ελληνικά"),
        Language(code: "cs", name: "Czech", nativeName: "Čeština"),
        Language(code: "fr", name: "French", nativeName: "Français"),
        Language(code: "ru", name: "Russian", nativeName: "Русский"),
        Language(code: "ro", name: "Romanian", nativeName: "Română"),
        Language(code: "tr", name: "Turkish", nativeName: "Türkçe"),
        Language(code: "ar", name: "Arabic", nativeName: "العربية"),
        Language(code: "fa", name: "Persian", nativeName: "فارسی"),
    ]

    var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
        }
    }

    private let dictionaries: [String: [String: String]]

    private init() {
        dictionaries = [
            "en": strings_en,
            "it": strings_it,
            "de": strings_de,
            "nl": strings_nl,
            "pl": strings_pl,
            "es": strings_es,
            "uk": strings_uk,
            "el": strings_el,
            "cs": strings_cs,
            "fr": strings_fr,
            "ru": strings_ru,
            "ro": strings_ro,
            "tr": strings_tr,
            "ar": strings_ar,
            "fa": strings_fa,
        ]

        // Check for saved preference
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           Self.supportedLanguages.contains(where: { $0.code == saved }) {
            currentLanguage = saved
        } else {
            // Detect device language using iOS capabilities
            let preferred = Locale.preferredLanguages.first ?? "en"
            let languageCode = Locale(identifier: preferred).language.languageCode?.identifier ?? "en"
            if Self.supportedLanguages.contains(where: { $0.code == languageCode }) {
                currentLanguage = languageCode
            } else {
                currentLanguage = "en"
            }
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
        }
    }

    func localized(_ key: String) -> String {
        dictionaries[currentLanguage]?[key] ?? dictionaries["en"]?[key] ?? key
    }
}

// MARK: - Global Convenience

/// Localize a UI string. Pass format args for strings containing %@, %d, %.0f%%, etc.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = LocalizationManager.shared.localized(key)
    if args.isEmpty { return format }
    return String(format: format, arguments: args)
}
