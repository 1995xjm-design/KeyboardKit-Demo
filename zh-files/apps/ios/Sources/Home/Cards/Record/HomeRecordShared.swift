import SwiftUI

/// 点击录音按钮：空闲时点击立即开始录音（回调 onHoldBegan），录音中点击立即停止（回调 onHoldEnded）。
/// 视觉：录音中环形渐变频谱随 audioLevel 跳动；转写中显示等待态。记录/记账两卡共用。
struct HoldToTalkButton: View {
    let phase: HomeSpeechRecorder.Phase
    let audioLevel: Float
    var tint: Color = OpenClawBrand.accent
    var compact = false
    var onHoldBegan: () -> Void = {}
    var onHoldEnded: () -> Void = {}

    @State private var isPressed = false
    @State private var didHandlePress = false

    private var recordButtonSize: CGFloat { compact ? 56 : 72 }
    private var ringPadding: CGFloat { compact ? 18 : 30 }
    private var ringRadius: CGFloat { (recordButtonSize + ringPadding) / 2 }
    private let spectrumBarCount = 22

    var body: some View {
        ZStack {
            if phase == .recording {
                recordingSpectrum
            }
            buttonBody
            Image(systemName: buttonIcon)
                .font(.system(size: compact ? 20 : 26, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: compact ? 76 : 104)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressAction() }
                .onEnded { _ in releaseAction() }
        )
        .onDisappear {
            isPressed = false
            didHandlePress = false
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var recordingSpectrum: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<spectrumBarCount, id: \.self) { index in
                    let length = spectrumLength(time: time, index: index)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(spectrumGradient)
                        .frame(width: 2, height: length)
                        .offset(y: -ringRadius)
                        .rotationEffect(.degrees(Double(index) * 360.0 / Double(spectrumBarCount)))
                }
            }
            .frame(width: recordButtonSize + ringPadding, height: recordButtonSize + ringPadding)
        }
    }

    private var buttonBody: some View {
        Group {
            switch phase {
            case .recording:
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            case .transcribing:
                Circle().fill(OpenClawBrand.textSecondary)
            case .idle:
                Circle().fill(tint)
            }
        }
        .frame(width: recordButtonSize, height: recordButtonSize)
        .scaleEffect(buttonScale)
        .animation(.easeOut(duration: 0.12), value: audioLevel)
        .animation(.easeOut(duration: 0.1), value: isPressed)
    }

    private var buttonScale: CGFloat {
        if phase == .recording {
            return CGFloat(1 + Double(audioLevel) * 0.08)
        }
        return isPressed ? 0.94 : 1
    }

    private var spectrumGradient: LinearGradient {
        LinearGradient(
            colors: [tint, tint.opacity(0.25)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func spectrumLength(time: TimeInterval, index: Int) -> CGFloat {
        let phase = time * 2 + Double(index) * 0.6
        let value = 6 + sin(phase) * 8 + Double(audioLevel) * 22
        return CGFloat(max(2, value))
    }

    private func pressAction() {
        guard !didHandlePress else { return }
        switch phase {
        case .idle:
            didHandlePress = true
            isPressed = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onHoldBegan()
        case .recording:
            didHandlePress = true
            isPressed = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onHoldEnded()
        case .transcribing:
            break
        }
    }

    private func releaseAction() {
        isPressed = false
        didHandlePress = false
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