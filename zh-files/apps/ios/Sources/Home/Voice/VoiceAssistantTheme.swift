import SwiftUI

// MARK: - 主题相位

/// 大卡动画四态（对应语音状态）。
enum VoiceAssistantThemePhase: Equatable {
    case idle
    case listening
    case thinking
    case speaking
}

// MARK: - 动画参数

/// 每主题每态动画参数。
struct VoiceAssistantThemeAnimation: Equatable {
    /// 一个完整动画周期（秒）。
    let duration: Double
    /// 0...1 动画幅度（脉冲大小/柱高/粒子速度/光晕半径/折线摆幅）。
    let amplitude: Double
    /// 元素透明度 0...1。
    let opacity: Double
    /// 每秒旋转角度（轨道/光晕使用）。
    let rotationDegreesPerSecond: Double
    /// 元素数量（脉冲环层数/频谱柱数/粒子数/光晕层数/折线采样点数）。
    let count: Int
    /// 录音时 micLevel 联动系数。
    let micLevelScale: Double
}

/// 每主题互不重复的动态元素。
enum VoiceAssistantThemeElement: String {
    case pulseRing
    case spectrumBars
    case orbitParticles
    case haloLayers
    case waveScan
}

// MARK: - 主题

/// 语音助手大卡主题（T15）。
///
/// 每主题一套主渐变 + 互不重复的动态元素：
/// Pulse 脉冲红橙 / Spectrum 频谱青蓝 / Orbit 轨道紫 / Halo 光环珊瑚粉 / Wave 声浪蓝绿。
enum VoiceAssistantTheme: String, CaseIterable, Identifiable {
    case pulse
    case spectrum
    case orbit
    case halo
    case wave

    /// UserDefaults key：启动读取，选择即写。
    static let storageKey = "voice.assistant.theme"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .pulse: return String(localized: "Pulse")
        case .spectrum: return String(localized: "Spectrum")
        case .orbit: return String(localized: "Orbit")
        case .halo: return String(localized: "Halo")
        case .wave: return String(localized: "Wave")
        }
    }

    var elementSubtitle: String {
        switch self {
        case .pulse: return String(localized: "Pulse ring")
        case .spectrum: return String(localized: "Spectrum bars")
        case .orbit: return String(localized: "Orbit particles")
        case .halo: return String(localized: "Halo layers")
        case .wave: return String(localized: "Wave scan")
        }
    }

    /// 主题主渐变（卡片背景 + 动画层共用）。
    var gradient: [Color] {
        switch self {
        case .pulse:
            return [
                Color(red: 1.00, green: 0.38, blue: 0.24),
                Color(red: 0.82, green: 0.16, blue: 0.14),
                Color(red: 0.46, green: 0.08, blue: 0.10),
            ]
        case .spectrum:
            return [
                Color(red: 0.10, green: 0.72, blue: 0.84),
                Color(red: 0.06, green: 0.60, blue: 0.62),
                Color(red: 0.04, green: 0.30, blue: 0.48),
            ]
        case .orbit:
            return [
                Color(red: 0.55, green: 0.35, blue: 0.90),
                Color(red: 0.62, green: 0.30, blue: 0.82),
                Color(red: 0.30, green: 0.22, blue: 0.62),
            ]
        case .halo:
            return [
                Color(red: 0.96, green: 0.42, blue: 0.48),
                Color(red: 0.88, green: 0.36, blue: 0.62),
                Color(red: 0.58, green: 0.16, blue: 0.34),
            ]
        case .wave:
            return [
                Color(red: 0.16, green: 0.78, blue: 0.72),
                Color(red: 0.12, green: 0.62, blue: 0.50),
                Color(red: 0.10, green: 0.42, blue: 0.66),
            ]
        }
    }

    /// 主题高亮色（阴影/选中态）。
    var accent: Color {
        self.gradient.first ?? .white
    }

    /// 互不重复的动态元素。
    var element: VoiceAssistantThemeElement {
        switch self {
        case .pulse: return .pulseRing
        case .spectrum: return .spectrumBars
        case .orbit: return .orbitParticles
        case .halo: return .haloLayers
        case .wave: return .waveScan
        }
    }

    /// 四态动画参数。
    func animation(for phase: VoiceAssistantThemePhase) -> VoiceAssistantThemeAnimation {
        switch phase {
        case .idle: return self.idleAnimation
        case .listening: return self.listeningAnimation
        case .thinking: return self.thinkingAnimation
        case .speaking: return self.speakingAnimation
        }
    }

    /// ClawTalk 悬浮麦同款力度换算：1 + level * 1.2。
    static func micStrength(_ level: Double) -> Double {
        min(2.2, 1 + level * 1.2)
    }
}

// MARK: - 每主题每态参数

