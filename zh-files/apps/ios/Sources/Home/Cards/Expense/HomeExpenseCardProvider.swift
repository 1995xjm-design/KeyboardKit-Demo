import SwiftUI

/// 「记账」卡 Provider（D-record）：
/// destination → 记账主页；quickActions → 快速记账 / 账单 / 统计。
enum HomeExpenseCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.expense] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .expense else { return nil }
        return AnyView(ExpenseHomeView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .expense else { return nil }
        return [
            HomeCardQuickAction(
                id: "expense.quick",
                title: String(localized: "Expense.QuickAdd"),
                icon: "yensign.circle.fill",
                destination: { AnyView(ExpenseEditorView(store: ExpenseStore())) }
            ),
            HomeCardQuickAction(
                id: "expense.bills",
                title: String(localized: "Expense.Bills"),
                icon: "list.bullet.rectangle",
                destination: { AnyView(ExpenseHomeView()) }
            ),
            HomeCardQuickAction(
                id: "expense.stats",
                title: String(localized: "Expense.Stats"),
                icon: "chart.pie.fill",
                destination: { AnyView(ExpenseStatsView(store: ExpenseStore())) }
            )
        ]
    }
}