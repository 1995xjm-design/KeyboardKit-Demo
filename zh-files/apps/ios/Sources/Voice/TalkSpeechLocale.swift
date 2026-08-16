import AVFoundation
import Foundation
import OpenClawKit
import Speech

enum TalkSpeechLocale {
    static let storageKey = "talk.speechLocale"
    static let automaticID = "auto"
    static let fallbackLocaleID = "zh-CN"

    struct Option: Identifiable {
        let id: String
        let label: String
    }

    static func supportedOptions(
        supportedLocales: Set<Locale> = SFSpeechRecognizer.supportedLocales()) -> [Option]
    {
        var seen = Set<String>()
        let dynamic: [Option] = supportedLocales
            .compactMap { locale in
                let id = self.canonicalID(locale.identifier)
                guard seen.insert(id).inserted else { return nil }
                return Option(id: id, label: self.friendlyName(for: locale))
            }
            .sorted { (lhs: Option, rhs: Option) in
                lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
        return [Option(id: self.automaticID, label: String(localized: "Automatic"))] + dynamic
    }

    static func resolvedLocaleID(
        localSelection: String?,
        gatewaySelection: String?,
        deviceLocaleID: String = Locale.autoupdatingCurrent.identifier,
        fallbackLocaleID: String = Self.fallbackLocaleID,
        supportedLocaleIDs: Set<String>) -> String?
    {
        let candidates = [
            TalkConfigParsing.normalizedExplicitSpeechLocaleID(localSelection),
            TalkConfigParsing.normalizedExplicitSpeechLocaleID(gatewaySelection),
            self.canonicalID(deviceLocaleID),
        ]
        for candidate in candidates {
            guard let candidate, !candidate.isEmpty else { continue }
            if let matched = Self.compatibleLocaleID(for: candidate, supportedLocaleIDs: supportedLocaleIDs) {
                return matched
            }
        }
        return supportedLocaleIDs.contains(fallbackLocaleID) ? fallbackLocaleID : nil
    }

    /// Best supported ID for `candidate`: exact match, then script-stripped
    /// (zh-Hans-CN -> zh-CN), then any supported ID sharing the language code.
    private static func compatibleLocaleID(for candidate: String, supportedLocaleIDs: Set<String>) -> String? {
        if supportedLocaleIDs.contains(candidate) {
            return candidate
        }
        if let withoutScript = Self.localeIDByDroppingScript(candidate),
           supportedLocaleIDs.contains(withoutScript) {
            return withoutScript
        }
        guard let languageCode = Locale(identifier: candidate).language.languageCode?.identifier else {
            return nil
        }
        let prefix = languageCode + "-"
        return supportedLocaleIDs
            .filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
            .sorted()
            .first
    }

    private static func localeIDByDroppingScript(_ id: String) -> String? {
        let locale = Locale(identifier: id)
        guard locale.language.script != nil else { return nil }
        var components = [locale.language.languageCode?.identifier].compactMap { $0 }
        if let region = locale.language.region?.identifier {
            components.append(region)
        }
        return components.isEmpty ? nil : components.joined(separator: "-")
    }

    static func resolvedSynthesisLocaleID(
        directiveLanguage: String?,
        localSelection: String?,
        gatewaySelection: String?,
        isVoiceAvailable: (String) -> Bool = TalkSpeechLocale.isSystemVoiceAvailable) -> String?
    {
        // A missing higher-priority voice must not mask a later configured voice.
        // Return nil only after every candidate fails so synthesis uses the device default.
        [directiveLanguage, localSelection, gatewaySelection]
            .compactMap { TalkConfigParsing.normalizedExplicitSpeechLocaleID($0) }
            .first(where: isVoiceAvailable)
    }

    static func isSystemVoiceAvailable(_ localeID: String) -> Bool {
        AVSpeechSynthesisVoice(language: localeID) != nil
    }

    static func makeRecognizer(
        localSelection: String?,
        gatewaySelection: String?,
        supportedLocales: Set<Locale> = SFSpeechRecognizer.supportedLocales()) -> (
        recognizer: SFSpeechRecognizer?,
        localeID: String?)
    {
        let supportedIDs = Set(supportedLocales.map(\.identifier))
        guard let localeID = self.resolvedLocaleID(
            localSelection: localSelection,
            gatewaySelection: gatewaySelection,
            supportedLocaleIDs: supportedIDs)
        else {
            let recognizer = SFSpeechRecognizer()
            return (recognizer, recognizer?.locale.identifier)
        }

        if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)) {
            return (recognizer, localeID)
        }

        let recognizer = SFSpeechRecognizer()
        return (recognizer, recognizer?.locale.identifier)
    }

    private static func canonicalID(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: "-")
    }

    private static func friendlyName(for locale: Locale) -> String {
        let id = self.canonicalID(locale.identifier)
        let cleanLocale = Locale(identifier: id)
        if let langCode = cleanLocale.language.languageCode?.identifier,
           let lang = cleanLocale.localizedString(forLanguageCode: langCode),
           let regionCode = cleanLocale.region?.identifier,
           let region = cleanLocale.localizedString(forRegionCode: regionCode)
        {
            return "\(lang) (\(region))"
        }
        if let langCode = cleanLocale.language.languageCode?.identifier,
           let lang = cleanLocale.localizedString(forLanguageCode: langCode)
        {
            return lang
        }
        return cleanLocale.localizedString(forIdentifier: id) ?? id
    }
}
