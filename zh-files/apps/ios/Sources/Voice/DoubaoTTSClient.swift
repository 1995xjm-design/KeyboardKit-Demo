//
//  DoubaoTTSClient.swift
//  OpenClaw
//
//  Doubao (Volcano Engine) big-model TTS via the HTTP V1 API.
//  Auth: "Bearer; <access_token>" header, body carries appid.
//

import Foundation

struct DoubaoTTSResult: Decodable {
    let code: Int?
    let message: String?
    let data: [DoubaoTTSChunk]?

    var isSuccess: Bool { (code ?? 0) == 3000 }
}

struct DoubaoTTSChunk: Decodable {
    let audio: String?
    let index: Int?
    let addition: String?
}

enum DoubaoTTSClientError: LocalizedError {
    case notConfigured
    case httpStatus(Int)
    case apiError(Int, String)
    case emptyAudio
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Doubao TTS is not configured"
        case .httpStatus(let code): "Doubao TTS HTTP \(code)"
        case .apiError(let code, let message): "Doubao TTS error \(code): \(message)"
        case .emptyAudio: "Doubao TTS returned empty audio"
        case .invalidResponse: "Doubao TTS returned an invalid response"
        }
    }
}

/// Synthesizes text with the Doubao big-model TTS HTTP API.
struct DoubaoTTSClient {
    let appID: String
    let token: String
    let voiceType: String

    init(appID: String, token: String, voiceType: String = DoubaoConfig.defaultVoiceType) {
        self.appID = appID
        self.token = token
        self.voiceType = voiceType
    }

    /// Synthesizes text into a complete audio file (MP3 by default).
    func synthesize(text: String) async throws -> Data {
        let reqid = UUID().uuidString
        let body: [String: Any] = [
            "app": [
                "appid": appID,
                "token": token,
                "cluster": "volcano_tts",
            ],
            "user": [
                "uid": "openclaw-ios",
            ],
            "audio": [
                "voice_type": voiceType,
                "encoding": "mp3",
                "rate": 24000,
                "speed_ratio": 1.0,
            ],
            "request": [
                "reqid": reqid,
                "text": text,
                "operation": "query",
            ],
        ]

        var request = URLRequest(url: DoubaoConfig.ttsEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer; \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DoubaoTTSClientError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw DoubaoTTSClientError.httpStatus(http.statusCode)
        }

        let result = try JSONDecoder().decode(DoubaoTTSResult.self, from: data)
        guard result.isSuccess else {
            throw DoubaoTTSClientError.apiError(
                result.code ?? -1,
                result.message ?? "unknown")
        }

        // Big-model TTS returns audio in chunks; concatenate all base64 chunks.
        var audio = Data()
        if let chunks = result.data {
            for chunk in chunks {
                if let b64 = chunk.audio, let chunkData = Data(base64Encoded: b64) {
                    audio.append(chunkData)
                }
            }
        }
        // Fallback: some responses carry audio directly under "audio".
        if audio.isEmpty {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let b64 = obj["audio"] as? String,
               let direct = Data(base64Encoded: b64)
            {
                audio = direct
            }
        }
        guard !audio.isEmpty else {
            throw DoubaoTTSClientError.emptyAudio
        }
        return audio
    }
}

/// Adapts `DoubaoTTSClient` to the gateway speech synthesizing protocol,
/// so talk replies can be voiced directly by Doubao without the gateway.
@MainActor
final class DoubaoTTSGatewaySynthesizer: TalkGatewaySpeechSynthesizing {
    private let client: DoubaoTTSClient

    init(client: DoubaoTTSClient) {
        self.client = client
    }

    convenience init?() {
        guard DoubaoConfig.isConfigured else { return nil }
        self.init(client: DoubaoTTSClient(
            appID: DoubaoConfig.appID,
            token: DoubaoConfig.token,
            voiceType: DoubaoConfig.voiceType))
    }

    func synthesize(_ request: TalkGatewaySpeechRequest) async throws -> TalkGatewaySpeechAudio {
        let text = request.text
        let data = try await client.synthesize(text: text)
        return TalkGatewaySpeechAudio(
            data: data,
            provider: "doubao",
            outputFormat: "mp3")
    }
}