private extension VoiceAssistantTheme {
    var idleAnimation: VoiceAssistantThemeAnimation {
        switch self {
        case .pulse: return .init(duration: 3.2, amplitude: 0.28, opacity: 0.55, rotationDegreesPerSecond: 0, count: 3, micLevelScale: 0.30)
        case .spectrum: return .init(duration: 2.6, amplitude: 0.30, opacity: 0.60, rotationDegreesPerSecond: 0, count: 9, micLevelScale: 0.30)
        case .orbit: return .init(duration: 5.0, amplitude: 0.30, opacity: 0.60, rotationDegreesPerSecond: 14, count: 5, micLevelScale: 0.30)
        case .halo: return .init(duration: 3.8, amplitude: 0.30, opacity: 0.50, rotationDegreesPerSecond: 0, count: 4, micLevelScale: 0.30)
        case .wave: return .init(duration: 3.0, amplitude: 0.30, opacity: 0.60, rotationDegreesPerSecond: 0, count: 28, micLevelScale: 0.30)
        }
    }

    var listeningAnimation: VoiceAssistantThemeAnimation {
        switch self {
        case .pulse: return .init(duration: 1.2, amplitude: 0.80, opacity: 0.85, rotationDegreesPerSecond: 0, count: 3, micLevelScale: 1.00)
        case .spectrum: return .init(duration: 1.1, amplitude: 0.90, opacity: 0.90, rotationDegreesPerSecond: 0, count: 9, micLevelScale: 1.00)
        case .orbit: return .init(duration: 2.2, amplitude: 0.75, opacity: 0.90, rotationDegreesPerSecond: 45, count: 5, micLevelScale: 1.00)
        case .halo: return .init(duration: 1.6, amplitude: 0.80, opacity: 0.85, rotationDegreesPerSecond: 0, count: 4, micLevelScale: 1.00)
        case .wave: return .init(duration: 1.2, amplitude: 0.85, opacity: 0.90, rotationDegreesPerSecond: 0, count: 28, micLevelScale: 1.00)
        }
    }

    var thinkingAnimation: VoiceAssistantThemeAnimation {
        switch self {
        case .pulse: return .init(duration: 2.0, amplitude: 0.50, opacity: 0.70, rotationDegreesPerSecond: 0, count: 3, micLevelScale: 0.30)
        case .spectrum: return .init(duration: 1.8, amplitude: 0.55, opacity: 0.75, rotationDegreesPerSecond: 0, count: 9, micLevelScale: 0.30)
        case .orbit: return .init(duration: 3.0, amplitude: 0.55, opacity: 0.80, rotationDegreesPerSecond: 30, count: 5, micLevelScale: 0.30)
        case .halo: return .init(duration: 2.4, amplitude: 0.55, opacity: 0.70, rotationDegreesPerSecond: 0, count: 4, micLevelScale: 0.30)
        case .wave: return .init(duration: 2.0, amplitude: 0.50, opacity: 0.75, rotationDegreesPerSecond: 0, count: 28, micLevelScale: 0.30)
        }
    }

    var speakingAnimation: VoiceAssistantThemeAnimation {
        switch self {
        case .pulse: return .init(duration: 1.0, amplitude: 1.00, opacity: 0.95, rotationDegreesPerSecond: 0, count: 3, micLevelScale: 0.60)
        case .spectrum: return .init(duration: 0.9, amplitude: 1.00, opacity: 1.00, rotationDegreesPerSecond: 0, count: 9, micLevelScale: 0.70)
        case .orbit: return .init(duration: 1.6, amplitude: 1.00, opacity: 1.00, rotationDegreesPerSecond: 70, count: 5, micLevelScale: 0.70)
        case .halo: return .init(duration: 1.2, amplitude: 1.00, opacity: 0.95, rotationDegreesPerSecond: 0, count: 4, micLevelScale: 0.70)
        case .wave: return .init(duration: 0.8, amplitude: 1.00, opacity: 1.00, rotationDegreesPerSecond: 0, count: 28, micLevelScale: 0.70)
        }
    }
}

// MARK: - 动画辅助

/// 正弦呼吸 0...1。
private func voiceBreathePhase(_ time: TimeInterval, duration: Double, offset: Double = 0) -> Double {
    0.5 + 0.5 * sin(time / duration * 2 * .pi + offset)
}

// MARK: - 主题动画层

/// 按主题渲染的中心状态动画层（只影响大卡内部视觉）。
struct VoiceAssistantThemeLayer: View {
    let theme: VoiceAssistantTheme
    let phase: VoiceAssistantThemePhase
    let micLevel: Double

