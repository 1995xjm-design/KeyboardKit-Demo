import SwiftUI

/// 按住说话按钮：按住 0.3 秒进入录音（回调 onHoldBegan），松开回调 onHoldEnded。
/// 视觉：录音中脉冲环随 audioLevel 缩放；转写中显示等待态。记录/记账两卡共用。
struct HoldToTalkButton: View {
    let phase: HomeSpeechRecorder.Phase
    let audioLevel: Float
    var compact = false
    var onHoldBegan: () -> Void = {}
    var onHoldEnded: () -> Void = {}

    @State private var controller = HoldTalkController()

    private var recordButtonSize: CGFloat { compact ? 56 : 72 }
    private var ringPadding: CGFloat { compact ? 18 : 30 }

    var body: some View {
        ZStack {
            if phase == .recording {
                Circle()
                    .stroke(OpenClawBrand.accent.opacity(0.28), lineWidth: 4)
                    .frame(width: recordButtonSize + ringPadding, height: recordButtonSize + ringPadding)
                    .scaleEffect(CGFloat(1 + audioLevel * 0.22))
                    .animation(.easeOut(duration: 0.12), value: audioLevel)
            }
            Circle()
                .fill(buttonColor)
                .frame(width: recordButtonSize, height: recordButtonSize)
                .scaleEffect(controller.isPressed && !controller.isActive ? 0.94 : 1)
                .animation(.easeOut(duration: 0.1), value: controller.isPressed)
            Image(systemName: buttonIcon)
                .font(.system(size: compact ? 20 : 26, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: compact ? 76 : 104)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in controller.press() }
                .onEnded { _ in controller.release() }
        )
        .onAppear {
            controller.onHoldBegan = { onHoldBegan() }
            controller.onHoldEnded = { onHoldEnded() }
        }
        .onDisappear { controller.reset() }
        .accessibilityLabel(accessibilityLabel)
    }

    private var buttonColor: Color {
        switch phase {
        case .recording: return OpenClawBrand.accentHot
        case .transcribing: return OpenClawBrand.textSecondary
        case .idle: return OpenClawBrand.accent
        }
    }

    private var buttonIcon: String {
        switch phase {
        case .recording: return "waveform"
        case .transcribing: return "ellipsis"
        case .idle: return "mic.fill"
        }
    }

    private var accessibilityLabel: String {
        switch phase {
        case .recording: return String(localized: "Record.Accessibility.Recording")
        case .transcribing: return String(localized: "Record.Accessibility.Transcribing")
        case .idle: return String(localized: "Record.Accessibility.HoldToTalk")
        }
    }
}

/// 按住说话手势状态机：0.3 秒阈值后才触发 onHoldBegan；未达阈值松开不触发 onHoldEnded。
/// @MainActor 隔离，保证 Swift 6 严格并发下从视图手势闭包调用安全。
@MainActor
final class HoldTalkController {
    private(set) var isPressed = false
    private(set) var isActive = false

    var onHoldBegan: (() -> Void)?
    var onHoldEnded: (() -> Void)?

    private var holdTask: Task<Void, Never>?
    private let holdThreshold: UInt64 = 300_000_000

    func press() {
        guard !isPressed else { return }
        isPressed = true
        let threshold = holdThreshold
        holdTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: threshold)
            guard !Task.isCancelled, let self else { return }
            self.isActive = true
            self.onHoldBegan?()
        }
    }

    func release() {
        isPressed = false
        holdTask?.cancel()
        holdTask = nil
        guard isActive else { return }
        isActive = false
        onHoldEnded?()
    }

    func reset() {
        release()
        onHoldBegan = nil
        onHoldEnded = nil
    }
}