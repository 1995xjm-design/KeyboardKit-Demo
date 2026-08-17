import Foundation
import Observation
import OpenClawKit
import OpenClawProtocol

/// 「记忆」数据源（G-memory）：
/// 接 OpenClaw 网关 `doctor.memory.*` RPC：
/// - `doctor.memory.status` → DreamingStatusEnvelope（梦境引擎状态 + 长期/信号/短期记忆条目）；
/// - `doctor.memory.dreamDiary` → DreamDiaryLite（梦境日记文本，本地解析为按天分块）。
///
/// 诚实原则：网关未连接 / RPC 不可用时不造假数据，仅置中文错误文案；
/// 搜索为「已加载条目/日记」的客户端过滤（网关当前无记忆全文搜索 RPC，见 reports/G-memory.md）。
@Observable
@MainActor
final class HomeMemoryStore {
    private(set) var status: DreamingStatusLite?
    private(set) var diary: DreamDiaryLite?
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?
    /// 中文错误文案（网关未连接 / RPC 失败）；nil = 无错误。
    private(set) var errorMessage: String?
    /// 搜索关键字（主页 searchable 双向绑定，跨 section 生效）。
    var searchText = ""

    private var didLoadOnce = false

    /// 是否有可展示的网关数据（用于空态区分「未连接」与「真的没内容」）。
    var hasAnyData: Bool {
        status != nil || diary != nil
    }

    var hasDiary: Bool {
        (diary?.content?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    var promotedEntries: [DreamingEntryLite] {
        status?.promotedEntries ?? []
    }

    var signalEntries: [DreamingEntryLite] {
        status?.signalEntries ?? []
    }

    var shortTermEntries: [DreamingEntryLite] {
        status?.shortTermEntries ?? []
    }

    var diaryDays: [HomeMemoryDiaryDay] {
        HomeMemoryDiaryParser.parse(diary?.content)
    }

    /// 记忆库（长期记忆）条目：按网关给出的顺序，搜索命中保留。
    var filteredPromotedEntries: [DreamingEntryLite] {
        filterEntries(promotedEntries)
    }

    var filteredSignalEntries: [DreamingEntryLite] {
        filterEntries(signalEntries)
    }

    var filteredShortTermEntries: [DreamingEntryLite] {
        filterEntries(shortTermEntries)
    }

    var filteredDiaryDays: [HomeMemoryDiaryDay] {
        let query = trimmedSearch
        guard !query.isEmpty else { return diaryDays }
        return diaryDays.filter { day in
            day.title.localizedCaseInsensitiveContains(query)
                || day.body.localizedCaseInsensitiveContains(query)
        }
    }

    var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 首次进入加载；force = 下拉刷新 / 重试。
    func loadIfNeeded(appModel: NodeAppModel, force: Bool = false) async {
        guard force || !didLoadOnce else { return }
        didLoadOnce = true
        await reload(appModel: appModel)
    }

    func reload(appModel: NodeAppModel) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard let gatewayID = appModel.connectedGatewayID else {
            status = nil
            diary = nil
            errorMessage = String(
                localized: "Connect the OpenClaw gateway to browse memory. Offline memory is not available.")
            return
        }

        let route = await appModel.operatorSession.currentRoute(ifGatewayID: gatewayID)
        async let statusData = request(
            appModel: appModel,
            route: route,
            method: "doctor.memory.status")
        async let diaryData = request(
            appModel: appModel,
            route: route,
            method: "doctor.memory.dreamDiary")

        var statusResult: DreamingStatusEnvelope?
        var diaryResult: DreamDiaryLite?
        var failures = 0

        if let data = await statusData {
            statusResult = try? JSONDecoder().decode(DreamingStatusEnvelope.self, from: data)
            if statusResult == nil { failures += 1 }
        } else {
            failures += 1
        }

        if let data = await diaryData {
            diaryResult = try? JSONDecoder().decode(DreamDiaryLite.self, from: data)
            if diaryResult == nil { failures += 1 }
        } else {
            failures += 1
        }

        if let statusResult {
            status = statusResult.dreaming
        }
        if let diaryResult {
            diary = diaryResult
        }
        lastUpdated = Date()

        if failures == 2 || (statusResult == nil && diaryResult == nil) {
            errorMessage = String(
                localized: "Memory could not be loaded. Check the gateway connection or enable the memory module.")
        } else {
            errorMessage = nil
        }
    }

    // MARK: - 搜索

    private func filterEntries(_ entries: [DreamingEntryLite]) -> [DreamingEntryLite] {
        let query = trimmedSearch
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            entry.path.localizedCaseInsensitiveContains(query)
                || entry.snippet.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - 网关请求

    private func request(
        appModel: NodeAppModel,
        route: GatewayNodeSessionRoute?,
        method: String) async -> Data?
    {
        do {
            return try await appModel.operatorSession.request(
                method: method,
                paramsJSON: "{}",
                timeoutSeconds: 12,
                ifCurrentRoute: route,
                distinguishPreDispatchRouteChange: true)
        } catch {
            return nil
        }
    }
}