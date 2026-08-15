import CryptoKit
import Foundation
import OSLog
import AVFoundation

/// Edge TTS (Microsoft free TTS) — no API key required.
///
/// Protocol (community-documented, matches the open edge-tts clients):
/// 1. Connect to the Bing readaloud WebSocket with three auth query params:
///    - `TrustedClientToken` (static)
///    - `Sec-MS-GEC` (dynamic SHA256 signature, REQUIRED in the query string;
///      putting it in a header gets 403)
///    - `Sec-MS-GEC-Version` (static)
/// 2. Send a `speech.config` text frame, then an `ssml` text frame.
/// 3. Server streams MP3 audio in binary frames; a `turn.end` text event
///    signals completion. The client cancels only its own connection, so a
///    cancelled synthesis can never kill a later read.
enum EdgeTTSConfig {
    static let endpoint =
        "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1"
    static let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    static let secMSGECVersion = "1-143.0.3650.75"
    /// MP3 at 24 kHz mono — plays directly through AVAudioPlayer.
    static let outputFormat = "audio-24khz-48kbitrate-mono-mp3"
    static let synthesizeTimeoutSeconds: UInt64 = 30
}

/// Edge TTS voices surfaced in the settings picker.
enum EdgeTTSVoice: String, CaseIterable, Identifiable {
    case xiaoxiao = "zh-CN-XiaoxiaoNeural"
    case yunxi = "zh-CN-YunxiNeural"
    case yunyang = "zh-CN-YunyangNeural"
    case yunjian = "zh-CN-YunjianNeural"

    static let storageKey = "talk.edge.voiceSelection"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .xiaoxiao:
            "晓晓 (Xiaoxiao)"
        case .yunxi:
            "云希 (Yunxi)"
        case .yunyang:
            "云扬 (Yunyang)"
        case .yunjian:
            "云健 (Yunjian)"
        }
    }

    static var current: EdgeTTSVoice {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        return EdgeTTSVoice(rawValue: raw) ?? .xiaoxiao
    }

    static func setCurrent(_ voice: EdgeTTSVoice) {
        UserDefaults.standard.set(voice.rawValue, forKey: Self.storageKey)
    }
}

private enum EdgeTTSError: LocalizedError {
    case timeout
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .timeout:
            String(localized: "Edge TTS synthesis timed out")
        case .emptyAudio:
            String(localized: "Edge TTS returned no audio")
        }
    }
}

@MainActor
final class EdgeTTSClient {
    static let shared = EdgeTTSClient()

    private var previewPlayer: AVAudioPlayer?

    private init() {}

    func speakPreview(text: String, completion: @escaping (Bool) -> Void) {
        stopPreview()
        Task { @MainActor in
            do {
                let audio = try await EdgeTTSSynthesizer.synthesize(
                    text: text,
                    voiceId: EdgeTTSVoice.current.id)
                let player = try AVAudioPlayer(data: audio)
                player.prepareToPlay()
                self.previewPlayer = player
                completion(player.play())
            } catch {
                self.previewPlayer = nil
                completion(false)
            }
        }
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }
}

/// Synthesizes one utterance to MP3 over the Edge readaloud WebSocket.
enum EdgeTTSSynthesizer {
    private static let logger = Logger(subsystem: "ai.openclaw", category: "talk.tts.edge")

