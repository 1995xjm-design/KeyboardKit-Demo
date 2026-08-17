import Foundation
import Observation

/// 语音速记本地存储：UserDefaults JSON。
/// - 增删改查：add / update / delete
/// - 诚实空状态：entries 为空即空，不塞假数据
@Observable
@MainActor
final class VoiceNotesStore {
    private static let defaultsKey = "home.record.voicenotes.v1"

    /// 全部速记（未排序；排序由调用方按需处理）
    private(set) var entries: [VoiceNoteEntry] = []

    init() {
        load()
    }

    /// 最新在前的速记列表（列表用）
    var sortedEntries: [VoiceNoteEntry] {
        entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.createdAt > rhs.createdAt
        }
    }

    // MARK: - 增删改查

    /// 新增一条
    func add(_ entry: VoiceNoteEntry) {
        entries.append(entry)
        persist()
    }

    /// 更新整条（按 id 替换；id 不存在则忽略）
    func update(_ entry: VoiceNoteEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        persist()
    }

    /// 删除单条
    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    // MARK: - 持久化

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([VoiceNoteEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }
}
