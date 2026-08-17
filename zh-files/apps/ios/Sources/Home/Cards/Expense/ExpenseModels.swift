import Foundation
import SwiftUI

/// 记账类型：收入 / 支出。
enum ExpenseType: String, Codable, CaseIterable, Identifiable, Equatable {
    case income
    case expense

    var id: String { rawValue }
}

/// 记账类别：餐饮 / 交通 / 购物 / 居住 / 娱乐 / 医疗 / 其他。
/// 语音解析按关键词映射（见 ExpenseVoiceParser），手动添加可自由选择。
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable, Equatable {
    case food
    case transport
    case shopping
    case housing
    case entertainment
    case medical
    case other

    var id: String { rawValue }
}

/// 一条账目（本地存储，UserDefaults JSON，见 ExpenseStore）。
struct ExpenseEntry: Identifiable, Codable, Equatable {
    let id: UUID
    /// 记账日期（按日分组用；语音记账取录音开始时间，手动添加默认今天）
    var date: Date
    /// 金额（元，>0；语音解析/手动填写均校验）
    var amount: Double
    /// 收入 / 支出
    var type: ExpenseType
    /// 类别
    var category: ExpenseCategory
    /// 备注（语音记账存转写原文，手动填写可自由输入）
    var note: String
    /// 条目创建时间
    let createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Double,
        type: ExpenseType,
        category: ExpenseCategory,
        note: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.type = type
        self.category = category
        self.note = note
        self.createdAt = createdAt
    }
}

/// 月汇总：本月收入 / 支出 / 结余（结余 = 收入 - 支出）。
struct ExpenseMonthSummary: Equatable {
    var income: Double = 0
    var expense: Double = 0

    var balance: Double { income - expense }
}

// MARK: - 金额显示

extension Double {
    /// 金额显示：保留两位小数（如 28 → "28.00"）。
    var expenseAmountText: String {
        String(format: "%.2f", self)
    }
}

// MARK: - 类型 / 类别展示（图标 / 主题色 / 文案）

extension ExpenseType {
    var title: String {
        self == .income ? String(localized: "Expense.Type.Income") : String(localized: "Expense.Type.Expense")
    }

    var iconName: String {
        self == .income ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill"
    }

    var themeColor: Color {
        self == .income ? OpenClawBrand.ok : OpenClawBrand.warn
    }

    var signText: String {
        self == .income ? "+" : "-"
    }
}

extension ExpenseCategory {
    var title: String {
        switch self {
        case .food: return String(localized: "Expense.Category.Food")
        case .transport: return String(localized: "Expense.Category.Transport")
        case .shopping: return String(localized: "Expense.Category.Shopping")
        case .housing: return String(localized: "Expense.Category.Housing")
        case .entertainment: return String(localized: "Expense.Category.Entertainment")
        case .medical: return String(localized: "Expense.Category.Medical")
        case .other: return String(localized: "Expense.Category.Other")
        }
    }

    var iconName: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .housing: return "house.fill"
        case .entertainment: return "gamecontroller.fill"
        case .medical: return "cross.case.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var themeColor: Color {
        switch self {
        case .food: return .orange
        case .transport: return OpenClawBrand.info
        case .shopping: return .pink
        case .housing: return .brown
        case .entertainment: return .purple
        case .medical: return OpenClawBrand.danger
        case .other: return .gray
        }
    }
}