    var body: some View {
        let animation = self.theme.animation(for: self.phase)
        Group {
            switch self.theme.element {
            case .pulseRing:
                ThemePulseRingView(colors: self.theme.gradient, animation: animation, micLevel: self.micLevel)
            case .spectrumBars:
                ThemeSpectrumBarsView(colors: self.theme.gradient, animation: animation, micLevel: self.micLevel)
            case .orbitParticles:
                ThemeOrbitParticlesView(colors: self.theme.gradient, animation: animation, micLevel: self.micLevel)
            case .haloLayers:
                ThemeHaloLayersView(colors: self.theme.gradient, animation: animation, micLevel: self.micLevel)
            case .waveScan:
                ThemeWaveScanView(colors: self.theme.gradient, animation: animation, micLevel: self.micLevel)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: 脉冲环（Pulse）

private struct ThemePulseRingView: View {
    let colors: [Color]
    let animation: VoiceAssistantThemeAnimation
    let micLevel: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let strength = VoiceAssistantTheme.micStrength(self.micLevel)
            ZStack {
                ForEach(0..<max(2, self.animation.count), id: \.self) { index in
                    let breath = voiceBreathePhase(
                        time,
                        duration: self.animation.duration,
                        offset: Double(index) * 0.38)
                    let micPulse = self.animation.micLevelScale * self.micLevel * strength
                    let scale = 0.30
                        + (0.40 + breath * 0.60) * self.animation.amplitude
                        + micPulse * 0.28
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: self.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing),
                            lineWidth: CGFloat(max(1.0, 2.4 - Double(index) * 0.5)))
                        .frame(width: 58, height: 58)
                        .scaleEffect(CGFloat(scale))
                        .opacity(self.animation.opacity * (1 - breath * 0.55))
                }
            }
            .frame(width: 112, height: 112)
        }
    }
}

// MARK: 频谱柱（Spectrum）

private struct ThemeSpectrumBarsView: View {
    let colors: [Color]
    let animation: VoiceAssistantThemeAnimation
    let micLevel: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let strength = VoiceAssistantTheme.micStrength(self.micLevel)
            let count = max(5, self.animation.count)
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<count, id: \.self) { index in
                    let breath = voiceBreathePhase(
                        time,
                        duration: self.animation.duration,
                        offset: Double(index) * 0.50)
                    let micBoost = self.animation.micLevelScale * self.micLevel * strength
                    let height = 10 + 54 * self.animation.amplitude * breath + 46 * micBoost
                    Capsule()
                        .fill(LinearGradient(colors: self.colors, startPoint: .top, endPoint: .bottom))
                        .frame(width: 4.5, height: CGFloat(max(6, height)))
                        .opacity(self.animation.opacity)
                }
            }
            .frame(height: 80)
        }
    }
}

// MARK: 旋转轨道粒子（Orbit）

private struct ThemeOrbitParticlesView: View {
    let colors: [Color]
    let animation: VoiceAssistantThemeAnimation
    let micLevel: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let strength = VoiceAssistantTheme.micStrength(self.micLevel)
            let count = max(3, self.animation.count)
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(colors: self.colors, startPoint: .top, endPoint: .bottom).opacity(0.35),
                        lineWidth: 1)
                    .frame(width: 88, height: 88)
                ForEach(0..<count, id: \.self) { index in
                    let angle = time * self.animation.rotationDegreesPerSecond * .pi / 180
                        + Double(index) * 2 * .pi / Double(count)
                    let micBoost = self.animation.micLevelScale * self.micLevel * strength
                    let radius = 38 + 5 * self.animation.amplitude + micBoost * 6
                    let particleSize = 6 + micBoost * 3
                    Circle()
                        .fill(self.colors[index % self.colors.count])
                        .frame(width: CGFloat(particleSize), height: CGFloat(particleSize))
                        .offset(
                            x: CGFloat(cos(angle) * radius),
                            y: CGFloat(sin(angle) * radius))
                        .opacity(self.animation.opacity)
                }
                Circle()
                    .fill(LinearGradient(colors: self.colors, startPoint: .top, endPoint: .bottom))
                    .frame(width: 10, height: 10)
                    .opacity(self.animation.opacity)
            }
            .frame(width: 112, height: 112)
        }
    }
}

// MARK: 多层光晕（Halo）

private struct ThemeHaloLayersView: View {
    let colors: [Color]
    let animation: VoiceAssistantThemeAnimation
    let micLevel: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let strength = VoiceAssistantTheme.micStrength(self.micLevel)
            let count = max(3, self.animation.count)
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let breath = voiceBreathePhase(
                        time,
                        duration: self.animation.duration * (0.72 + Double(index) * 0.22),
                        offset: Double(index) * 0.40)
                    let scale = 0.85
                        + (0.35 + breath * 0.65) * self.animation.amplitude
                        + self.animation.micLevelScale * self.micLevel * strength * 0.30
                    Circle()
                        .fill(self.colors[index % self.colors.count])
                        .frame(
                            width: CGFloat(30 + index * 15),
                            height: CGFloat(30 + index * 15))
                        .blur(radius: CGFloat(7 + index * 2))
                        .scaleEffect(CGFloat(scale))
                        .opacity(0.14 * self.animation.opacity * (0.7 + breath * 0.6))
                }
            }
            .frame(width: 112, height: 112)
        }
    }
}

