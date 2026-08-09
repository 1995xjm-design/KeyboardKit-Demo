//
//  DoubaoConfig.swift
//  OpenClaw
//
//  Doubao (Volcano Engine) speech configuration: TTS + ASR
//  credentials and endpoints.
//

import Foundation

/// Doubao / Volcano Engine speech credentials and endpoints.
///
/// TTS uses the big-model HTTP API (`api/v1/tts`, token auth).
/// ASR uses the big-model streaming WebSocket API
/// (`api/v3/sauc/bigmodel/recognize`, token auth).
enum DoubaoConfig {
    static let appIDKey = "talk.doubao.appid"
    static let tokenKey = "talk.doubao.token"
    static let apiKeyKey = "talk.doubao.apiKey"
    static let voiceTypeKey = "talk.doubao.voiceType"
    static let asrLanguageKey = "talk.doubao.asrLanguage"

    /// Default big-model voice: 月月（万趣大叔）.
    static let defaultVoiceType = "zh_female_wanqudashu_moon_bigtts"
    static let defaultASRLanguage = "zh-CN"

    /// Tag used by the settings picker for a manually entered voice ID.
    static let customVoiceTag = "__custom__"

    /// Preset big-model voices shown in the settings picker.
    struct DoubaoVoicePreset: Identifiable, Hashable {
        let name: String
        let id: String

        var voiceTypeID: String { id }
    }

    static let presetVoices: [DoubaoVoicePreset] = [
        DoubaoVoicePreset(name: "鸡汤妹妹2.0", id: "zh_female_jitangmei_uranus_bigtts"),
        DoubaoVoicePreset(name: "小何2.0", id: "zh_female_xiaohe_uranus_bigtts"),
        DoubaoVoicePreset(name: "Tina老师2.0", id: "zh_female_yingyujiaoxue_uranus_bigtts"),
        DoubaoVoicePreset(name: "魅力女友2.0", id: "zh_female_meilinvyou_uranus_bigtts"),
        DoubaoVoicePreset(name: "月月（万趣大叔）", id: "zh_female_wanqudashu_moon_bigtts"),
    ]

    /// Whether a voice type is one of the presets.
    static func isPresetVoice(_ voiceType: String) -> Bool {
        presetVoices.contains { $0.id == voiceType }
    }

    static let ttsEndpoint = URL(string: "https://openspeech.bytedance.com/api/v1/tts")!
    static let asrEndpoint = URL(string: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel/recognize")!
    static let asrResourceID = "volc.bigasr.auc"

    static var appID: String {
        get { UserDefaults.standard.string(forKey: appIDKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: appIDKey) }
    }

    static var token: String {
        get { UserDefaults.standard.string(forKey: tokenKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    /// Volcano Ark API Key (single-key mode, X-Api-App-Key auth).
    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: apiKeyKey) }
    }

    static var voiceType: String {
        get {
            let v = UserDefaults.standard.string(forKey: voiceTypeKey) ?? ""
            return v.isEmpty ? defaultVoiceType : v
        }
        set { UserDefaults.standard.set(newValue, forKey: voiceTypeKey) }
    }

    static var asrLanguage: String {
        get {
            let v = UserDefaults.standard.string(forKey: asrLanguageKey) ?? ""
            return v.isEmpty ? defaultASRLanguage : v
        }
        set { UserDefaults.standard.set(newValue, forKey: asrLanguageKey) }
    }

    /// Whether any credential mode is configured: Ark API Key alone,
    /// or the legacy App ID + Access Token pair.
    static var isConfigured: Bool {
        !apiKey.isEmpty || (!appID.isEmpty && !token.isEmpty)
    }
}
