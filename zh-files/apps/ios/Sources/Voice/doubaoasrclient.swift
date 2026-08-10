//
//  DoubaoASRClient.swift
//  OpenClaw
//
//  Doubao (Volcano Engine) big-model streaming ASR via the V3 WebSocket
//  API — the ClawTalk-verified integration.
//
//  URL: wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async
//  Auth: X-Api-Key (speech console API Key) + X-Api-Resource-Id
//  Frames: [0x11,0x11,0x10,0x00] init JSON + [0x11,0x21,0x10,0x00] audio
//          chunks (16k s16le PCM) + [0x11,0x23,0x10,0x00] end.
//
//  Thread safety: NOT @MainActor so the AVAudioEngine tap thread can call
//  `appendPCM` directly. All mutable state is guarded by a lock; callbacks
//  are re-dispatched to the main actor.
//

import AVFoundation
import Foundation

final class DoubaoASRClient: NSObject, URLSessionWebSocketDelegate {

    // MARK: - Callbacks (main-actor hops)

    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Locked state

    private let lock = NSLock()
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isStarted = false
    private var pendingStart: [Data] = []
    private var sequence: Int32 = 2

    private let apiKey: String
    private let language: String

    init(apiKey: String, language: String = DoubaoConfig.defaultASRLanguage) {
        self.apiKey = apiKey
        self.language = language
        super.init()
    }

    // MARK: - Lifecycle

    /// Opens the WebSocket, sends the init frame.
    func start() throws {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        lock.lock()
        self.session = session
        lock.unlock()

        var request = URLRequest(url: DoubaoConfig.asrEndpoint)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue(DoubaoConfig.asrResourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue("-1", forHTTPHeaderField: "X-Api-Sequence")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Connect-Id")

        let task = session.webSocketTask(with: request)
        lock.lock()
        self.task = task
        lock.unlock()
        task.resume()

        let payload: [String: Any] = [
            "user": ["uid": "openclaw-ios"],
            "audio": ["format": "pcm", "codec": "raw", "rate": 16000, "bits": 16, "channel": 1],
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,
                "enable_punc": true,
                "enable_ddc": true,
                "show_utterances": false,
                "enable_nonstream": false,
            ],
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        var frame = Data([0x11, 0x11, 0x10, 0x00])
        var seq = Int32(1).bigEndian
        frame.append(Data(bytes: &seq, count: 4))
        var len = UInt32(json.count).bigEndian
        frame.append(Data(bytes: &len, count: 4))
        frame.append(json)

        lock.lock()
        isStarted = true
        lock.unlock()
        task.send(.data(frame)) { [weak self] error in
            if let error {
                self?.emitError(error)
            }
        }
        receive()
    }

    /// Thread-safe: callable from the audio tap thread.
    func appendPCM(_ data: Data) {
        lock.lock()
        let started = isStarted
        let task = self.task
        lock.unlock()
        guard started, let task, !data.isEmpty else { return }

        // 200ms chunks of 16k s16le = 6400 bytes
        let chunkBytes = 16000 * 2 / 5
        var index = 0
        while index < data.count {
            let end = min(index + chunkBytes, data.count)
            let chunk = data.subdata(in: index..<end)
            let isLast = end >= data.count

            lock.lock()
            let seqValue = isLast ? -sequence : sequence
            sequence += 1
            lock.unlock()

            var frame = Data(isLast ? [0x11, 0x23, 0x10, 0x00] : [0x11, 0x21, 0x10, 0x00])
            var seqBE = seqValue.bigEndian
            frame.append(Data(bytes: &seqBE, count: 4))
            var len = UInt32(chunk.count).bigEndian
            frame.append(Data(bytes: &len, count: 4))
            frame.append(chunk)
            task.send(.data(frame)) { [weak self] error in
                if let error {
                    self?.emitError(error)
                }
            }
            index = end
        }
    }

    /// Sends the end frame (when no trailing audio) and waits for the final result.
    func finish() {
        lock.lock()
        let started = isStarted
        let task = self.task
        lock.unlock()
        guard started, let task else { return }

        lock.lock()
        let seqValue = -sequence
        lock.unlock()

        var frame = Data([0x11, 0x23, 0x10, 0x00])
        var seqBE = seqValue.bigEndian
        frame.append(Data(bytes: &seqBE, count: 4))
        var len = UInt32(0).bigEndian
        frame.append(Data(bytes: &len, count: 4))
        task.send(.data(frame)) { [weak self] error in
            if let error {
                self?.emitError(error)
            }
        }
    }

    func close() {
        lock.lock()
        let task = self.task
        self.task = nil
        self.session = nil
        self.isStarted = false
        lock.unlock()
        task?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - WebSocket delegate

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?)
    {
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?)
    {
        lock.lock()
        let started = isStarted
        lock.unlock()
        if started {
            emitError(DoubaoASRClientError.closed(closeCode.rawValue))
        }
    }

    // MARK: - Private

    private func receive() {
        lock.lock()
        let task = self.task
        lock.unlock()
        guard let task else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handle(message)
                self.receive()
            case .failure(let error):
                self.emitError(error)
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            guard let parsed = Self.parseResponse(data) else { return }
            if let text = parsed.text, !text.isEmpty {
                if parsed.isFinal {
                    emitFinal(text)
                } else {
                    emitPartial(text)
                }
            }
        case .string(let string):
            emitError(DoubaoASRClientError.serverMessage(string))
        @unknown default:
            break
        }
    }

