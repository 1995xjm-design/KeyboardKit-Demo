import AVFoundation
import OpenClawKit
import SwiftUI

// MARK: - 通道与状态

/// 语音助手大卡通道选择（AppStorage 持久化）。
enum VoiceAssistantChannel: String, CaseIterable, Identifiable {
    case auto
    case talk
    case deepSeek

    static let storageKey = "talk.voiceAssistant.channel"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .talk: return String(localized: "OpenClaw Talk")
        case .deepSeek: return String(localized: "DeepSeek Direct")
        }
    }
}

/// 语音助手大卡会话状态。
enum VoiceAssistantCardPhase: Equatable {
    case idle
    case capturing
    case thinking
    case speaking
    case hint(String)
    case finished(String)
    case error(String)
}

/// 大卡交互模式。语音助手默认使用持续通话；DeepSeek 直连仍保留一次性转写。
enum VoiceAssistantCardMode: String, CaseIterable, Identifiable {
    case pushToTalk
    case realtime

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .pushToTalk: return String(localized: "Push to talk")
        case .realtime: return String(localized: "Realtime call")
        }
    }
}

// MARK: - 大卡视图

/// 主页顶部「语音助手」大卡（完整可用视图）。
///
/// 通道选择（网关在线默认 Talk，离线自动提示切 DeepSeek 或一键切换）：
/// - 自动（默认）：网关在线 → OpenClaw Talk；离线 → 已配置的 DeepSeek 直连。
/// - OpenClaw Talk：走 OpenClaw 现有 TalkModeManager 对讲链路（麦克风 → 网关 → 回复 → TTS）。
/// - DeepSeek 直连：TalkModeManager「仅转写」PTT 拿文本 → DeepSeekDirectClient 回复 →
///   OpenClaw 现有 Edge TTS 播报。
///
/// 交互模式（顶部胶囊切换，互斥）：
/// - 点按说话（默认）：点击大卡一次对讲。
/// - 实时通话：talkMode.setEnabled(true) + await talkMode.start()，网关 Realtime 优先、
///   连续识别兜底一直可聊；退出 stop()。状态由 isListening/isSpeaking/statusText 驱动。
///
/// 不重造 OpenClaw 已有语音能力：录音 / 转写 / 网关回复 / 播报全部复用现有接口，
/// 本视图只做通道编排与 UI 状态。
struct VoiceAssistantCardView: View {
    let appModel: NodeAppModel

    @AppStorage(VoiceAssistantChannel.storageKey) private var channelRaw =
        VoiceAssistantChannel.auto.rawValue

    @AppStorage(VoiceAssistantTheme.storageKey) private var themeRaw =
        VoiceAssistantTheme.pulse.rawValue

    @State private var phase: VoiceAssistantCardPhase = .idle
    @State private var isRealtimeMode = false
    @State private var showsThemePicker = false
    @State private var transcriptText = ""
    @State private var isBusy = false
    @State private var activeTask: Task<Void, Never>?
    @State private var realtimeTask: Task<Void, Never>?
    @State private var isBreathing = false
    @State private var recordingStartedAt: Date?

    private static let cardHeight: CGFloat = 250

    init(appModel: NodeAppModel) {
        self.appModel = appModel
    }

    private var talkMode: TalkModeManager { self.appModel.talkMode }

    private var preference: VoiceAssistantChannel {
        VoiceAssistantChannel(rawValue: self.channelRaw) ?? .auto
    }

    /// 当前生效通道（自动解析；离线且未配置 DeepSeek 时仍回退 .talk，便于给出切换提示）。
    private var effectiveChannel: VoiceAssistantChannel {
        switch self.preference {
        case .auto:
            if self.talkMode.isGatewayConnected { return .talk }
            return DeepSeekDirectClient.shared.isConfigured ? .deepSeek : .talk
        case .talk:
            return .talk
        case .deepSeek:
            return .deepSeek
        }
    }

    private var isGatewayOnline: Bool {
        self.talkMode.isGatewayConnected
    }

    private var deepSeekConfigured: Bool {
        DeepSeekDirectClient.shared.isConfigured
    }

    private var gatewayDotColor: Color {
        self.isGatewayOnline ? OpenClawBrand.ok : OpenClawBrand.danger
    }

