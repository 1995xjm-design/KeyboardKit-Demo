//
//  DoubaoASRClient.swift
//  OpenClaw
//
//  Doubao (Volcano Engine) big-model streaming ASR over
//  WebSocket. Sends 16k mono 16-bit PCM; the app microphone
//  (usually 48k) is resampled with AVAudioConverter before
//  transmission.
//
//  Thread safety: this class is intentionally NOT @MainActor so the
//  AVAudioEngine tap thread can call `appendPCM` directly. All mutable
//  state is guarded by a lock; callbacks are re-dispatched to the main
//  actor.
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
    private var converter: AVAudioConverter?
    private var isStarted = false
    private var pendingStart: [Data] = []

    private let appID: String
    private let token: String
    private let apiKey: String
    private let language: String

    init(
        appID: String,
        token: String,
        apiKey: String = "",
        language: String = DoubaoConfig.defaultASRLanguage)
    {
        self.appID = appID
        self.token = token
        self.apiKey = apiKey
        self.language = language
        super.init()
    }

    private var usesArkKey: Bool { !apiKey.isEmpty }

    // MARK: - Lifecycle

    /// Opens the WebSocket and sends the start frame.
    func start() throws {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        lock.lock()
        self.session = session
        lock.unlock()

        let url: URL
        if usesArkKey {
            guard let arkURL = URL(string: DoubaoConfig.asrEndpoint.absoluteString + "?x-api-app-key=" + apiKey) else {
                throw DoubaoASRClientError.invalidURL
            }
            url = arkURL
        } else {
            var urlComponents = URLComponents(
                url: DoubaoConfig.asrEndpoint,
                resolvingAgainstBaseURL: false)!
            urlComponents.queryItems = [
                URLQueryItem(name: "appid", value: appID),
                URLQueryItem(name: "token", value: token),
            ]
            guard let composed = urlComponents.url else {
                throw DoubaoASRClientError.invalidURL
            }
            url = composed
        }

        let task = session.webSocketTask(with: url)
        lock.lock()
        self.task = task
        lock.unlock()

        let authToken = usesArkKey ? apiKey : token
        let startPayload: [String: Any] = [
            "header": [
                "appid": appID,
                "token": authToken,
                "event": "start",
                "namespace": "audio",
                "message_id": UUID().uuidString,
                "resource_id": DoubaoConfig.asrResourceID,
            ],
            "payload": [
                "format": "pcm",
                "codec": "raw",
                "rate": 16000,
                "bits": 16,
                "channels": 1,
                "language": language,
            ],
        ]
        let startData = try JSONSerialization.data(withJSONObject: startPayload)
        let startString = String(data: startData, encoding: .utf8) ?? "{}"

        task.resume()
        lock.lock()
        isStarted = true
        lock.unlock()
        task.send(.string(startString)) { [weak self] error in
            if let error {
                self?.emitError(error)
            }
        }
        lock.lock()
        let queued = pendingStart
        pendingStart.removeAll()
        lock.unlock()
        for data in queued {
            sendAudio(data)
        }
        receive()
    }

    /// Thread-safe: callable from the audio tap thread.
    func appendPCM(_ data: Data) {
        lock.lock()
        let started = isStarted
        let task = self.task
        lock.unlock()
        guard started, let task else { return }
        task.send(.data(data)) { [weak self] error in
            if let error {
                self?.emitError(error)
            }
        }
    }

    /// Sends the end frame and waits for the final result.
    func finish() {
        lock.lock()
        let started = isStarted
        let task = self.task
        lock.unlock()
        guard started, let task else { return }
        let endPayload: [String: Any] = [
            "header": [
                "event": "end",
                "message_id": UUID().uuidString,
            ],
        ]
        guard let endData = try? JSONSerialization.data(withJSONObject: endPayload),
              let endString = String(data: endData, encoding: .utf8)
        else { return }
        task.send(.string(endString)) { [weak self] error in
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
        self.converter = nil
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

    private func sendAudio(_ data: Data) {
        lock.lock()
        let task = self.task
        lock.unlock()
        guard let task else { return }
        task.send(.data(data)) { [weak self] error in
            if let error {
                self?.emitError(error)
            }
        }
    }

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
        guard case .string(let text) = message else { return }
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let header = obj["header"] as? [String: Any]
        let event = header?["event"] as? String

        // Error events carry code/message at the root.
        if event == "error" {
            let code = (obj["code"] as? Int) ?? -1
            let message = obj["message"] as? String ?? "unknown"
            emitError(DoubaoASRClientError.api(code, message))
            return
        }

        guard event == "result" else { return }
        guard let payload = obj["payload"] as? [String: Any],
              let result = payload["result"] as? [String: Any],
              let text = result["text"] as? String
        else { return }

        let isDefinite = (payload["definite"] as? Bool) ?? false
        if isDefinite {
            emitFinal(text)
        } else {
            emitPartial(text)
        }
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

        // Build/reset a converter when the input format changes.
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
    case api(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Doubao ASR is not configured"
        case .invalidURL: "Invalid Doubao ASR endpoint"
        case .closed(let code): "Doubao ASR closed (code \(code))"
        case .api(let code, let message): "Doubao ASR error \(code): \(message)"
        }
    }
}
