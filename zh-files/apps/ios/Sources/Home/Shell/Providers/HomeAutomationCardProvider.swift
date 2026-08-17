import OpenClawKit
import OpenClawProtocol
import SwiftUI

/// 单任务操作结果（成功提示或失败错误，行内展示）。
private struct HomeJobActionMessage: Equatable {
    let text: String
    let isError: Bool
}

/// automation 卡 Provider（B-home）：
/// destination = 网关 cron 状态 + 任务列表（cron.status / cron.list RPC，参考 AgentProTab+Cron.swift）。
/// 任务管理操作（立即运行 / 暂停继续 / 删除）直接走网关 RPC；创建/编辑表单仍由 OpenClaw 现有自动化页负责。
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

    /// cron.run 轻量响应（本地定义，避免依赖 Design 内部模型）。
    struct HomeCronRunResult: Decodable {
        let ok: Bool
        let ran: Bool?
        let enqueued: Bool?
        let reason: String?
    }

    /// 主页自动化管理操作错误。
    enum HomeCronActionError: LocalizedError {
        case gatewayDisconnected
        case gatewayChanged
        case missingRevision
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .gatewayDisconnected:
                String(localized: "Connect a Gateway to manage automations.")
            case .gatewayChanged:
                String(localized: "The connected Gateway changed. Refresh and try again.")
            case .missingRevision:
                String(localized: "This automation cannot be changed from iOS right now.")
            case .invalidResponse:
                String(localized: "The Gateway returned an unexpected automation response.")
            }
        }
    }

    /// 统一网关 RPC 通道：路由快照 + 提交后校验，防止网关切换后误写（参照 AgentPro requestAutomationGateway）。
    @MainActor
    private static func requestGateway(
        appModel: NodeAppModel,
        method: String,
        paramsJSON: String) async throws -> Data
    {
        guard let gatewayID = appModel.connectedGatewayID,
              let route = await appModel.operatorSession.currentRoute(ifGatewayID: gatewayID)
        else {
            throw HomeCronActionError.gatewayDisconnected
        }
        let data = try await appModel.operatorSession.request(
            method: method,
            paramsJSON: paramsJSON,
            timeoutSeconds: 20,
            ifCurrentRoute: route,
            distinguishPreDispatchRouteChange: true)
        guard await appModel.operatorSession.currentRoute() == route else {
            throw HomeCronActionError.gatewayChanged
        }
        return data
    }

    private static func jsonParams(_ value: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw HomeCronActionError.invalidResponse
        }
        return text
    }

    /// 立即运行任务（cron.run，先取 system.info 进程标识，参照 AgentProTab+Cron.swift / AgentAutomationDetailScreen.swift）。
    @MainActor
    static func runCronJob(_ job: CronJob, appModel: NodeAppModel) async throws -> String {
        let systemInfoData = try await Self.requestGateway(
            appModel: appModel,
            method: "system.info",
            paramsJSON: "{}")
        let processInstanceID = try JSONDecoder()
            .decode(SystemInfoResult.self, from: systemInfoData)
            .processinstanceid
        var runParams: [String: Any] = ["id": job.id, "mode": "force"]
        if let processInstanceID {
            runParams["expectedProcessInstanceId"] = processInstanceID
        }
        let data = try await Self.requestGateway(
            appModel: appModel,
            method: "cron.run",
            paramsJSON: try Self.jsonParams(runParams))
        let result = try JSONDecoder().decode(HomeCronRunResult.self, from: data)
        guard result.ok else { throw HomeCronActionError.invalidResponse }
        if result.ran == false, result.enqueued != true {
            return Self.runSkipMessage(result.reason)
        }
        guard result.ran == true || result.enqueued == true else {
            throw HomeCronActionError.invalidResponse
        }
        return result.enqueued == true
            ? String(localized: "Run queued.")
            : String(localized: "Run started.")
    }

    /// 暂停 / 继续任务（cron.update，参数参照 buildAgentAutomationEnabledParams）。
    @MainActor
    static func setCronJobEnabled(_ job: CronJob, enabled: Bool, appModel: NodeAppModel) async throws -> CronJob {
        let data = try await Self.requestGateway(
            appModel: appModel,
            method: "cron.update",
            paramsJSON: try Self.enabledParams(for: job, enabled: enabled))
        return try JSONDecoder().decode(CronJob.self, from: data)
    }

    /// 删除任务（cron.remove）。
    @MainActor
    static func removeCronJob(_ job: CronJob, appModel: NodeAppModel) async throws {
        _ = try await Self.requestGateway(
            appModel: appModel,
            method: "cron.remove",
            paramsJSON: try Self.jsonParams(["id": job.id]))
    }

    private static func enabledParams(for job: CronJob, enabled: Bool) throws -> String {
        guard let revision = job.configrevision, !revision.isEmpty else {
            throw HomeCronActionError.missingRevision
        }
        return try jsonParams([
            "id": job.id,
            "expectedConfigRevision": revision,
            "patch": ["enabled": enabled],
        ])
    }

    private static func runSkipMessage(_ reason: String?) -> String {
        switch reason {
        case "not-due": String(localized: "This automation is not due yet.")
        case "already-running": String(localized: "This automation is already running.")
        case "restart-recovery-pending": String(localized: "Gateway restart recovery is still in progress.")
        case "invalid-spec": String(localized: "This automation has an invalid configuration.")
        case "stopped": String(localized: "The automation scheduler is stopped.")
        default: String(localized: "The Gateway did not start this automation.")
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
    /// 任务管理操作中的 job id（行内进度 / 禁用）。
    @State private var busyJobIDs: Set<String> = []
    /// 单任务操作结果文案（成功提示或失败错误）。
    @State private var jobMessages: [String: HomeJobActionMessage] = [:]
    /// 待删除确认的任务。
    @State private var confirmDeleteJob: CronJob?
    /// 「新建任务」入口是否展开 Agent Pro 自动化区。
    @State private var isPresentingAgentPro = false

    var body: some View {
        List {
            Section {
                newTaskRow
            }

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
            } footer: {
                if !gatewayConnected {
                    Text(String(localized: "Connect a Gateway to manage automations."))
                        .font(OpenClawType.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(HomeCardKind.automation.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog(
            String(localized: "Delete this automation?"),
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible,
            presenting: confirmDeleteJob)
        { job in
            Button(String(localized: "Delete"), role: .destructive) {
                Task { await deleteJob(job) }
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                confirmDeleteJob = nil
            }
        } message: { _ in
            Text(String(localized: "This action cannot be undone."))
        }
        .sheet(isPresented: $isPresentingAgentPro) {
            NavigationStack {
                AgentProTab(
                    directRoute: .cron,
                    headerSidebarAction: nil,
                    headerTitle: String(localized: "Automations"),
                    openSettings: nil)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Close")) {
                                isPresentingAgentPro = false
                            }
                        }
                    }
            }
        }
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

    // MARK: - 新建任务入口

    private var gatewayConnected: Bool {
        appModel.connectedGatewayID != nil
    }

    /// 「新建任务」入口：AgentAutomationDetailScreen 只能编辑已存在任务（init 必须传 CronJob），
    /// 全工程没有 cron.create 流程，因此这里不重造表单，改为跳 Agent Pro 自动化区管理。
    private var newTaskRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isPresentingAgentPro = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(gatewayConnected ? OpenClawBrand.accent : Color.secondary)
                    Text(String(localized: "New Task"))
                        .font(OpenClawType.subheadSemiBold)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(OpenClawType.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .disabled(!gatewayConnected)
            .accessibilityLabel(String(localized: "New Task"))

            Text(String(localized: "Automation creation isn't available in the app. This opens Agent Pro to manage existing tasks."))
                .font(OpenClawType.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmDeleteJob != nil },
            set: { if !$0 { confirmDeleteJob = nil } })
    }

    // MARK: - 任务行

    private func jobRow(_ job: CronJob) -> some View {
        let busy = isBusy(job)
        return VStack(alignment: .leading, spacing: 4) {
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

                if busy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(job.enabled ? String(localized: "On") : String(localized: "Off"))
                        .font(OpenClawType.caption2SemiBold)
                        .foregroundStyle(job.enabled ? OpenClawBrand.accent : .secondary)
                        .lineLimit(1)
                }
            }

            if let message = jobMessages[job.id] {
                Text(message.text)
                    .font(OpenClawType.caption2)
                    .foregroundStyle(message.isError ? Color.red : Color.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !busy {
                Button {
                    Task { await runNow(job) }
                } label: {
                    Label(String(localized: "Run Now"), systemImage: "bolt.fill")
                }
                .tint(OpenClawBrand.accent)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !busy {
                Button(role: .destructive) {
                    confirmDeleteJob = job
                } label: {
                    Label(String(localized: "Delete"), systemImage: "trash")
                }
                Button {
                    Task { await setEnabled(!job.enabled, for: job) }
                } label: {
                    Label(
                        job.enabled ? String(localized: "Pause") : String(localized: "Resume"),
                        systemImage: job.enabled ? "pause.fill" : "play.fill")
                }
                .tint(job.enabled ? Color.orange : OpenClawBrand.ok)
            }
        }
    }

    // MARK: - 数据加载

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        didFail = false
        jobMessages = [:]
        async let statusTask = HomeAutomationCardProvider.fetchCronStatus(appModel: appModel)
        async let jobsTask = HomeAutomationCardProvider.fetchCronJobs(appModel: appModel)
        let (status, jobs) = await (statusTask, jobsTask)
        self.status = status
        self.jobs = jobs
        self.didFail = status == nil && jobs.isEmpty
        isLoading = false
    }

    // MARK: - 任务管理操作

    private func isBusy(_ job: CronJob) -> Bool {
        busyJobIDs.contains(job.id)
    }

    private func runNow(_ job: CronJob) async {
        guard gatewayConnected, !isBusy(job) else { return }
        await performAction(job) {
            try await HomeAutomationCardProvider.runCronJob(job, appModel: appModel)
        }
    }

    private func setEnabled(_ enabled: Bool, for job: CronJob) async {
        guard gatewayConnected, !isBusy(job) else { return }
        await performAction(job) {
            let updated = try await HomeAutomationCardProvider.setCronJobEnabled(
                job, enabled: enabled, appModel: appModel)
            if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[index] = updated
            }
            return String(
                format: enabled
                    ? String(localized: "Enabled %@.")
                    : String(localized: "Paused %@."),
                job.name)
        }
    }

    private func deleteJob(_ job: CronJob) async {
        guard gatewayConnected, !isBusy(job) else { return }
        await performAction(job) {
            try await HomeAutomationCardProvider.removeCronJob(job, appModel: appModel)
            jobs.removeAll { $0.id == job.id }
            return nil
        }
    }

    /// 操作公共入口：行内忙碌标记 + 成功提示 / 失败错误文案。
    private func performAction(_ job: CronJob, action: () async throws -> String?) async {
        busyJobIDs.insert(job.id)
        jobMessages[job.id] = nil
        defer { busyJobIDs.remove(job.id) }
        do {
            if let message = try await action() {
                jobMessages[job.id] = HomeJobActionMessage(text: message, isError: false)
            }
        } catch {
            jobMessages[job.id] = HomeJobActionMessage(text: error.localizedDescription, isError: true)
        }
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