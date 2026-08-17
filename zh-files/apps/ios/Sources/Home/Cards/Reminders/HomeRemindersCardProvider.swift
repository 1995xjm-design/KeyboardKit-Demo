import SwiftUI

/// 「提醒」卡 Provider：目的地 = 提醒主页；快捷动作 = 新建提醒 / 今日提醒。
/// 实现 B-home 定义的 HomeCardDestinationProviding（只实现、不重新定义协议）。
/// 数据源：HomeReminderStore（本地 UserDefaults + UNUserNotificationCenter 本地通知）。
@MainActor
struct HomeRemindersCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.reminders] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .reminders else { return nil }
        return AnyView(HomeRemindersListView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .reminders else { return nil }
        return [
            HomeCardQuickAction(
                id: "reminders.add",
                title: String(localized: "New Reminder"),
                icon: "plus.circle.fill",
                destination: { AnyView(HomeRemindersListView(autoOpenAdd: true)) }
            ),
            HomeCardQuickAction(
                id: "reminders.today",
                title: String(localized: "Today's Reminders"),
                icon: "sun.max.fill",
                destination: { AnyView(HomeRemindersListView(initialFilter: .today)) }
            ),
        ]
    }
}