// MARK: 声波折线扫描（Wave）

private struct ThemeWaveScanView: View {
    let colors: [Color]
    let animation: VoiceAssistantThemeAnimation
    let micLevel: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let strength = VoiceAssistantTheme.micStrength(self.micLevel)
            let count = max(12, self.animation.count)
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                let midY = height / 2
                let amplitude = Double(height) * 0.34 * self.animation.amplitude
                    + Double(height) * 0.26 * self.animation.micLevelScale * self.micLevel * strength
                let phase = time * 2 * .pi / self.animation.duration
                let scanX = CGFloat((time / self.animation.duration).truncatingRemainder(dividingBy: 1)) * width
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: midY))
                        for index in 0...count {
                            let x = CGFloat(index) / CGFloat(count) * width
                            let wave = sin(Double(index) * 0.5 + phase)
                            let y = midY - CGFloat(wave) * CGFloat(amplitude) * 0.5
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(
                        LinearGradient(colors: self.colors, startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .opacity(self.animation.opacity)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    (self.colors.first ?? .white).opacity(0),
                                    (self.colors.first ?? .white).opacity(0.5),
                                    (self.colors.last ?? .white).opacity(0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing))
                        .frame(width: 26)
                        .offset(x: scanX - 13)
                        .opacity(self.animation.opacity)
                }
            }
        }
    }
}

// MARK: - 录音频谱条（仿 ClawTalk）

/// 中心区小尺寸频谱条：22 条竖条，主题渐变着色，半透明黑底圆角胶囊。
/// 与 VoiceAssistantThemeLayer 的各主题元素相互独立，录音/说话态叠加使用。
struct VoiceAssistantSpectrumBars: View {
    let theme: VoiceAssistantTheme
    let phase: VoiceAssistantThemePhase
    let micLevel: Double
    let width: CGFloat
    let height: CGFloat

    private static let barCount = 22
    private static let barWidth: CGFloat = 3
    private static let barSpacing: CGFloat = 1.5
    private static let baseHeight: CGFloat = 6
    private static let waveAmplitude: CGFloat = 10
    private static let micBoostScale: Double = 22

    private var intensity: Double {
        switch self.phase {
        case .listening: return 1.0
        case .speaking: return 0.85
        default: return 0.55
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.32))
                    .frame(width: self.width, height: self.height)

                HStack(alignment: .bottom, spacing: Self.barSpacing) {
                    ForEach(0..<Self.barCount, id: \.self) { index in
                        let wave = sin(time * 2.8 + Double(index) * 0.6)
                        let boost = self.micLevel * Self.micBoostScale
                        let barHeight = Self.baseHeight
                            + CGFloat(wave) * Self.waveAmplitude * CGFloat(self.intensity)
                            + CGFloat(boost)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: self.theme.gradient,
                                    startPoint: .top,
                                    endPoint: .bottom))
                            .frame(
                                width: Self.barWidth,
                                height: max(Self.baseHeight, barHeight))
                            .opacity(0.6 + 0.4 * self.intensity)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - 主题选择器

/// 主题选择 sheet：5 卡片预览，点选立即生效。
struct VoiceAssistantThemePickerView: View {
    let selected: VoiceAssistantTheme
    let onSelect: (VoiceAssistantTheme) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Voice theme"))
                .font(OpenClawType.title3SemiBold)
                .foregroundStyle(OpenClawBrand.textSecondary)
            Text(String(localized: "Pick a theme. It applies to the assistant card instantly."))
                .font(OpenClawType.caption)
                .foregroundStyle(OpenClawBrand.textSecondary)

            ForEach(VoiceAssistantTheme.allCases) { theme in
                Button {
                    self.onSelect(theme)
                    self.dismiss()
                } label: {
                    self.themePreviewRow(theme)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func themePreviewRow(_ theme: VoiceAssistantTheme) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: theme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                VoiceAssistantThemeLayer(theme: theme, phase: .listening, micLevel: 0.55)
                    .frame(width: 50, height: 50)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.displayName)
                    .font(OpenClawType.subheadSemiBold)
                    .foregroundStyle(OpenClawBrand.textSecondary)
                Text(theme.elementSubtitle)
                    .font(OpenClawType.caption)
                    .foregroundStyle(OpenClawBrand.textSecondary.opacity(0.8))
            }
            Spacer(minLength: 4)
            if theme == self.selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(OpenClawBrand.ok)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(OpenClawBrand.activationNeutralSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    Color.primary.opacity(theme == self.selected ? 0.6 : 0.12),
                    lineWidth: theme == self.selected ? 1.5 : 1)
        }
    }
}
