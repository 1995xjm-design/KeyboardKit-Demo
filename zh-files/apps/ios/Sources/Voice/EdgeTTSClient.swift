import CryptoKit
import Foundation
import OSLog
import AVFoundation

/// Edge TTS (Microsoft free TTS) — no API key required.
///
/// Protocol (community-documented, matches the open edge-tts clients):
/// 1. Connect to the Bing readaloud WebSocket via `URLRequest` +
///    `session.webSocketTask(with: request)` with browser headers (`Origin`,
///    `User-Agent`, `Pragma`, `Cache-Control`, `Cookie`) and four auth query
///    params:
///    - `TrustedClientToken` (static)
///    - `Sec-MS-GEC` (dynamic SHA256 signature, REQUIRED in the query string;
///      putting it in a header gets 403)
///    - `Sec-MS-GEC-Version` (static)
///    - `ConnectionId` (UUID without dashes)
/// 2. Send a `speech.config` text frame, then an `ssml` text frame.
/// 3. Server streams MP3 audio in binary frames (first 2 bytes big-endian =
///    header length, then the header block, then the MP3 payload); a `turn.end`
///    text event signals completion.
/// 4. Output: MP3 (24 kHz 48 kbps mono) — plays directly through AVAudioPlayer.
enum EdgeTTSConfig {
    static let endpoint =
        "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1"
    static let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    static let secMSGECVersion = "1-143.0.3650.75"
    /// Same Chrome/Edge UA as the verified ClawTalk client.
    static let userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0"
    /// MP3 at 24 kHz mono — plays directly through AVAudioPlayer.
    static let outputFormat = "audio-24khz-48kbitrate-mono-mp3"
    static let synthesizeTimeoutSeconds: UInt64 = 30
}

/// Edge TTS voices surfaced in the settings picker.
enum EdgeTTSVoice: String, CaseIterable, Identifiable {
    case xiaoxiao = "zh-CN-XiaoxiaoNeural"
    case xiaoyi = "zh-CN-XiaoyiNeural"
    case yunxi = "zh-CN-YunxiNeural"
    case yunyang = "zh-CN-YunyangNeural"
    case yunjian = "zh-CN-YunjianNeural"
    case yunxia = "zh-CN-YunxiaNeural"
    case hiuMaan = "zh-HK-HiuMaanNeural"
    case wanLung = "zh-HK-WanLungNeural"
    case hiuGaai = "zh-HK-HiuGaaiNeural"
    case hsiaoChen = "zh-TW-HsiaoChenNeural"

    static let storageKey = "talk.edge.voiceSelection"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .xiaoxiao:
            "晓晓（女）"
        case .xiaoyi:
            "小艺（女）"
        case .yunxi:
            "云希（男）"
        case .yunyang:
            "云扬（男）"
        case .yunjian:
            "云健（男）"
        case .yunxia:
            "云夏（女）"
        case .hiuMaan:
            "晓曼（粤语·女）"
        case .wanLung:
            "云龙（粤语·男）"
        case .hiuGaai:
            "晓佳（粤语·女）"
        case .hsiaoChen:
            "晓臻（台湾·女）"
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

