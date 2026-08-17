import SwiftUI

/// 记账统计页：本月收支汇总 + 本月支出按类别占比。
struct ExpenseStatsView: View {
    @State private var store: ExpenseStore

    init(store: ExpenseStore) {
        _store = State(initialValue: store)
    }

    private var summary: ExpenseMonthSummary {
        store.monthSummary()
    }

    /// 本月支出按类别汇总（金额降序）。
    private var categoryTotals: [(category: ExpenseCategory, amount: Double)] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        var totals: [ExpenseCategory: Double] = [:]
        for entry in store.entries where entry.type == .expense && interval.contains(entry.date) {
            totals[entry.category, default: 0] += entry.amount
        }
        return totals.map { (category: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        List {
            Section(String(localized: "Expense.Stats.Month")) {
                summaryRows
            }
            Section(String(localized: "Expense.Stats.ByCategory")) {
                if categoryTotals.isEmpty {
                    Text(String(localized: "Expense.Stats.Empty"))
                        .font(OpenClawType.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(categoryTotals, id: \.category) { item in
                        categoryRow(item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Expense.Stats"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryRows: some View {
        VStack(spacing: 0) {
            summaryRow(
                title: String(localized: "Expense.Home.Expense"),
                amount: summary.expense,
                color: OpenClawBrand.warn,
                icon: "arrow.up.right.circle.fill"
            )
            Divider().padding(.vertical, 4)
            summaryRow(
                title: String(localized: "Expense.Home.Income"),
                amount: summary.income,
                color: OpenClawBrand.ok,
                icon: "arrow.down.left.circle.fill"
            )
            Divider().padding(.vertical, 4)
            summaryRow(
                title: String(localized: "Expense.Home.Balance"),
                amount: summary.balance,
                color: OpenClawBrand.info,
                icon: "equal.circle.fill"
            )
        }
    }

    private func summaryRow(title: String, amount: Double, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
                .font(OpenClawType.body)
                .foregroundStyle(.primary)
            Spacer()
            Text("¥\(amount.expenseAmountText)")
                .font(OpenClawType.headlineBold)
                .foregroundStyle(amount == 0 ? .secondary : color)
        }
    }

    private func categoryRow(_ item: (category: ExpenseCategory, amount: Double)) -> some View {
        let total = summary.expense
        let ratio = total > 0 ? item.amount / total : 0
        return HStack(spacing: 12) {
            Image(systemName: item.category.iconName)
                .foregroundStyle(item.category.themeColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.category.title)
                    .font(OpenClawType.body)
                    .foregroundStyle(.primary)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(uiColor: .systemGray5))
                        Capsule()
                            .fill(item.category.themeColor)
                            .frame(width: proxy.size.width * ratio)
                    }
                }
                .frame(height: 6)
            }
            Spacer()
            Text("¥\(item.amount.expenseAmountText)")
                .font(OpenClawType.subheadMedium)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }
}