import OpenClawKit
import OpenClawProtocol
import SwiftUI

/// automation 卡 Provider（B-home）：
/// destination = 网关 cron 状态 + 任务列表（cron.status / cron.list RPC，参考 AgentProTab+Cron.swift）。
/// 只读接数；任务的创建/编辑/启停仍由 OpenClaw 现有自动化页负责，不在主页壳内复制。
enum HomeAutomationCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.automation] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .automation else { return nil }
        return AnyView(HomeAutomationDestinationView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .automation else { return nil }
        return [
            HomeCardQuickAction(
                id: "automation.jobs",
                title: String(localized: "Scheduled Tasks"),
                icon: "clock.badge.checkmark",
                destination: { AnyView(HomeAutomationDestinationView()) }
            ),
            HomeCardQuickAction(
                id: "automation.next",
                title: String(localized: "Next Run"),
                icon: "bolt.fill",
                destination: { AnyView(HomeAutomationDestinationView()) }
            ),
        ]
    }

    // MARK: - 网关 cron RPC（HomeTabView 今日概览与 destination 共用）

    /// cron.status 轻量响应（本地定义，避免依赖 Design 内部模型）。
    struct HomeCronStatusLite: Decodable {
        let enabled: Bool
        let jobs: Int
        let nextwakeatms: Int?

        enum CodingKeys: String, CodingKey {
            case enabled
            case jobs
            case nextwakeatms = "nextWakeAtMs"
        }
    }

    private struct HomeCronJobsEnvelope: Decodable {
        let jobs: [CronJob]
    }

    /// 请求 cron.status（网关未连接 / RPC 失败返回 nil，主页显示「--」）。
    @MainActor
    static func fetchCronStatus(appModel: NodeAppModel) async -> HomeCronStatusLite? {
        guard let gatewayID = appModel.connectedGatewayID else { return nil }
        do {
            let route = await appModel.operatorSession.currentRoute(ifGatewayID: gatewayID)
            let data = try await appModel.operatorSession.request(
                method: "cron.status",
                paramsJSON: "{}",
                timeoutSeconds: 20,
                ifCurrentRoute: route,
                distinguishPreDispatchRouteChange: true)
            return try JSONDecoder().decode(HomeCronStatusLite.self, from: data)
        } catch {
            return nil
        }
    }

    /// 请求 cron.list（取第一页，够主页展示用；失败返回空数组）。
    @MainActor
    static func fetchCronJobs(appModel: NodeAppModel, limit: Int = 200) async -> [CronJob] {
        guard let gatewayID = appModel.connectedGatewayID else { return [] }
        do {
            let params = try JSONSerialization.data(withJSONObject: [
                "includeDisabled": true,
                "limit": limit,
                "offset": 0,
                "sortBy": "name",
                "sortDir": "asc",
            ], options: [.sortedKeys])
            let paramsJSON = String(data: params, encoding: .utf8) ?? "{}"
            let route = await appModel.operatorSession.currentRoute(ifGatewayID: gatewayID)
            let data = try await appModel.operatorSession.request(
                method: "cron.list",
                paramsJSON: paramsJSON,
                timeoutSeconds: 12,
                ifCurrentRoute: route,
                distinguishPreDispatchRouteChange: true)
            return try JSONDecoder().decode(HomeCronJobsEnvelope.self, from: data).jobs
        } catch {
            return []
        }
    }
}

/// automation 卡目标页：网关 cron 状态 + 任务列表（只读，诚实空态，不造假数据）。
struct HomeAutomationDestinationView: View {
    @Environment(NodeAppModel.self) private var appModel