    func speakPreview(
        text: String,
        speed: Int = 0,
        pitch: Int = 0,
        completion: @escaping (Bool) -> Void)
    {
        stopPreview()
        Task { @MainActor in
            do {
                let audio = try await EdgeTTSSynthesizer.synthesize(
                    text: text,
                    voiceId: EdgeTTSVoice.current.id,
                    speed: speed,
                    pitch: pitch)
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

    static func synthesize(
        text: String,
        voiceId: String,
        speed: Int = 0,
        pitch: Int = 0) async throws -> Data
    {
        let requestId = Self.connectionID()
        let connectionId = Self.connectionID()

        var urlComponents = URLComponents(string: EdgeTTSConfig.endpoint)!
        urlComponents.queryItems = [
            URLQueryItem(name: "TrustedClientToken", value: EdgeTTSConfig.trustedClientToken),
            URLQueryItem(name: "Sec-MS-GEC", value: Self.generateSecMSGEC()),
            URLQueryItem(name: "Sec-MS-GEC-Version", value: EdgeTTSConfig.secMSGECVersion),
            URLQueryItem(name: "ConnectionId", value: connectionId),
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue("https://edge.microsoft.com", forHTTPHeaderField: "Origin")
        request.setValue(EdgeTTSConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("muid=\(connectionId.uppercased());", forHTTPHeaderField: "Cookie")

        let session = URLSession(configuration: .ephemeral)
        let webSocket = session.webSocketTask(with: request)
        webSocket.resume()
        // Only this connection is torn down; the next utterance starts fresh.
        defer { webSocket.cancel(with: .goingAway, reason: nil) }

        // 1. speech.config — advertises the MP3 output format.
        try await webSocket.send(.string(Self.speechConfigFrame()))

        // 2. SSML request with the caller's speed/pitch applied to <prosody>.
        try await webSocket.send(
            .string(Self.ssmlFrame(
                text: text,
                voiceID: voiceId,
                requestID: requestId,
                speed: speed,
                pitch: pitch)))

        // 3. Collect streamed MP3 chunks until turn.end (with a hard timeout).
        let audio = try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await Self.collectAudio(webSocket)
            }
            group.addTask {
                do {
                    try await Task.sleep(
                        nanoseconds: EdgeTTSConfig.synthesizeTimeoutSeconds * 1_000_000_000)
                } catch {
                    // Cancelled because audio finished first — not a timeout.
                    return Data()
                }
                throw EdgeTTSError.timeout
            }
            defer { group.cancelAll() }
            let data = try await group.next()!
            return data
        }
        guard !audio.isEmpty else { throw EdgeTTSError.emptyAudio }
        return audio
    }

    // MARK: - Frame helpers

    private static func collectAudio(_ webSocket: URLSessionWebSocketTask) async throws -> Data {
        var audioData = Data()
        while !Task.isCancelled {
            let message = try await webSocket.receive()
            switch message {
            case .data(let frame):
                if let payload = Self.extractAudioPayload(from: frame) {
                    audioData.append(payload)
                }
            case .string(let text):
                if text.contains("turn.end") {
                    return audioData
                }
                // turn.start / response events carry no audio.
            @unknown default:
                break
            }
        }
        return audioData
    }

    /// Binary frames are: 2-byte big-endian header length, then the header block
    /// (`Path:audio\r\n...\r\n\r\n`), then the MP3 payload.
    private static func extractAudioPayload(from frame: Data) -> Data? {
        guard frame.count >= 2 else { return nil }
        let headerLength = (Int(frame[0]) << 8) | Int(frame[1])
        guard frame.count >= 2 + headerLength else { return nil }
        return frame.subdata(in: (2 + headerLength)..<frame.count)
    }

    private static func speechConfigFrame() -> String {
        let config = "{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":" +
            "{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"}," +
            "\"outputFormat\":\"\(EdgeTTSConfig.outputFormat)\"}}}}"
        return "X-Timestamp:\(Self.timestampString())\r\n" +
            "Content-Type:application/json; charset=utf-8\r\n" +
            "Path:speech.config\r\n\r\n" + config
    }

    private static func ssmlFrame(
        text: String,
        voiceID: String,
        requestID: String,
        speed: Int,
        pitch: Int) -> String
    {
        let escaped = Self.escapeXML(Self.sanitize(text))
        let rate = speed >= 0 ? "+\(speed)%" : "\(speed)%"
        let pitchValue = pitch >= 0 ? "+\(pitch)Hz" : "\(pitch)Hz"
        let ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>" +
            "<voice name='\(voiceID)'><prosody pitch='\(pitchValue)' rate='\(rate)' volume='+0%'>" +
            "\(escaped)</prosody></voice></speak>"
        // 注意：X-Timestamp 末尾的 Z 是微软接口的已知行为（edge-tts 注释 "This is not a mistake"），照抄
        return "X-RequestId:\(requestID)\r\n" +
            "Content-Type:application/ssml+xml\r\n" +
            "X-Timestamp:\(Self.timestampString())Z\r\n" +
            "Path:ssml\r\n\r\n" + ssml
    }

    // MARK: - Auth

    /// `Sec-MS-GEC`: current Unix time converted to Windows FILETIME 100ns
    /// ticks, rounded DOWN to the nearest 5-minute slot, concatenated with the
    /// client token, then SHA256 uppercase hex.
    private static func generateSecMSGEC() -> String {
        var ticks = Date().timeIntervalSince1970 + 11_644_473_600.0
        ticks -= ticks.truncatingRemainder(dividingBy: 300)
        let hashInput = "\(Int64(ticks * 10_000_000))\(EdgeTTSConfig.trustedClientToken)"
        let digest = SHA256.hash(data: Data(hashInput.utf8))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    /// Matches edge-tts' date_to_string()
    /// (%a %b %d %Y %H:%M:%S GMT+0000 (Coordinated Universal Time)).
    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT+0000 (Coordinated Universal Time)'"
        return formatter.string(from: Date())
    }

    private static func connectionID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    // MARK: - Text sanitization

    /// 剔除 XML 1.0 不允许的字符（控制字符会让 Edge 接口报错，与 edge-tts 的
    /// remove_incompatible_characters 一致）。
    private static func sanitize(_ text: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            let value = scalar.value
            let allowed = value == 0x09 || value == 0x0A || value == 0x0D
                || (value >= 0x20 && value <= 0xD7FF)
                || (value >= 0xE000 && value <= 0xFFFD)
                || (value >= 0x10000 && value <= 0x10FFFF)
            if allowed {
                result.append(scalar)
            }
        }
        return String(result)
    }

    private static func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - Settings helpers

    /// Saved synthesis speed (UserDefaults "talk.edge.speed", default 0).
    static func savedSpeed() -> Int {
        UserDefaults.standard.integer(forKey: "talk.edge.speed")
    }

    /// Saved synthesis pitch (UserDefaults "talk.edge.pitch", default 0).
    static func savedPitch() -> Int {
        UserDefaults.standard.integer(forKey: "talk.edge.pitch")
    }
}
