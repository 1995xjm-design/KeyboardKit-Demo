//
//  APIKeyStore.swift
//  Demo
//
//  Shared API configuration store used by both the main app
//  and the keyboard extension. Values are persisted in the
//  App Group so a key entered in the app is picked up by the
//  keyboard. As a fallback for sideloaded installs where the
//  App Group may not be provisioned, saving also writes the
//  values to the pasteboard.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Stores the user-configured API connection values (base
/// URL, API key and model name) in shared storage.
class APIKeyStore {

    static let shared = APIKeyStore()

    private static let baseURLKey = "api.baseURL"
    private static let apiKeyKey = "api.apiKey"
    private static let modelKey = "api.model"

    /// Defaults matching the built-in DeepSeek configuration.
    static let defaultBaseURL = "https://api.deepseek.com"
    static let defaultModel = "deepseek-chat"

    private let defaults: UserDefaults

    private init() {
        if let shared = UserDefaults(suiteName: AppConstants.appGroupId) {
            defaults = shared
        } else {
            defaults = .standard
        }
    }

    var baseURL: String {
        get { defaults.string(forKey: Self.baseURLKey) ?? Self.defaultBaseURL }
        set { defaults.set(newValue, forKey: Self.baseURLKey) }
    }

    var apiKey: String {
        get { defaults.string(forKey: Self.apiKeyKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.apiKeyKey) }
    }

    var model: String {
        get { defaults.string(forKey: Self.modelKey) ?? Self.defaultModel }
        set { defaults.set(newValue, forKey: Self.modelKey) }
    }

    var hasConfiguredAPI: Bool { !apiKey.isEmpty }

    /// Persists all values and writes a pasteboard fallback so
    /// a sideloaded keyboard can read the configuration even
    /// when the App Group isn't provisioned.
    func save(baseURL: String, apiKey: String, model: String) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        writePasteboardFallback()
    }

    /// Reads a pasteboard fallback written by the main app when
    /// the App Group values are missing.
    func readPasteboardFallbackIfNeeded() {
        #if canImport(UIKit)
        guard apiKey.isEmpty,
              let raw = UIPasteboard.general.string,
              let data = raw.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              payload["kkApiConfig"] == "true"
        else { return }
        if let value = payload["baseURL"], !value.isEmpty { baseURL = value }
        if let value = payload["apiKey"], !value.isEmpty { apiKey = value }
        if let value = payload["model"], !value.isEmpty { model = value }
        #endif
    }

    /// Writes the current configuration to the pasteboard.
    func writePasteboardFallback() {
        #if canImport(UIKit)
        let payload: [String: String] = [
            "kkApiConfig": "true",
            "baseURL": baseURL,
            "apiKey": apiKey,
            "model": model
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8)
        else { return }
        UIPasteboard.general.string = json
        #endif
    }
}