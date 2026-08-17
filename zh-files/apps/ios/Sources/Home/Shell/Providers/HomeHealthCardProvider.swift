import OpenClawKit
import SwiftUI

/// health 卡 Provider（B-home）：
/// destination = Apple 健康摘要（OpenClaw `Sources\Health\HealthSummaryService.swift`，真实数据）。
enum HomeHealthCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.health] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .health else { return nil }
        return AnyView(HomeHealthDestinationView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .health else { return nil }
        return [
            HomeCardQuickAction(
                id: "health.today",
                title: String(localized: "Today Health"),
                icon: "heart.fill",
                destination: { AnyView(HomeHealthDestinationView()) }
            ),
            HomeCardQuickAction(
                id: "health.access",
                title: String(localized: "Health Access"),
                icon: "checkmark.shield.fill",
                destination: { AnyView(HomeHealthDestinationView()) }
            ),
        ]
    }
}

/// health 卡目标页：今日步数/睡眠/静息心率/锻炼（HealthSummaryService 真实数据，诚实空态）。
struct HomeHealthDestinationView: View {
    @State private var payload: OpenClawHealthSummaryPayload?
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        List {
            Section {
                if !HealthAuthorization.isEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Apple Health access is off."))
                            .font(OpenClawType.body)
                        Text(String(localized: "Enable Apple Health Summaries in OpenClaw settings to show steps and health data here."))
                            .font(OpenClawType.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if let payload {
                    metricRow(
                        icon: "figure.walk",
                        tint: OpenClawBrand.ok,
                        label: String(localized: "Steps"),
                        value: payload.stepCount.map { "\($0)" } ?? "--"
                    )
                    metricRow(
                        icon: "moon.zzz.fill",
                        tint: OpenClawBrand.info,
                        label: String(localized: "Sleep"),
                        value: payload.sleepDurationMinutes.map(Self.minutesText) ?? "--"
                    )
                    metricRow(
                        icon: "heart.circle.fill",
                        tint: OpenClawBrand.accent,
                        label: String(localized: "Resting Heart Rate"),
                        value: payload.restingHeartRateBpm.map { String(format: "%.0f", $0) } ?? "--"
                    )
                    metricRow(
                        icon: "figure.run",
                        tint: OpenClawBrand.warn,
                        label: String(localized: "Workouts"),
                        value: payload.workoutCount.map { "\($0)" } ?? "--"
                    )
                } else if let errorText {
                    Text(errorText)
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "No health data yet."))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "Today"))
            }
        }
        .navigationTitle(HomeCardKind.health.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    // MARK: - 数据加载

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorText = nil
        do {
            payload = try await HealthSummaryService().summary(
                params: OpenClawHealthSummaryParams(period: .today))
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 展示辅助

    private func metricRow(icon: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(label)
                .font(OpenClawType.subhead)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(OpenClawType.subheadSemiBold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private static func minutesText(_ minutes: Int) -> String {
        if minutes >= 60 {
            return String(format: String(localized: "%d h %d min"), minutes / 60, minutes % 60)
        }
        return String(format: String(localized: "%d min"), minutes)
    }
}