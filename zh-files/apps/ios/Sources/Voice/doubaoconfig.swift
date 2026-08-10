//
//  DoubaoConfig.swift
//  OpenClaw
//
//  Doubao (Volcano Engine) speech configuration.
//  Single API Key auth (X-Api-Key), the ClawTalk-verified mode.
//

import Foundation

/// Doubao / Volcano Engine speech credentials.
///
/// Both TTS and ASR use the V3 WebSocket APIs authenticated with a single
/// speech console API Key (`X-Api-Key` header), the same integration
/// verified in the ClawTalk client:
///  - TTS: wss://openspeech.bytedance.com/api/v3/tts/unidirectional/stream
///  - ASR: wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async
enum DoubaoConfig {
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

    /// Whether the speech console API Key is configured.
    static var isConfigured: Bool {
        !apiKey.isEmpty
    }

    // MARK: - Endpoints (ClawTalk-verified)

    static let ttsEndpoint = URL(string: "wss://openspeech.bytedance.com/api/v3/tts/unidirectional/stream")!
    static let asrEndpoint = URL(string: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async")!
    static let ttsResourceID = "seed-tts-2.0"
    static let asrResourceID = "volc.seedasr.sauc.duration"
}
