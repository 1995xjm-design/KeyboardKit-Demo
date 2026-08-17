import AVFoundation
import Observation
import Speech

/// 自包含语音转写（SFSpeechRecognizer + AVAudioEngine）：
/// 不依赖 OpenClaw 语音栈，供「记录」「记账」两卡共用。
/// 权限（麦克风/语音识别）由宿主工程 Info.plist 提供。
@Observable
@MainActor
final class HomeSpeechRecorder {
    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
    }

    private(set) var phase: Phase = .idle
    /// 录音实时电平（0...1，驱动按住录音的脉冲动画）
    private(set) var audioLevel: Float = 0
    /// 实时转写片段（录音中持续更新）
    private(set) var partialText = ""
    var errorMessage: String?

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapQueue: HomeAudioBufferQueue?
    private var tapDrainTask: Task<Void, Never>?
    private var hasTap = false
    private var finalTranscript = ""
    private var recognitionFinished = false
    private var recognitionGeneration: UInt64 = 0

    init(locale: Locale = Locale(identifier: "zh-CN")) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - 权限

    /// 当前语音识别授权状态。
    static var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    /// 请求麦克风 + 语音识别权限；全部通过返回 true。
    func requestAuthorization() async -> Bool {
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else {
            errorMessage = String(localized: "Record.Error.MicrophonePermission")
            return false
        }
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        if !speechGranted {
            errorMessage = String(localized: "Record.Error.SpeechPermission")
        }
        return speechGranted
    }

    // MARK: - 录音

    /// 开始录音；成功返回 true（引擎不可用/启动失败返回 false 并设置 errorMessage）。
    func start() -> Bool {
        guard phase == .idle else { return false }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = String(localized: "Record.Error.SpeechUnavailable")
            return false
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            errorMessage = String(localized: "Record.Error.MicrophoneStart")
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            errorMessage = String(localized: "Record.Error.MicrophoneStart")
            return false
        }

        let queue = HomeAudioBufferQueue()
        tapQueue = queue
        let tapBlock: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, _ in
            queue.enqueueCopy(of: buffer)
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat, block: tapBlock)
        hasTap = true

        recognitionGeneration &+= 1
        let generation = recognitionGeneration
        let handler: @Sendable (SFSpeechRecognitionResult?, Error?) -> Void = { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let errorText = error?.localizedDescription
            Task { @MainActor in
                self?.handleRecognition(transcript: transcript, isFinal: isFinal, errorText: errorText, generation: generation)
            }
        }
        recognitionTask = speechRecognizer.recognitionTask(with: request, resultHandler: handler)

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            tearDownPipeline()
            errorMessage = String(localized: "Record.Error.MicrophoneStart")
            return false
        }

        phase = .recording
        finalTranscript = ""
        recognitionFinished = false
        partialText = ""
        audioLevel = 0
        tapDrainTask = Task { [weak self] in
            guard let self, let queue = self.tapQueue else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 40_000_000)
                let drained = queue.drain()
                if drained.isEmpty { continue }
                for buffer in drained {
                    self.recognitionRequest?.append(buffer)
                    self.updateLevel(from: buffer)
                }
            }
        }
        return true
    }

    /// 结束录音并返回最终转写文本；未识别到内容返回 nil。
    func finish() async -> String? {
        guard phase == .recording else { return nil }
        phase = .transcribing
        let text = await stopAndCollect()
        phase = .idle
        audioLevel = 0
        partialText = ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMessage = String(localized: "Record.Error.EmptyTranscript")
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 放弃当前录音（不落库）。
    func cancel() {
        tearDownPipeline()
        phase = .idle
        audioLevel = 0
        partialText = ""
    }

    // MARK: - 内部

    private func handleRecognition(transcript: String?, isFinal: Bool, errorText: String?, generation: UInt64) {
        guard generation == recognitionGeneration else { return }
        if let transcript {
            finalTranscript = transcript
            partialText = transcript
        }
        if isFinal || errorText != nil {
            recognitionFinished = true
        }
    }

    private func stopAndCollect() async -> String {
        recognitionRequest?.endAudio()
        let deadline = Date().addingTimeInterval(6)
        while !recognitionFinished && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        tearDownPipeline()
        return finalTranscript
    }

    private func tearDownPipeline() {
        recognitionGeneration &+= 1
        tapDrainTask?.cancel()
        tapDrainTask = nil
        tapQueue?.clear()
        tapQueue = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else {
            audioLevel = 0
            return
        }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<frames {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frames))
        audioLevel = min(max(rms * 5, 0), 1)
    }
}

/// 录音缓冲队列：tap 回调（实时音频线程）只入队深拷贝，主线程异步取走喂给识别请求。
/// 参照 OpenClaw Voice 栈的 Swift 6 并发安全写法。
private final class HomeAudioBufferQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var buffers: [AVAudioPCMBuffer] = []

    func enqueueCopy(of buffer: AVAudioPCMBuffer) {
        guard let copy = buffer.homeDeepCopy() else { return }
        lock.lock()
        buffers.append(copy)
        lock.unlock()
    }

    func drain() -> [AVAudioPCMBuffer] {
        lock.lock()
        let drained = buffers
        buffers.removeAll(keepingCapacity: true)
        lock.unlock()
        return drained
    }

    func clear() {
        lock.lock()
        buffers.removeAll(keepingCapacity: false)
        lock.unlock()
    }
}

private extension AVAudioPCMBuffer {
    /// 深拷贝（音频线程安全地持有缓冲）。
    func homeDeepCopy() -> AVAudioPCMBuffer? {
        let frameLength = frameLength
        guard frameLength > 0,
              let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }
        copy.frameLength = frameLength
        if let source = floatChannelData, let destination = copy.floatChannelData {
            let channels = Int(format.channelCount)
            let frames = Int(frameLength)
            for channel in 0..<channels {
                destination[channel].update(from: source[channel], count: frames)
            }
        }
        return copy
    }
}