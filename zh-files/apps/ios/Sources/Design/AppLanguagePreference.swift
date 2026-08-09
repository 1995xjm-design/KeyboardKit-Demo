import Foundation
import SwiftUI

/// In-app UI language selection.
///
/// The app ships `en` + `zh-Hans` localizations (plus more community locales).
/// This preference lets the user override the system language from Settings
/// without touching the device's language list. Changing it takes effect
/// on the next app launch (the process-local `AppleLanguages` override is
/// re-applied at startup so it survives launches).
enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case english = "en"

    static let storageKey = "app.language"

    var id: String { self.rawValue }

    /// Display name shown in the settings list, rendered in its own language.
    var displayName: String {
        switch self {
        case .system: "System"
        case .zhHans: "简体中文"
        case .english: "English"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "globe"
        case .zhHans: "character.book.closed.fill"
        case .english: "character.book.closed.fill"
        }
    }

    /// `AppleLanguages` value used to override the process language
    /// (nil means "follow the system").
    var appleLanguagesValue: String? {
        switch self {
        case .system: nil
        case .zhHans: "zh-Hans"
        case .english: "en"
        }
    }

    static var saved: AppLanguagePreference {
        get {
            let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
            return AppLanguagePreference(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.storageKey)
        }
    }

    /// Applies the saved preference to this process so `Bundle` and
    /// `String(localized:)` resolve against the selected language.
    /// Call once at app startup, before any UI is built.
    static func applySavedPreference() {
        let preference = Self.saved
        guard let language = preference.appleLanguagesValue else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            return
        }
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
    }
}
