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
    static let voiceTypeKey = "talk.doubao.voiceType"
    static let asrLanguageKey = "talk.doubao.asrLanguage"

    /// Default big-model voice: 万趣大叔-月月 (natural Chinese narrator).
    static let defaultVoiceType = "zh_female_wanqudashu_moon_bigtts"
    static let defaultASRLanguage = "zh-CN"

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

    /// Whether both credentials are present.
    static var isConfigured: Bool {
        !appID.isEmpty && !token.isEmpty
    }
}
