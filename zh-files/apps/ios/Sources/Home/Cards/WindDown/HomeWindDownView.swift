import SwiftUI

/// 睡前陪伴主页的启动方式（快捷动作用）。
enum HomeWindDownLaunchMode {
    /// 普通进入。
    case none
    /// 快捷动作「播放白噪音」：进入后自动开始白噪音。
    case noise
    /// 快捷动作「开始睡前模式」：进入后自动开始睡前模式倒计时。
    case sleep
}

/// 「睡前陪伴」页：晚安回顾（今日/明日提醒，数据来自 HomeReminderStore，诚实不造假）+
/// 助眠引导（4-7-8 呼吸动画，纯 SwiftUI，无声版）+ 白噪音（纯代码生成，可定时停止）+
/// 睡前模式计时器（白噪音 + 倒计时，到点自动停）+ 可选「每日定时睡前提醒」。
///
/// 移植自 ClawTalk WindDownView：
/// - 白噪音：WindDownNoisePlayer 同方案（AVAudioEngine 纯代码生成，无 bundle 资源）。
/// - 睡前模式计时器：新增，替代 ClawTalk 仅噪音定时停止。
/// - 助眠引导：ClawTalk 版本带 TTS 温柔朗读（SpeechService 栈），OpenClaw 无等价轻量 TTS，
///   本卡做无声动画引导（呼吸节奏 + 倒计时），朗读能力留作后续接入语音栈。
/// - 每日定时提醒：写入 HomeReminderStore（daily），到点由本地通知提醒。
@MainActor
struct HomeWindDownView: View {
    @State private var reminderStore: HomeReminderStore
    @State private var noisePlayer = HomeWindDownNoisePlayer()

    private let launchMode: HomeWindDownLaunchMode
    @State private var hasAppliedLaunch = false

    // 每日定时睡前提醒（可选）
    @State private var dailyReminderEnabled = false
    @State private var dailyReminderTime: Date

    // 睡前模式
    @State private var sleepModeActive = false
    @State private var sleepDuration = 30

    private static let windDownReminderIDKey = "openclaw_home_winddown_reminder_id"
    private static let windDownReminderTitle = String(localized: "Wind Down")

    init(
        store: HomeReminderStore? = nil,
        launchMode: HomeWindDownLaunchMode = .none
    ) {
        let resolvedStore = store ?? HomeReminderStore()
        _reminderStore = State(initialValue: resolvedStore)
        self.launchMode = launchMode

        let storedID = UserDefaults.standard.string(forKey: Self.windDownReminderIDKey)
        let storedReminder = storedID.flatMap { id in
            resolvedStore.reminders.first { $0.id == id }
        }
        _dailyReminderEnabled = State(initialValue: storedReminder != nil)
        _dailyReminderTime = State(initialValue: storedReminder?.time ?? Self.defaultReminderTime)
    }

    var body: some View {
        List {
            goodnightSection
            breathingSection
            noiseSection
            sleepModeSection
            nightlyReminderSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Wind Down"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasAppliedLaunch else { return }
            hasAppliedLaunch = true
            switch launchMode {
            case .none:
                break
            case .noise:
                noisePlayer.start()
            case .sleep:
                startSleepMode()
            }
        }
        .onChange(of: noisePlayer.sleepModeFinished) { _, finished in
            if finished {
                sleepModeActive = false
            }
        }
        .onDisappear {
            noisePlayer.stop()
        }
    }

    // MARK: - 说晚安

