import Foundation
import Observation

/// 记账本地存储：UserDefaults JSON。
/// - 增删改查：add / update / delete / entry(id:)
/// - 月汇总：monthSummary(for:) 按日历月统计收入/支出/结余
/// - 诚实空状态：entries 为空即空，不塞假数据
@Observable
@MainActor
final class ExpenseStore {
    private static let defaultsKey = "home.expense.entries.v1"

    /// 全部账目（未排序；排序由调用方按需处理）
    private(set) var entries: [ExpenseEntry] = []

    init() {
        load()
    }

    /// 最新在前的账目（列表用）
    var sortedEntries: [ExpenseEntry] {
        entries.sorted { $0.date > $1.date }
    }

    // MARK: - 增删改查

    /// 新增一条（金额必须 >0，否则返回 nil 不落库）。
    @discardableResult
    func add(
        amount: Double,
        type: ExpenseType,
        category: ExpenseCategory,
        note: String = "",
        date: Date = Date()
    ) -> ExpenseEntry? {
        guard amount > 0 else { return nil }
        let entry = ExpenseEntry(date: date, amount: amount, type: type, category: category, note: note)
        entries.append(entry)
        persist()
        return entry
    }

    /// 更新整条（按 id 替换；id 不存在则忽略）
    func update(_ entry: ExpenseEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        persist()
    }

    /// 删除单条
    func delete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    /// 按 id 查询
    func entry(id: UUID) -> ExpenseEntry? {
        entries.first { $0.id == id }
    }

    // MARK: - 月汇总

    /// 指定日期所在自然月（默认本月）的收入 / 支出 / 结余。
    func monthSummary(for date: Date = Date()) -> ExpenseMonthSummary {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return ExpenseMonthSummary()
        }
        var summary = ExpenseMonthSummary()
        for entry in entries where interval.contains(entry.date) {
            switch entry.type {
            case .income: summary.income += entry.amount
            case .expense: summary.expense += entry.amount
            }
        }
        return summary
    }

    /// 本月支出总额（主页摘要用）
    func monthExpenseTotal(for date: Date = Date()) -> Double {
        monthSummary(for: date).expense
    }

    // MARK: - 持久化

    /// 从 UserDefaults 重新读取（页面重新出现时刷新）。
    func reload() {
        load()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([ExpenseEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }
}