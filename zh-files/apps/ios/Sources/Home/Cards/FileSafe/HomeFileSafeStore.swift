import Foundation
import Observation

/// 文件防丢存储：本地文件登记（UserDefaults JSON），数据只保存在本机。
/// 存储 key 与 ClawTalk FileVault / OpenClaw 网关 Files 完全隔离（独立新存）。
@Observable
@MainActor
final class HomeFileSafeStore {

    /// 全局单例：主页目的地 / 列表页 / 详情页共用同一数据。
    static let shared = HomeFileSafeStore()

    private(set) var entries: [HomeFileEntry] = []
    var errorMessage: String?

    private let storageKey = "openclaw_home_filesafe_entries_v1"

    init() {
        load()
    }

    // MARK: - 查询

    func entry(id: String) -> HomeFileEntry? {
        entries.first { $0.id == id }
    }

    /// 搜索：文件名 / 存放位置 / 备注 模糊匹配（大小写不敏感）；空查询返回全部。
    func matching(_ query: String) -> [HomeFileEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { entry in
            entry.fileName.localizedCaseInsensitiveContains(trimmed)
                || entry.location.localizedCaseInsensitiveContains(trimmed)
                || (entry.note?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    // MARK: - 增删改

    /// 新增登记，最新在前。
    @discardableResult
    func add(_ entry: HomeFileEntry) -> HomeFileEntry {
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    func update(_ entry: HomeFileEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        persist()
    }

    func delete(id: String) {
        entries.removeAll { $0.id == id }
        persist()
    }

    // MARK: - 本地持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HomeFileEntry].self, from: data)
        else {
            entries = []
            return
        }
        entries = decoded.sorted { $0.registeredAt > $1.registeredAt }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}