    private var goodnightSection: some View {
        Section {
            Text(goodnightLine)
                .font(OpenClawType.title3SemiBold)
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            Label {
                Text(todaySummaryText)
            } icon: {
                Image(systemName: "bell.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Label {
                Text(tomorrowSummaryText)
            } icon: {
                Image(systemName: "calendar.badge.clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } header: {
            Label(String(localized: "Say Goodnight"), systemImage: "moon.stars.fill")
        } footer: {
            Text(String(localized: "Reminder counts come from the Reminders card on this device."))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var goodnightLine: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 21..<24: String(localized: "It's late. You've done enough today. Good night and sweet dreams.")
        case 0..<6: String(localized: "It's late. Time to rest. Good night.")
        default: String(localized: "Good evening. Let's look back at today. Good night.")
        }
    }

    private var todaySummaryText: String {
        let count = reminderStore.todayReminderCount
        if count > 0 {
            return String(localized: "\(count) reminders still due today")
        }
        return String(localized: "No reminders due today")
    }

    private var tomorrowSummaryText: String {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let count = reminderStore.upcomingReminders
            .filter { calendar.isDate($0.fireDate, inSameDayAs: tomorrow) }
            .count
        if count > 0 {
            return String(localized: "\(count) reminders tomorrow")
        }
        return String(localized: "No reminders tomorrow")
    }

    // MARK: - 助眠引导

    private var breathingSection: some View {
        Section {
            HomeWindDownBreathingGuideView()
        } header: {
            Label(String(localized: "Breathing Guide"), systemImage: "wind")
        } footer: {
            Text(String(localized: "Follow the circle: breathe in for 4 seconds, hold for 7, and exhale slowly for 8."))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 白噪音

    private var noiseSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { noisePlayer.isPlaying },
                set: { newValue in
                    if newValue {
                        noisePlayer.start()
                    } else {
                        noisePlayer.stop()
                    }
                }
            )) {
                Label(String(localized: "Play White Noise"), systemImage: "speaker.wave.2.fill")
            }
            .tint(.indigo)

            if noisePlayer.isPlaying {
                HStack {
                    ForEach([15, 30, 60], id: \.self) { minutes in
                        Button {
                            noisePlayer.startTimed(minutes: minutes)
                        } label: {
                            Text("\(minutes) \(String(localized: "min"))")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.indigo.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let remaining = noisePlayer.remainingMinutes {
                    Text("\(String(localized: "Stops in")) \(remaining) \(String(localized: "min"))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label(String(localized: "White Noise"), systemImage: "moon.zzz.fill")
        } footer: {
            Text(String(localized: "A soft loop generated on-device. No audio files needed; can stop on a timer."))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 睡前模式计时器

    private var sleepModeSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { sleepModeActive },
                set: { newValue in
                    if newValue {
                        startSleepMode()
                    } else {
                        stopSleepMode()
                    }
                }
            )) {
                Label(String(localized: "Sleep Mode"), systemImage: "bed.double.fill")
            }
            .tint(OpenClawBrand.accent)

            if sleepModeActive {
                if let seconds = noisePlayer.sleepModeRemainingSeconds {
                    Label {
                        Text(String(localized: "Time remaining \(sleepCountdownText(seconds))"))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.subheadline)
                }
            } else {
                Picker(String(localized: "Duration"), selection: $sleepDuration) {
                    ForEach([15, 30, 60, 90], id: \.self) { minutes in
                        Text("\(minutes) \(String(localized: "min"))").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }

            if noisePlayer.sleepModeFinished {
                HStack(spacing: 12) {
                    Label(String(localized: "Time's up. Good night."), systemImage: "moon.stars.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button(String(localized: "OK")) {
                        noisePlayer.dismissSleepFinished()
                    }
                    .font(.footnote.weight(.semibold))
                }
            }

            if let error = noisePlayer.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Label(String(localized: "Sleep Timer"), systemImage: "timer")
        } footer: {
            Text(String(localized: "Sleep Mode plays white noise and stops automatically when the timer ends."))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func startSleepMode() {
        sleepModeActive = true
        noisePlayer.startSleepMode(minutes: sleepDuration)
    }

    private func stopSleepMode() {
        sleepModeActive = false
        noisePlayer.stop()
        noisePlayer.dismissSleepFinished()
    }

    private func sleepCountdownText(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - 每日定时睡前提醒（可选）

    private var nightlyReminderSection: some View {
        Section {
            Toggle(
                String(localized: "Remind me every night"),
                isOn: Binding(
                    get: { dailyReminderEnabled },
                    set: { toggleDailyReminder($0) }
                )
            )
            if dailyReminderEnabled {
                DatePicker(
                    String(localized: "Reminder time"),
                    selection: Binding(
                        get: { dailyReminderTime },
                        set: { newValue in
                            dailyReminderTime = newValue
                            updateDailyReminderTime()
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
            if reminderStore.notificationPermissionDenied {
                Label(
                    String(localized: "Notifications are turned off, so the reminder will not ring. Enable notifications in System Settings."),
                    systemImage: "bell.slash"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        } header: {
            Label(String(localized: "Nightly Reminder"), systemImage: "alarm")
        } footer: {
            Text(String(localized: "Saves a daily reminder (default 10:30 PM) that asks you to wind down, delivered by a local notification."))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func toggleDailyReminder(_ enabled: Bool) {
        dailyReminderEnabled = enabled
        if enabled {
            let reminder = HomeReminder(
                title: Self.windDownReminderTitle,
                time: dailyReminderTime,
                category: .custom,
                repeatType: .daily,
                enabled: true
            )
            let added = reminderStore.add(reminder)
            UserDefaults.standard.set(added.id, forKey: Self.windDownReminderIDKey)
        } else {
            if let id = UserDefaults.standard.string(forKey: Self.windDownReminderIDKey) {
                reminderStore.delete(id: id)
            }
            UserDefaults.standard.removeObject(forKey: Self.windDownReminderIDKey)
        }
    }

    private func updateDailyReminderTime() {
        guard dailyReminderEnabled,
              let id = UserDefaults.standard.string(forKey: Self.windDownReminderIDKey),
              let index = reminderStore.reminders.firstIndex(where: { $0.id == id }) else {
            return
        }
        var reminder = reminderStore.reminders[index]
        reminder.time = dailyReminderTime
        reminderStore.update(reminder)
    }

    /// 默认提醒时间：22:30。
    private static var defaultReminderTime: Date {
        Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - 助眠引导（4-7-8 呼吸）

/// 「助眠引导」：4-7-8 呼吸法圆圈缩放动画（纯 SwiftUI，无声）。
/// 节奏：吸气 4 秒（圆圈放大）→ 屏住 7 秒（保持）→ 呼气 8 秒（圆圈缩小），循环 4 轮后完成。
/// 从 ClawTalk BreathingGuideView 移植，去掉 TTS 语音部分（OpenClaw 未接入轻量 TTS）。
@MainActor
private struct HomeWindDownBreathingGuideView: View {
    private enum Phase: String {
        case inhale
        case hold
        case exhale

        var label: String {
            switch self {
            case .inhale: String(localized: "Breathe in")
            case .hold: String(localized: "Hold")
            case .exhale: String(localized: "Breathe out")
            }
        }

        var duration: Double {
            switch self {
            case .inhale: 4
            case .hold: 7
            case .exhale: 8
            }
        }
    }

    private static let totalRounds = 4

    @State private var phase: Phase = .inhale
    @State private var phaseStartedAt = Date.now
    @State private var isRunning = false
    @State private var finished = false
    @State private var round = 0
    @State private var task: Task<Void, Never>?

    private var scale: CGFloat {
        switch phase {
        case .inhale, .hold: 1.35
        case .exhale: 1.0
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.indigo.opacity(0.18), lineWidth: 4)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.5), OpenClawBrand.carapaceCoral.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 150, height: 150)
                    .scaleEffect(scale)
                    .animation(
                        phase == .hold ? .none : .easeInOut(duration: phase.duration),
                        value: scale
                    )
                VStack(spacing: 4) {
                    if isRunning {
                        Text(phase.label)
                            .font(OpenClawType.title3)
                            .foregroundStyle(.white)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = max(
                                0,
                                Int(ceil(phase.duration - context.date.timeIntervalSince(phaseStartedAt)))
                            )
                            Text("\(remaining)")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    } else if finished {
                        Text(String(localized: "Done. Sweet dreams."))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    } else {
                        Text(String(localized: "Ready?"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 220, height: 220)

            Text(String(localized: "Lie down, close your eyes, and follow the breathing rhythm."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isRunning {
                Text(String(localized: "Round \(round) / \(Self.totalRounds)"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                if isRunning {
                    stop()
                } else {
                    start()
                }
            } label: {
                Label(
                    isRunning ? String(localized: "Stop Guide") : String(localized: "Start Breathing Guide"),
                    systemImage: isRunning ? "stop.circle.fill" : "moon.zzz.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isRunning ? OpenClawBrand.warn : Color.indigo,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)

            Text(String(localized: "You can also turn on white noise below for a softer sound."))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .onDisappear { stop() }
    }

    private func start() {
        isRunning = true
        finished = false
        round = 1
        phase = .inhale
        phaseStartedAt = .now
        task?.cancel()
        task = Task { @MainActor in
            for _ in 1...Self.totalRounds {
                guard !Task.isCancelled else { break }
                await breathe(.inhale)
                await breathe(.hold)
                await breathe(.exhale)
                round += 1
            }
            isRunning = false
            finished = true
        }
    }

    private func breathe(_ newPhase: Phase) async {
        phase = newPhase
        phaseStartedAt = .now
        try? await Task.sleep(nanoseconds: UInt64(newPhase.duration * 1_000_000_000))
    }

    private func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        round = 0
        phase = .inhale
        finished = false
    }
}