    private var theme: VoiceAssistantTheme {
        VoiceAssistantTheme(rawValue: self.themeRaw) ?? .pulse
    }

    /// 持续通话由 TalkMode 的真实状态驱动；DeepSeek 直连使用本地 phase。
    private var displayPhase: VoiceAssistantCardPhase {
        if self.isRealtimeMode {
            if self.talkMode.isSpeaking { return .speaking }
            if self.talkMode.isListening { return .capturing }
            return .idle
        }
        return self.phase
    }

    private var themePhase: VoiceAssistantThemePhase {
        switch self.displayPhase {
        case .capturing: return .listening
        case .thinking: return .thinking
        case .speaking: return .speaking
        default: return .idle
        }
    }

    private var isPulsingIcon: Bool {
        self.displayPhase == .capturing || self.displayPhase == .speaking
    }

    private var centerIcon: String {
        switch self.displayPhase {
        case .capturing: return "mic.fill"
        case .thinking: return "ellipsis.circle"
        case .speaking: return "speaker.wave.2.fill"
        case .error: return "exclamationmark.triangle.fill"
        default: return "waveform"
        }
    }

    private var modeSubtitle: String {
        self.isRealtimeMode
            ? String(localized: "Realtime call · always available")
            : String(localized: "Tap to start or end a call")
    }

    private var statusCaption: String {
        if self.isRealtimeMode {
            return self.talkMode.statusText
        }
        if let hint = self.statusHint {
            return hint
        }
        switch self.phase {
        case .idle:
            if !self.isGatewayOnline {
                return String(localized: "Gateway offline · switch to DeepSeek Direct to keep talking")
            }
            return String(localized: "Tap to talk · always available")
        case .capturing:
            return String(localized: "Listening…")
        case .thinking:
            return String(localized: "Thinking…")
        case .speaking:
            return String(localized: "Speaking…")
        case let .hint(text), let .finished(text), let .error(text):
            return text
        }
    }

    /// 兜底/失败提示（如 "Edge TTS unavailable, using system voice"、网关降级摘要）显示到卡片。
    private var statusHint: String? {
        if let issue = self.talkMode.gatewayTalkLastIssueText, !issue.isEmpty {
            return issue
        }
        // PTT 播报中 TalkMode 可能降级到系统语音并改写 statusText，浮出到卡片。
        if self.phase == .speaking,
           self.talkMode.statusText != String(localized: "Speaking…"),
           self.talkMode.statusText != String(localized: "Speaking (System)…")
        {
            return self.talkMode.statusText
        }
        return nil
    }

    private var isLongStatusText: Bool {
        if case .finished = self.phase { return true }
        if case .error = self.phase { return true }
        return self.statusCaption.count > 24
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: self.theme.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(
                    color: self.theme.accent.opacity(self.isBreathing ? 0.45 : 0.25),
                    radius: self.isBreathing ? 14 : 8,
                    x: 0,
                    y: 8)

            if self.isPulsingIcon {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(self.theme.accent.opacity(0.16))
            }

            VStack(spacing: 6) {
                self.topBar
                Spacer(minLength: 0)
                self.centerStatus
                Spacer(minLength: 0)
                self.bottomBar
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.cardHeight)
        .scaleEffect(self.isBreathing ? 1.0 : 0.97)
        .opacity(self.isBreathing ? 1.0 : 0.9)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { self.handleTap() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                self.isBreathing = true
            }
            if self.isRealtimeMode {
                self.startRealtimeSession()
            }
        }
        .onDisappear { self.teardown() }
        .animation(.easeInOut(duration: 0.3), value: self.phase)
        .animation(.easeInOut(duration: 0.3), value: self.isRealtimeMode)
        .animation(.easeInOut(duration: 0.3), value: self.theme)
        .sheet(isPresented: self.$showsThemePicker) {
            VoiceAssistantThemePickerView(selected: self.theme) { theme in
                self.themeRaw = theme.rawValue
            }
            .presentationDetents([.height(520), .large])
            .presentationDragIndicator(.visible)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Voice assistant"))
        .accessibilityValue(self.statusCaption)
    }

