//
//  DoubaoTTSClient.swift
//  OpenClaw
//
//  Doubao (Volcano Engine) big-model TTS via the V3 unidirectional
//  streaming WebSocket API — the ClawTalk-verified integration.
//
//  URL: wss://openspeech.bytedance.com/api/v3/tts/unidirectional/stream
//  Auth: X-Api-Key (speech console API Key) + X-Api-Resource-Id
//  Request frame: [0x11,0x10,0x10,0x00] + uint32 BE len + JSON
//  Response: PCM s16le 24kHz mono frames (msgType 0b1011 audio).
//

import AVFoundation
import Foundation

enum DoubaoTTSClientError: LocalizedError {
    case notConfigured
    case serverError(UInt32, String)
    case serverMessage(String)
    case malformedFrame
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Doubao TTS is not configured"
        case .serverError(let code, let message): "Doubao TTS error \(code): \(message)"
        case .serverMessage(let message): "Doubao TTS server: \(message)"
        case .malformedFrame: "Doubao TTS returned a malformed frame"
        case .emptyAudio: "Doubao TTS returned empty audio"
        }
    }
}

/// Synthesizes text with the Doubao big-model TTS V3 WebSocket API.
/// Returns the complete PCM s16le 24kHz mono audio.
struct DoubaoTTSClient {
    let apiKey: String
    let voiceType: String
    let sampleRate: Int

    init(
        apiKey: String,
        voiceType: String = DoubaoConfig.defaultVoiceType,
        sampleRate: Int = 24000)
    {
        self.apiKey = apiKey
        self.voiceType = voiceType
        self.sampleRate = sampleRate
    }

    /// Synthesizes text into complete PCM audio (s16le 24kHz mono).
    func synthesize(text: String) async throws -> Data {
        var request = URLRequest(url: DoubaoConfig.ttsEndpoint)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue(DoubaoConfig.ttsResourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        task.resume()

        let payload: [String: Any] = [
            "user": ["uid": "openclaw-ios"],
            "req_params": [
                "text": text,
                "speaker": voiceType,
                "audio_params": ["format": "pcm", "sample_rate": sampleRate],
            ],
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        var frame = Data([0x11, 0x10, 0x10, 0x00])
        var payloadLen = UInt32(jsonData.count).bigEndian
        frame.append(Data(bytes: &payloadLen, count: 4))
        frame.append(jsonData)

        try await task.send(.data(frame))

        var audio = Data()
        var finished = false
        var receivedError: Error?

        while !finished, receivedError == nil {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await task.receive()
            } catch {
                // Server closes after the final result; treat as normal end
                // if we already have audio.
                if !audio.isEmpty {
                    break
                }
                receivedError = error
                break
            }
            switch message {
            case .data(let data):
                do {
                    if try Self.parseFrame(data, audio: &audio) {
                        finished = true
                    }
                } catch {
                    receivedError = error
                }
            case .string(let string):
                receivedError = DoubaoTTSClientError.serverMessage(string)
            @unknown default:
                break
            }
        }
        task.cancel(with: .goingAway, reason: nil)

        if let receivedError {
            throw receivedError
        }
        guard !audio.isEmpty else {
            throw DoubaoTTSClientError.emptyAudio
        }
        return audio
    }

    /// Parses one TTS response frame, appending audio payloads.
    private static func parseFrame(
        _ data: Data,
        audio: inout Data) throws -> Bool
    {
        guard data.count >= 4 else { throw DoubaoTTSClientError.malformedFrame }
        let msgType = (data[1] >> 4) & 0x0F
        var offset = 4

        // Error frame: uint32 code + uint32 len + body
        if msgType == 0b1111 {
            guard data.count >= offset + 8 else { throw DoubaoTTSClientError.malformedFrame }
            let code = data.subdata(in: offset..<offset + 4)
                .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
            offset += 4
            let bodyLen = Int(data.subdata(in: offset..<offset + 4)
                .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian })
            offset += 4
            guard data.count >= offset + bodyLen else { throw DoubaoTTSClientError.malformedFrame }
            let body = String(data: data.subdata(in: offset..<offset + bodyLen), encoding: .utf8) ?? ""
            throw DoubaoTTSClientError.serverError(code, body)
        }

        guard data.count >= offset + 4 else { throw DoubaoTTSClientError.malformedFrame }
        let event = data.subdata(in: offset..<offset + 4)
            .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        offset += 4

        // session id: uint32 len + bytes
        guard data.count >= offset + 4 else { throw DoubaoTTSClientError.malformedFrame }
        let sidLen = Int(data.subdata(in: offset..<offset + 4)
            .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian })
        offset += 4
        guard data.count >= offset + sidLen + 4 else { throw DoubaoTTSClientError.malformedFrame }
        offset += sidLen

        guard data.count >= offset + 4 else { throw DoubaoTTSClientError.malformedFrame }
        let payloadLen = Int(data.subdata(in: offset..<offset + 4)
            .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian })
        offset += 4
        guard data.count >= offset + payloadLen else { throw DoubaoTTSClientError.malformedFrame }
        let payload = data.subdata(in: offset..<offset + payloadLen)

        if msgType == 0b1011, !payload.isEmpty {
            audio.append(payload)
        }

        // 152 = SessionFinished, 52 = ConnectionFinished
        return event == 152 || event == 52
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
            apiKey: DoubaoConfig.apiKey,
            voiceType: DoubaoConfig.voiceType))
    }

    func synthesize(_ request: TalkGatewaySpeechRequest) async throws -> TalkGatewaySpeechAudio {
        let text = request.text
        let data = try await client.synthesize(text: text)
        return TalkGatewaySpeechAudio(
            data: data,
            provider: "doubao",
            outputFormat: "pcm_24000")
    }
}