    static func synthesize(text: String, voiceId: String) async throws -> Data {
        let requestId = UUID().uuidString.uppercased()
        let connectionId = UUID().uuidString.uppercased()

        var urlComponents = URLComponents(string: EdgeTTSConfig.endpoint)!
        urlComponents.queryItems = [
            URLQueryItem(name: "TrustedClientToken", value: EdgeTTSConfig.trustedClientToken),
            URLQueryItem(name: "Sec-MS-GEC", value: Self.generateSecMSGEC()),
            URLQueryItem(name: "Sec-MS-GEC-Version", value: EdgeTTSConfig.secMSGECVersion),
            URLQueryItem(name: "ConnectionId", value: connectionId),
        ]

        let session = URLSession(configuration: .ephemeral)
        let webSocket = session.webSocketTask(with: urlComponents.url!)
        webSocket.resume()
        // Only this connection is torn down; the next utterance starts fresh.
        defer { webSocket.cancel(with: .goingAway, reason: nil) }

        // 1. speech.config — advertises the MP3 output format.
        let configJSON = """
        {"context":{"synthesis":{"audio":{"metadataoptions":\
        {"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},\
        "outputFormat":"\(EdgeTTSConfig.outputFormat)"}}}}
        """
        try await Self.sendTextFrame(
            webSocket,
            path: "speech.config",
            contentType: "application/json; charset=utf-8",
            data: Data(configJSON.utf8),
            requestId: requestId)

        // 2. SSML request. A slightly slower rate and lower pitch make the
        // synthesized speech sound more natural instead of rushed/robotic.
        let ssml =
            "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' " +
            "xml:lang='zh-CN'><voice name='\(voiceId)'>" +
            "<prosody rate='-8%' pitch='-3%'>\(Self.escapeXML(text))</prosody>" +
            "</voice></speak>"
        try await Self.sendTextFrame(
            webSocket,
            path: "ssml",
            contentType: "application/ssml+xml",
            data: Data(ssml.utf8),
            requestId: requestId)

        // 3. Collect streamed MP3 chunks until turn.end (with a hard timeout).
        let audio = try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await Self.collectAudio(webSocket)
            }
            group.addTask {
                try? await Task.sleep(
                    nanoseconds: EdgeTTSConfig.synthesizeTimeoutSeconds * 1_000_000_000)
                throw EdgeTTSError.timeout
            }
            defer { group.cancelAll() }
            let data = try await group.next()!
            return data
        }
        guard !audio.isEmpty else { throw EdgeTTSError.emptyAudio }
        return audio
    }

    private static func collectAudio(_ webSocket: URLSessionWebSocketTask) async throws -> Data {
        var audioData = Data()
        while !Task.isCancelled {
            let message = try await webSocket.receive()
            switch message {
            case .data(let frame):
                audioData.append(Self.extractAudioPayload(from: frame))
            case .string(let text):
                if text.contains("Path:turn.end") {
                    return audioData
                }
                // turn.start / response events carry no audio.
            @unknown default:
                break
            }
        }
        return audioData
    }

    /// Binary frames are: 4-byte message type, 4-byte big-endian length, then a
    /// header block (`Path:audio\r\n...\r\n\r\n`) followed by MP3 bytes.
    private static func extractAudioPayload(from frame: Data) -> Data {
        guard frame.count > 8 else { return Data() }
        let payload = frame.dropFirst(8)
        guard let boundary = payload.range(of: Data("\r\n\r\n".utf8)) else { return Data() }
        return Data(payload[boundary.upperBound...])
    }

    /// Text frames are: type (0x01), big-endian length, then
    /// `Path:<path>\r\nX-RequestId:<uuid>\r\nX-Timestamp:<iso>\r\nContent-Type:<mime>\r\n\r\n<data>`.
    private static func sendTextFrame(
        _ webSocket: URLSessionWebSocketTask,
        path: String,
        contentType: String,
        data: Data,
        requestId: String) async throws
    {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var header = "Path:\(path)\r\nX-RequestId:\(requestId)\r\nX-Timestamp:\(timestamp)\r\n"
        header += "Content-Type:\(contentType)\r\n\r\n"
        var payload = Data(header.utf8)
        payload.append(data)

        var frame = Data()
        frame.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        let length = UInt32(payload.count)
        withUnsafeBytes(of: length.bigEndian) { frame.append(contentsOf: $0) }
        frame.append(payload)
        try await webSocket.send(.data(frame))
    }

    /// `Sec-MS-GEC`: current Unix time converted to Windows FILETIME 100ns
    /// ticks, rounded DOWN to the nearest 5-minute slot (Microsoft changed the
    /// rounding direction in 2026; the old `(t + 300) / 300 * 300` scheme now
    /// returns 403), concatenated with the client token, then SHA256 uppercase
    /// hex.
    private static func generateSecMSGEC() -> String {
        var ticks = Date().timeIntervalSince1970 + 11644473600
        ticks -= ticks.truncatingRemainder(dividingBy: 300)
        ticks *= 10_000_000
        let token = "\(Int64(ticks.rounded()))\(EdgeTTSConfig.trustedClientToken)"
        let digest = SHA256.hash(data: Data(token.utf8))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    private static func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
