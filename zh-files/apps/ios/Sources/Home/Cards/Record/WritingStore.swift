import Foundation
import Observation

/// 手记草稿本地存储：UserDefaults JSON。
/// - 增删改查：add / update / delete
/// - 诚实空状态：drafts 为空即空，不塞假数据
@Observable
@MainActor
final class WritingStore {
    private static let defaultsKey = "home.record.writing.v1"

    /// 全部草稿（未排序；排序由调用方按需处理）
    private(set) var drafts: [ArticleDraft] = []

    init() {
        load()
    }

    /// 最近更新在前的草稿列表（列表用）
    var sortedDrafts: [ArticleDraft] {
        drafts.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - 增删改查

    /// 新增一篇
    func add(_ draft: ArticleDraft) {
        drafts.append(draft)
        persist()
    }

    /// 更新整篇（按 id 替换；id 不存在则忽略）
    func update(_ draft: ArticleDraft) {
        guard let index = drafts.firstIndex(where: { $0.id == draft.id }) else { return }
        drafts[index] = draft
        persist()
    }

    /// 删除单篇
    func delete(id: UUID) {
        drafts.removeAll { $0.id == id }
        persist()
    }

    // MARK: - 持久化

    private func persist() {
        if let data = try? JSONEncoder().encode(drafts) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([ArticleDraft].self, from: data) else {
            drafts = []
            return
        }
        drafts = decoded
    }
}