    // MARK: - Frame parsing (ClawTalk-verified)

    private static func parseResponse(_ data: Data) -> (text: String?, isFinal: Bool)? {
        guard data.count >= 4 else { return nil }
        let msgType = (data[1] >> 4) & 0x0F
        let flags = data[1] & 0x0F
        var offset = 4

        if msgType == 0b1111 {
            return nil // error frame; surfaced via close
        }

        if flags & 0b0011 != 0 {
            guard data.count >= offset + 4 else { return nil }
            offset += 4 // sequence
        }

        guard data.count >= offset + 4 else { return nil }
        let payloadLen = Int(data.subdata(in: offset..<offset + 4)
            .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian })
        offset += 4
        guard data.count >= offset + payloadLen else { return nil }
        let payload = data.subdata(in: offset..<offset + payloadLen)

        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let result = json["result"] as? [String: Any]
        else {
            return (nil, flags & 0b0010 != 0)
        }
        let text = result["text"] as? String
        let isFinal = (json["is_final"] as? Bool)
            ?? (result["is_final"] as? Bool)
            ?? (flags & 0b0010 != 0)
        return (text, isFinal)
    }

    // MARK: - Callback dispatch (main actor)

    private func emitPartial(_ text: String) {
        lock.lock()
        let callback = onPartial
        lock.unlock()
        Task { @MainActor in
            callback?(text)
        }
    }

    private func emitFinal(_ text: String) {
        lock.lock()
        let callback = onFinal
        lock.unlock()
        Task { @MainActor in
            callback?(text)
        }
    }

    private func emitError(_ error: Error) {
        lock.lock()
        let callback = onError
        lock.unlock()
        Task { @MainActor in
            callback?(error)
        }
    }

    // MARK: - Resampling (audio thread)

    /// Resamples any audio buffer to 16k mono 16-bit little-endian PCM.
    /// Safe to call on the audio tap thread; pass an audio-thread-local
    /// `converter` cache to avoid rebuilding it on every buffer.
    static func resample(
        _ buffer: AVAudioPCMBuffer,
        converter: inout AVAudioConverter?) -> Data?
    {
        let inputFormat = buffer.format
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true)
        guard let targetFormat else { return nil }

        if converter?.inputFormat != inputFormat {
            converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        }
        guard let converter else { return nil }

        let ratio = 16000.0 / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: capacity)
        else { return nil }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let int16 = output.int16ChannelData else { return nil }

        let frames = Int(output.frameLength)
        let bytes = frames * 2
        var data = Data(count: bytes)
        data.withUnsafeMutableBytes { raw in
            if let dst = raw.bindMemory(to: Int16.self).baseAddress {
                dst.update(from: int16.pointee, count: frames)
            }
        }
        return data
    }
}

enum DoubaoASRClientError: LocalizedError {
    case notConfigured
    case invalidURL
    case closed(Int)
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Doubao ASR is not configured"
        case .invalidURL: "Invalid Doubao ASR endpoint"
        case .closed(let code): "Doubao ASR closed (code \(code))"
        case .serverMessage(let message): "Doubao ASR server: \(message)"
        }
    }
}