    @State private var status: HomeAutomationCardProvider.HomeCronStatusLite?
    @State private var jobs: [CronJob] = []
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        List {
            Section {
                statusRow
            }

            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if didFail {
                    Text(String(localized: "Gateway is unavailable. Check the connection and try again."))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                } else if jobs.isEmpty {
                    Text(String(localized: "No scheduled tasks."))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(jobs.enumerated()), id: \.element.id) { index, job in
                        jobRow(job)
                        if index < jobs.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            } header: {
                Text(String(localized: "Scheduled Tasks"))
            }
        }
        .navigationTitle(HomeCardKind.automation.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    // MARK: - 状态区

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "Scheduler"))
                    .font(OpenClawType.headline)
                Spacer()
                Text(status?.enabled == true ? String(localized: "On") : String(localized: "Off"))
                    .font(OpenClawType.caption2SemiBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(status?.enabled == true ? OpenClawBrand.ok : Color.secondary, in: Capsule())
            }
            HStack(spacing: 20) {
                metric(label: String(localized: "Automations"), value: status.map { "\($0.jobs)" } ?? "--")
                metric(label: String(localized: "Next"), value: nextRunText)
            }
        }
        .padding(.vertical, 4)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(OpenClawType.subheadSemiBold)
                .foregroundStyle(.primary)
            Text(label)
                .font(OpenClawType.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var nextRunText: String {
        guard let ms = status?.nextwakeatms else { return "--" }
        return Self.timeText(fromMilliseconds: ms)
    }

    // MARK: - 任务行

    private func jobRow(_ job: CronJob) -> some View {
        HStack(spacing: 12) {
            Image(systemName: job.enabled ? "clock.badge.checkmark" : "pause.circle")
                .font(.headline)
                .foregroundStyle(job.enabled ? OpenClawBrand.accent : Color.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(job.name)
                    .font(OpenClawType.subheadSemiBold)
                    .lineLimit(1)
                Text(Self.scheduleText(job))
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let next = Self.nextRunText(job) {
                    Text(String(localized: "Next run \(next)"))
                        .font(OpenClawType.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(job.enabled ? String(localized: "On") : String(localized: "Off"))
                .font(OpenClawType.caption2SemiBold)
                .foregroundStyle(job.enabled ? OpenClawBrand.accent : .secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
    }

    // MARK: - 数据加载

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        didFail = false
        async let statusTask = HomeAutomationCardProvider.fetchCronStatus(appModel: appModel)
        async let jobsTask = HomeAutomationCardProvider.fetchCronJobs(appModel: appModel)
        let (status, jobs) = await (statusTask, jobsTask)
        self.status = status
        self.jobs = jobs
        self.didFail = status == nil && jobs.isEmpty
        isLoading = false
    }

    // MARK: - 展示辅助（只读解析，不引入 Design 内部工具）

    private static func scheduleText(_ job: CronJob) -> String {
        guard let dict = job.schedule.value as? [String: AnyCodable] else {
            return String(localized: "Schedule configured")
        }
        if let expr = stringValue(dict["expr"]), !expr.isEmpty {
            return String(localized: "Cron \(expr)")
        }
        if let everyMs = intValue(dict["everyMs"]?.value) {
            return durationText(milliseconds: everyMs)
        }
        if let kind = stringValue(dict["kind"]), !kind.isEmpty {
            return kind
        }
        return String(localized: "Schedule configured")
    }

    private static func durationText(milliseconds: Int) -> String {
        let seconds = Double(milliseconds) / 1000
        if seconds >= 3600 {
            return String(format: String(localized: "Every %.1f hours"), seconds / 3600)
        }
        if seconds >= 60 {
            return String(format: String(localized: "Every %.0f minutes"), seconds / 60)
        }
        return String(format: String(localized: "Every %.0f seconds"), seconds)
    }

    private static func nextRunText(_ job: CronJob) -> String? {
        if let ms = job.nextrunatms {
            return timeText(fromMilliseconds: ms)
        }
        if let ms = intValue(job.state["nextRunAtMs"]?.value) {
            return timeText(fromMilliseconds: ms)
        }
        return nil
    }

    private static func stringValue(_ value: AnyCodable?) -> String? {
        guard let string = value?.value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int: return int
        case let double as Double where double.isFinite: return Int(double)
        case let string as String: return Int(string)
        default: return nil
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func timeText(fromMilliseconds ms: Int) -> String {
        timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(ms) / 1000))
    }
}