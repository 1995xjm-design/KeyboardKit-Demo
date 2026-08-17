import Foundation
import SwiftUI

/// 本地提醒类别：久坐 / 喝水 / 用药 / 自定义。
/// 由 ClawTalk CareReminderCategory 移植，rawValue 改英文，展示名走本地化。
enum HomeReminderCategory: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case sedentary
    case water
    case medication
    case custom

    var id: String { rawValue }

    /// 展示名（本地化）。
    var displayName: String {
        switch self {
        case .sedentary: String(localized: "Sitting")
        case .water: String(localized: "Water")
        case .medication: String(localized: "Medication")
        case .custom: String(localized: "Custom")
        }
    }

    /// 类别图标（SF Symbols）。
    var iconName: String {
        switch self {
        case .sedentary: "figure.seated.side"
        case .water: "drop.fill"
        case .medication: "pills.fill"
        case .custom: "bell.fill"
        }
    }

    /// 类别主题色（浅色 / 深色下均有对比度，沿用 ClawTalk 语义映射）。
    var themeColor: Color {
        switch self {
        case .sedentary: .orange
        case .water: .blue
        case .medication: .red
        case .custom: .purple
        }
    }
}

/// 提醒重复方式。
/// - none：一次性，到点响一次（指定日期，或今天该时间已过则不再触发）
/// - daily：每天同一时间
/// - workday：工作日（周一至周五）同一时间
enum HomeReminderRepeat: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case none
    case daily
    case workday

    var id: String { rawValue }

    /// 展示名（本地化）。
    var displayName: String {
        switch self {
        case .none: String(localized: "Once")
        case .daily: String(localized: "Daily")
        case .workday: String(localized: "Weekdays")
        }
    }
}

/// 一条本地提醒（UserDefaults 持久化 + UNUserNotificationCenter 本地通知调度共用）。
/// 重复提醒只取「时:分」；一次性提醒可用 scheduledDate 指定完整日期。
struct HomeReminder: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var title: String
    /// 提醒时间（重复提醒只取时/分；一次性提醒取时/分用于展示与兜底）。
    var time: Date
    var category: HomeReminderCategory
    var repeatType: HomeReminderRepeat
    /// 通知开关：关闭后取消已排的本地通知。
    var enabled: Bool
    /// 一次性提醒（.none）的指定日期；nil 时按 time 的时:分走「今天/下一次」。
    var scheduledDate: Date?
    /// 已完成：取消后续通知、不再计入待触发；可再次标记未完成恢复。
    var completed: Bool
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        time: Date = Date(),
        category: HomeReminderCategory,
        repeatType: HomeReminderRepeat = .daily,
        enabled: Bool = true,
        scheduledDate: Date? = nil,
        completed: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.category = category
        self.repeatType = repeatType
        self.enabled = enabled
        self.scheduledDate = scheduledDate
        self.completed = completed
        self.createdAt = createdAt
    }
}

/// 一键添加的默认提醒模板（久坐 / 喝水 / 用药）。
/// 默认时间仅为预填，用户点选后可在新建弹窗里调整再保存。
struct HomeReminderTemplate: Identifiable, Equatable {
    let id: String
    let category: HomeReminderCategory
    /// 模板标题（预填到提醒标题）。
    let title: String
    /// 默认时/分（24 小时制）。
    let hour: Int
    let minute: Int
    /// 默认重复方式。
    let repeatType: HomeReminderRepeat

    var defaultTime: Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }
}