    // MARK: - 子视图

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))

            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "Voice Assistant"))
                    .font(OpenClawType.title3SemiBold)
                    .foregroundStyle(.white)
                Text(self.modeSubtitle)
                    .font(OpenClawType.caption)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                self.showsThemePicker = true
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Choose voice theme"))

            HStack(spacing: 6) {
                Circle()
                    .fill(self.gatewayDotColor)
                    .frame(width: 9, height: 9)
                Text(self.isGatewayOnline ? String(localized: "Online") : String(localized: "Offline"))
                    .font(OpenClawType.captionSemiBold)
                    .foregroundStyle(Color.white.opacity(0.9))
            }
        }
    }

    private var centerStatus: some View {
        VStack(spacing: 6) {
            ZStack {
                VoiceAssistantThemeLayer(
                    theme: self.theme,
                    phase: self.themePhase,
                    micLevel: self.talkMode.micLevel)
                    .frame(width: 118, height: 76)

                Image(systemName: self.centerIcon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .symbolEffect(.pulse, options: .repeating, isActive: self.isPulsingIcon)
                    .scaleEffect(self.isPulsingIcon ? 1.12 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: self.isPulsingIcon)

                if self.isPulsingIcon {
                    VoiceAssistantSpectrumBars(
                        theme: self.theme,
                        phase: self.themePhase,
                        micLevel: self.talkMode.micLevel,
                        width: 100,
                        height: 38)
                        .frame(width: 118, height: 76, alignment: .bottom)
                }
            }
            .frame(height: 76)

            Text(self.statusCaption)
                .font(OpenClawType.subheadSemiBold)
                .multilineTextAlignment(.center)
                .lineLimit(self.isLongStatusText ? 3 : 2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            if self.displayPhase == .capturing, let startedAt = self.recordingStartedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
                    Text(String(format: "%02d:%02d", elapsed / 60, elapsed % 60))
                        .font(OpenClawType.caption.monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }

            if self.displayPhase == .thinking && !self.transcriptText.isEmpty {
                Text(self.transcriptText)
                    .font(OpenClawType.caption)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button {
                self.switchChannel()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: self.effectiveChannel == .deepSeek
                        ? "network"
                        : "bubble.left.and.bubble.right.fill")
                    Text(self.effectiveChannel == .deepSeek
                        ? String(localized: "DeepSeek Direct")
                        : String(localized: "OpenClaw Talk"))
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                }
                .font(OpenClawType.captionSemiBold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Switch voice channel"))

            Spacer(minLength: 4)

            if self.preference == .auto {
                Text(String(localized: "Auto"))
                    .font(OpenClawType.caption)
                    .foregroundStyle(Color.white.opacity(0.75))
            }

            if self.effectiveChannel == .talk && !self.isGatewayOnline {
                Button {
                    self.switchChannel()
                } label: {
                    Text(String(localized: "Switch to DeepSeek Direct"))
                        .font(OpenClawType.captionSemiBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 交互

    private func handleTap() {
        if self.effectiveChannel == .talk {
            if self.isRealtimeMode {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self.stopRealtimeSession()
            } else {
                guard self.isGatewayOnline else {
                    self.phase = .error(String(localized:
                        "Gateway offline: OpenClaw Talk is unavailable right now. Switch to DeepSeek Direct to keep talking."))
                    return
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.isRealtimeMode = true
                self.phase = .idle
                self.startRealtimeSession()
            }
            return
        }
        if self.isBusy {
            self.cancelConversation()
            return
        }
        switch self.effectiveChannel {
        case .talk:
            guard self.isGatewayOnline else {
                self.phase = .error(String(localized:
                    "Gateway offline: OpenClaw Talk is unavailable right now. Switch to DeepSeek Direct to keep talking."))
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.runTalkChannel()
        case .deepSeek:
            guard self.deepSeekConfigured else {
                self.phase = .error(String(localized:
                    "DeepSeek Direct is not configured. Turn it on and add your API key in Settings → Voice."))
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.runDeepSeekChannel()
        case .auto:
            break
        }
    }

    private func switchChannel() {
        self.activeTask?.cancel()
        self.activeTask = nil
        VoiceAssistantSpeechPlayer.shared.stop()
        self.stopRealtimeSession()
        switch self.effectiveChannel {
        case .talk:
            self.channelRaw = VoiceAssistantChannel.deepSeek.rawValue
        case .deepSeek:
            self.channelRaw = VoiceAssistantChannel.talk.rawValue
        case .auto:
            break
        }
        self.phase = .idle
        self.transcriptText = ""
    }

    private func stopRealtimeSession() {
        self.realtimeTask?.cancel()
        self.realtimeTask = nil
        self.talkMode.stop()
        self.isRealtimeMode = false
        self.phase = .idle
        self.transcriptText = ""
        self.recordingStartedAt = nil
    }

    /// 实时通话：setEnabled(true) + start()（网关 Realtime 优先、连续识别兜底一直可聊）。
    private func startRealtimeSession() {
        self.realtimeTask?.cancel()
        self.realtimeTask = Task { @MainActor in
            GatewayDiagnostics.log("voice.card call start tap")
            self.talkMode.setEnabled(true)
            await self.talkMode.start()
        }
    }

    /// OpenClaw Talk 通道：一次对讲（非仅转写），网关负责回复与 TTS。
    private func runTalkChannel() {
        self.isBusy = true
        self.phase = .capturing
        self.recordingStartedAt = Date()
        self.activeTask = Task { @MainActor in
            defer { self.isBusy = false; self.recordingStartedAt = nil }
            do {
                let start = try await self.talkMode.beginPushToTalkOnce(transcriptionOnly: false)
                switch start {
                case let .busy(payload):
                    self.phase = payload.status == "busy"
                        ? .error(String(localized: "The microphone is busy. Try again in a moment."))
                        : .idle
                case .started:
                    let payload = await self.talkMode.awaitPushToTalkOnce(start)
                    self.recordingStartedAt = nil
                    switch payload.status {
                    case "queued":
                        // 网关接管回复与 TTS；本卡观察 isSpeaking 过渡到播报态。
                        self.phase = .thinking
                        await self.waitForTalkSpeech()
                    case "empty":
                        self.phase = .hint(String(localized: "I didn’t catch that. Try again."))
                    case "offline":
                        self.phase = .error(String(localized:
                            "Gateway went offline mid-talk. Switch to DeepSeek Direct to keep talking."))
                    default:
                        self.phase = .idle
                    }
                }
            } catch {
                self.phase = .error(VoiceAssistantErrorMessage.text(for: error))
            }
        }
    }

    /// DeepSeek 直连通道：仅转写 PTT 拿文本 → DeepSeek 回复 → Edge TTS 播报。
    private func runDeepSeekChannel() {
        self.isBusy = true
        self.phase = .capturing
        self.recordingStartedAt = Date()
        self.activeTask = Task { @MainActor in
            defer { self.isBusy = false; self.recordingStartedAt = nil }
            do {
                let start = try await self.talkMode.beginPushToTalkOnce(transcriptionOnly: true)
                switch start {
                case let .busy(payload):
                    self.phase = payload.status == "busy"
                        ? .error(String(localized: "The microphone is busy. Try again in a moment."))
                        : .idle
                case .started:
                    let payload = await self.talkMode.awaitPushToTalkOnce(start)
                    self.recordingStartedAt = nil
                    guard payload.status == "transcribed",
                          let transcript = payload.transcript,
                          !transcript.isEmpty
                    else {
                        self.phase = payload.status == "empty"
                            ? .hint(String(localized: "I didn’t catch that. Try again."))
                            : .idle
                        return
                    }
                    self.transcriptText = transcript
                    self.phase = .thinking
                    let reply = try await DeepSeekDirectClient.shared.complete(
                        messages: [.user(transcript)],
                        system: DeepSeekDirectClient.defaultSystemPrompt)
                    guard !Task.isCancelled else { return }
                    self.phase = .speaking
                    try await VoiceAssistantSpeechPlayer.shared.speak(reply)
                    guard !Task.isCancelled else { return }
                    self.phase = .finished(reply)
                    // 短暂展示回复文本后回待机。
                    try? await Task.sleep(for: .seconds(5))
                    if self.phase == .finished(reply) {
                        self.phase = .idle
                    }
                    self.transcriptText = ""
                }
            } catch {
                self.phase = .error(VoiceAssistantErrorMessage.text(for: error))
            }
        }
    }

    /// 等待网关回复播报完成：isSpeaking 出现 → 播报中 → 播完回待机。
    ///
    /// 说明：TalkModeManager 没有「本次 PTT 播报完成」的公开回调，这里用轻量轮询桥接
    /// （0.2s），避免给 TalkModeManager 增加接口；120s 超时兜底回待机。
    private func waitForTalkSpeech() async {
        let timeoutSteps = 600
        var wasSpeaking = false
        for _ in 0..<timeoutSteps {
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            let speaking = self.talkMode.isSpeaking
            if speaking && self.phase != .speaking {
                self.phase = .speaking
            }
            if !speaking && wasSpeaking {
                self.phase = .idle
                return
            }
            wasSpeaking = speaking
        }
        if self.phase == .speaking || self.phase == .thinking {
            self.phase = .idle
        }
    }

    private func cancelConversation() {
        self.activeTask?.cancel()
        self.activeTask = nil
        VoiceAssistantSpeechPlayer.shared.stop()
        _ = self.talkMode.cancelPushToTalk()
        self.phase = .idle
        self.transcriptText = ""
        self.recordingStartedAt = nil
    }

    private func teardown() {
        self.recordingStartedAt = nil
        self.activeTask?.cancel()
        self.activeTask = nil
        self.realtimeTask?.cancel()
        self.realtimeTask = nil
        VoiceAssistantSpeechPlayer.shared.stop()
        // 主题选择 sheet 弹出也会触发 onDisappear，不能因此打断实时通话。
        if self.isRealtimeMode && !self.showsThemePicker {
            self.stopRealtimeSession()
        }
    }
}

// MARK: - 错误文案

/// TalkMode / DeepSeek 错误 → 中文用户文案。
private enum VoiceAssistantErrorMessage {
    static func text(for error: Error) -> String {
        if let deepSeek = error as? DeepSeekDirectClient.DeepSeekError {
            return deepSeek.errorDescription ?? String(localized: "Something went wrong. Try again.")
        }
        let nsError = error as NSError
        if nsError.domain == "TalkMode" {
            switch nsError.code {
            case 4:
                return String(localized: "Microphone permission is off. Allow microphone access in system Settings.")
            case 5:
                return String(localized: "Speech recognition permission is off. Allow it in system Settings.")
            case 7:
                return String(localized: "Gateway offline: switch to DeepSeek Direct or retry later.")
            case 9:
                return String(localized: "Cancelled.")
            case 10:
                return String(localized: "The microphone is busy. Try again in a moment.")
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

// MARK: - Edge TTS 播报（复用 OpenClaw 现有能力）

/// 播报一段文本：OpenClaw 现有 Edge TTS 合成 MP3 → AVAudioPlayer 播放。
/// 复用 EdgeTTSSynthesizer / EdgeTTSVoice / 语速语调设置，不重造 TTS。
/// stop() 置空播放器，speak() 的等待循环随即退出（不悬挂调用方）。
@MainActor
private final class VoiceAssistantSpeechPlayer {
    static let shared = VoiceAssistantSpeechPlayer()

    private var player: AVAudioPlayer?

    private init() {}

    func stop() {
        self.player?.stop()
        self.player = nil
    }

    /// 播放文本直到结束；失败抛错；被 stop() 或任务取消中断时正常返回。
    func speak(_ text: String) async throws {
        self.stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        let audio = try await EdgeTTSSynthesizer.synthesize(
            text: text,
            voiceId: EdgeTTSVoice.current.id,
            speed: EdgeTTSSynthesizer.savedSpeed(),
            pitch: EdgeTTSSynthesizer.savedPitch())
        guard !Task.isCancelled else { return }
        let player = try AVAudioPlayer(data: audio)
        player.prepareToPlay()
        self.player = player
        guard player.play() else {
            self.player = nil
            throw VoiceAssistantSpeechError.playbackFailed
        }
        // 播放完成或被打断时退出等待。
        while self.player === player && player.isPlaying && !Task.isCancelled {
            try? await Task.sleep(for: .seconds(0.1))
        }
    }
}

private enum VoiceAssistantSpeechError: LocalizedError {
    case playbackFailed

    var errorDescription: String? {
        String(localized: "Could not play the reply. Showing text instead.")
    }
}
