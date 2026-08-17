import Foundation
import Observation

/// 报告类型：日报 / 周报 / 自定义 prompt。
enum HomeReportKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case daily
    case weekly
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: String(localized: "Daily Report")
        case .weekly: String(localized: "Weekly Report")
        case .custom: String(localized: "Custom Report")
        }
    }

    var icon: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        case .custom: return "square.and.pencil"
        }
    }

    var detail: String {
        switch self {
        case .daily: String(localized: "Today's summary, progress and tomorrow's plan")
        case .weekly: String(localized: "This week's review and next week's plan")
        case .custom: String(localized: "Ask the agent with your own prompt")
        }
    }
}

/// 一条已生成的报告（本地历史，只保存在本机）。
struct HomeReportEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: HomeReportKind
    let customPrompt: String
    let text: String
    let generatedAt: Date

    init(
        id: UUID = UUID(),
        kind: HomeReportKind,
        customPrompt: String = "",
        text: String,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.customPrompt = customPrompt
        self.text = text
        self.generatedAt = generatedAt
    }

    var title: String {
        kind.title
    }

    var subtitle: String {
        generatedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

/// 报告历史存储：UserDefaults JSON（与 ClawTalk 完全隔离的独立 key）。
/// 另支持「保存为文件」导出到本机 Documents/OpenClawReports。
@Observable
@MainActor
final class HomeReportStore {

    static let shared = HomeReportStore()

    private(set) var reports: [HomeReportEntry] = []
    var errorMessage: String?

    private let storageKey = "openclaw_home_reports_v1"

    init() {
        load()
    }

    // MARK: - 历史

    @discardableResult
    func add(_ entry: HomeReportEntry) -> HomeReportEntry {
        reports.insert(entry, at: 0)
        persist()
        return entry
    }

    func delete(id: UUID) {
        reports.removeAll { $0.id == id }
        persist()
    }

    func entry(id: UUID) -> HomeReportEntry? {
        reports.first { $0.id == id }
    }

    // MARK: - 导出为文件（保存/分享共用）

    /// 写入 Documents/OpenClawReports/<kind>-<时间戳>.md，返回文件 URL。
    func saveToFile(_ entry: HomeReportEntry) throws -> URL {
        let directory = try Self.reportsDirectory()
        let stamp = Self.fileTimestamp(entry.generatedAt)
        let url = directory.appendingPathComponent(
            "\(entry.kind.rawValue)-\(stamp).md",
            isDirectory: false)
        try entry.text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func reportsDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)
        let directory = documents.appendingPathComponent("OpenClawReports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - 本地持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HomeReportEntry].self, from: data)
        else {
            reports = []
            return
        }
        reports = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(reports) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func fileTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
