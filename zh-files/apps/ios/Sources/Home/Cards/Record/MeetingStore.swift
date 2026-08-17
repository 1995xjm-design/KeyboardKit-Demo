import Foundation
import Observation

/// 会议记录本地存储：UserDefaults JSON。
/// - 增删改查：add / update / delete
/// - 诚实空状态：notes 为空即空，不塞假数据
@Observable
@MainActor
final class MeetingStore {
    private static let defaultsKey = "home.record.meeting.v1"

    /// 全部会议纪要（未排序；排序由调用方按需处理）
    private(set) var notes: [MeetingNote] = []

    init() {
        load()
    }

    /// 最新在前的纪要列表（列表用）
    var sortedNotes: [MeetingNote] {
        notes.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.createdAt > rhs.createdAt
        }
    }

    // MARK: - 增删改查

    /// 新增一条
    func add(_ note: MeetingNote) {
        notes.append(note)
        persist()
    }

    /// 更新整条（按 id 替换；id 不存在则忽略）
    func update(_ note: MeetingNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index] = note
        persist()
    }

    /// 删除单条
    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        persist()
    }

    // MARK: - 持久化

    private func persist() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([MeetingNote].self, from: data) else {
            notes = []
            return
        }
        notes = decoded
    }
}
