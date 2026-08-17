import AVFoundation
import Foundation
import Observation

/// 睡前白噪音播放器：AVAudioEngine + AVAudioSourceNode 生成轻柔白噪音循环。
/// 纯代码生成、无外部资源（ClawTalk WindDownNoisePlayer 同方案）；stop() 立即停止并释放引擎。
/// 会话用 .playback + .mixWithOthers：白噪音可与其它 App 音频混播，不占麦克风。
@MainActor
@Observable
final class HomeWindDownNoisePlayer {
    private(set) var isPlaying = false
    /// 定时剩余分钟数（nil = 未定时，手动停止）。
    private(set) var remainingMinutes: Int?
    /// 睡前模式剩余秒数（nil = 未运行睡前模式）。
    private(set) var sleepModeRemainingSeconds: Int?
    /// 睡前模式到点置 true（页面展示「晚安」提示，dismiss 后清除）。
    private(set) var sleepModeFinished = false
    /// 最近一次启动失败原因（页面诚实展示）。
    private(set) var lastError: String?

    private var engine: AVAudioEngine?
    private var timerTask: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?

    /// 开始播放白噪音。volume 为 0~1 的幅度（默认 0.05，很轻，适合睡前）。
    func start(volume: Float = 0.05) {
        guard engine == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            lastError = error.localizedDescription
            return
        }

        let newEngine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let source = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in buffers {
                guard let mData = buffer.mData else { continue }
                let frames = Int(frameCount)
                let channelCount = Int(buffer.mNumberChannels)
                let samples = mData.assumingMemoryBound(to: Float.self)
                let total = frames * channelCount
                for index in 0..<total {
                    samples[index] = Float.random(in: -1...1) * volume
                }
            }
            return noErr
        }
        let mixer = AVAudioMixerNode()
        mixer.outputVolume = 0.9
        newEngine.attach(source)
        newEngine.attach(mixer)
        newEngine.connect(source, to: mixer, format: format)
        newEngine.connect(mixer, to: newEngine.mainMixerNode, format: format)
        newEngine.mainMixerNode.outputVolume = 0.8
        do {
            try newEngine.start()
        } catch {
            lastError = error.localizedDescription
            return
        }
        engine = newEngine
        isPlaying = true
        lastError = nil
    }

    /// 定时播放：minutes 分钟后自动停止（手动停止同样生效）。
    func startTimed(minutes: Int, volume: Float = 0.05) {
        start(volume: volume)
        guard isPlaying else { return }
        timerTask?.cancel()
        remainingMinutes = minutes
        timerTask = Task { @MainActor [weak self] in
            for remaining in stride(from: minutes, through: 1, by: -1) {
                try? await Task.sleep(nanoseconds: UInt64(60 * 1_000_000_000))
                if Task.isCancelled { return }
                self?.remainingMinutes = remaining - 1
            }
            self?.stop()
        }
    }

    /// 睡前模式：播白噪音并按秒倒计时，到点自动停止并置 finished 标记。
    func startSleepMode(minutes: Int, volume: Float = 0.05) {
        sleepTask?.cancel()
        sleepTask = nil
        sleepModeFinished = false
        start(volume: volume)
        guard isPlaying else { return }
        sleepModeRemainingSeconds = minutes * 60
        sleepTask = Task { @MainActor [weak self] in
            var remaining = minutes * 60
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
                self?.sleepModeRemainingSeconds = remaining
            }
            self?.sleepModeRemainingSeconds = nil
            self?.stop()
            self?.sleepModeFinished = true
        }
    }

    /// 清除「到点」提示标记（页面展示后调用）。
    func dismissSleepFinished() {
        sleepModeFinished = false
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        sleepTask?.cancel()
        sleepTask = nil
        remainingMinutes = nil
        sleepModeRemainingSeconds = nil
        engine?.stop()
        engine = nil
        isPlaying = false
    }
}