import Foundation
import Observation
import UserNotifications

/// 本地提醒存储：UserDefaults（JSON 序列化）增删改查 + 到点本地通知调度。
/// 由 ClawTalk CareReminderStore 移植，去掉对 ClawTalk 日志/权限框架的依赖；
/// 首次新建提醒时通过 UNUserNotificationCenter 申请通知权限，被拒则诚实提示。
///
/// 通知：
/// - 权限在用户第一次新建提醒时申请（.alert + .sound + .badge），不提前弹框。
/// - 到点响铃 content.sound = .default。
/// - daily 用「时:分」重复的日历触发器；workday 拆成 5 个工作日周重复触发器；
///   一次性（none）只排下一次触发（scheduledDate 指定日期，或今天时间已过则不排，
///   列表照常保留，诚实显示）。
@Observable
@MainActor
final class HomeReminderStore {

    private(set) var reminders: [HomeReminder] = []
    /// 通知权限被系统拒绝时置 true（列表页用于提示，不反复弹授权框）。
    private(set) var notificationPermissionDenied = false
    /// 最近一次调度错误（页面可选展示）。
    var errorMessage: String?

    private let storageKey = "openclaw_home_reminders_v1"
    /// Calendar：1=周日 … 6=周五
    private let workdayWeekdays = [2, 3, 4, 5, 6]

    init() {
        load()
    }

    // MARK: - 查询

    /// 未来将触发的提醒（按触发时间升序），供卡片「最近一条」与计数使用。
    var upcomingReminders: [(reminder: HomeReminder, fireDate: Date)] {
        reminders.compactMap { reminder in
            guard let fireDate = nextFireDate(for: reminder) else { return nil }
            return (reminder, fireDate)
        }
        .sorted { $0.fireDate < $1.fireDate }
    }

    /// 今天还会触发的提醒数量（卡片「今日 N 条」）。
    var todayReminderCount: Int {
        upcomingReminders.filter { Calendar.current.isDate($0.fireDate, inSameDayAs: Date()) }.count
    }

    /// 最近一条将触发的提醒（无则 nil，卡片显示诚实空态）。
    var nextReminder: HomeReminder? {
        upcomingReminders.first?.reminder
    }

    /// 提醒下一次触发时间；已禁用 / 已完成 / 一次性已过点返回 nil。
    func nextFireDate(for reminder: HomeReminder) -> Date? {
        guard reminder.enabled, !reminder.completed else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let time = calendar.dateComponents([.hour, .minute], from: reminder.time)
        let todayTime = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: now)

        switch reminder.repeatType {
        case .none:
            // 一次性提醒带完整日期：到点响一次，过了就不触发
            if let scheduledDate = reminder.scheduledDate {
                return scheduledDate > now ? scheduledDate : nil
            }
            guard let todayTime, todayTime > now else { return nil }
            return todayTime
        case .daily:
            if let todayTime, todayTime > now { return todayTime }
            return calendar.date(byAdding: .day, value: 1, to: todayTime ?? now)
        case .workday:
            var candidate = todayTime ?? now
            if candidate <= now {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            while !Self.isWorkday(candidate) {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            return candidate
        }
    }

    // MARK: - 增删改查

    @discardableResult
    func add(_ reminder: HomeReminder) -> HomeReminder {
        reminders.append(reminder)
        sortByTime()
        persist()
        reschedule(for: reminder)
        return reminder
    }

    func update(_ reminder: HomeReminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        sortByTime()
        persist()
        reschedule(for: reminder)
    }

    func delete(id: String) {
        guard let reminder = reminders.first(where: { $0.id == id }) else { return }
        cancelNotifications(for: reminder)
        reminders.removeAll { $0.id == id }
        persist()
    }

    func setEnabled(_ enabled: Bool, for id: String) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].enabled = enabled
        persist()
        if enabled {
            reschedule(for: reminders[index])
        } else {
            cancelNotifications(for: reminders[index])
        }
    }

    /// 标记完成 / 取消完成：完成时取消已排通知，恢复时重新调度。
    func setCompleted(_ completed: Bool, for id: String) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].completed = completed
        persist()
        if completed {
            cancelNotifications(for: reminders[index])
        } else {
            reschedule(for: reminders[index])
        }
    }

    // MARK: - 本地持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HomeReminder].self, from: data)
        else {
            reminders = []
            return
        }
        reminders = decoded.sorted { timeOfDay($0.time) < timeOfDay($1.time) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func sortByTime() {
        reminders.sort { timeOfDay($0.time) < timeOfDay($1.time) }
    }

    private func timeOfDay(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    // MARK: - 本地通知

    /// 刷新通知权限状态（页面 onAppear 时调用；不弹授权框，被拒时用于提示）。
    func refreshNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationPermissionDenied = false
        case .denied:
            notificationPermissionDenied = true
        case .notDetermined:
            break
        @unknown default:
            notificationPermissionDenied = true
        }
    }

    /// 增删改 / 开关切换后按当前状态重新调度（add/update/开启/恢复时调用）。
    private func reschedule(for reminder: HomeReminder) {
        cancelNotifications(for: reminder)
        guard reminder.enabled, !reminder.completed else { return }
        Task { await scheduleNotifications(for: reminder) }
    }

    private func cancelNotifications(for reminder: HomeReminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: Self.notificationIdentifiers(for: reminder)
        )
    }

    private func scheduleNotifications(for reminder: HomeReminder) async {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        // 首次创建提醒时申请通知权限（.alert + .sound + .badge），被拒则只保存不响铃。
        if settings.authorizationStatus == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            notificationPermissionDenied = !granted
            guard granted else { return }
            settings = await center.notificationSettings()
        }
        let allowed = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        if !allowed {
            if settings.authorizationStatus == .denied {
                notificationPermissionDenied = true
            }
            return
        }
        notificationPermissionDenied = false

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = Self.notificationBody(for: reminder)
        content.sound = .default
        content.userInfo = ["home_reminder_id": reminder.id]

        for (identifier, trigger) in notificationTriggers(for: reminder) {
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                errorMessage = String(localized: "Failed to schedule reminder notification: \(error.localizedDescription)")
            }
        }
    }

    private func notificationTriggers(for reminder: HomeReminder) -> [(String, UNCalendarNotificationTrigger)] {
        let calendar = Calendar.current
        let baseID = Self.notificationBaseIdentifier(for: reminder.id)
        let time = calendar.dateComponents([.hour, .minute], from: reminder.time)

        switch reminder.repeatType {
        case .none:
            guard let fireDate = nextFireDate(for: reminder) else { return [] }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            return [(baseID, UNCalendarNotificationTrigger(dateMatching: components, repeats: false))]
        case .daily:
            return [(baseID, UNCalendarNotificationTrigger(dateMatching: time, repeats: true))]
        case .workday:
            return workdayWeekdays.map { weekday in
                var components = time
                components.weekday = weekday
                return ("\(baseID)-\(weekday)", UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
            }
        }
    }

    private static func notificationBody(for reminder: HomeReminder) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: reminder.time)
        switch reminder.repeatType {
        case .none:
            return "\(reminder.category.displayName) · \(time)"
        case .daily:
            return String(localized: "Daily at %@").replacingOccurrences(of: "%@", with: time)
        case .workday:
            return String(localized: "Weekdays at %@").replacingOccurrences(of: "%@", with: time)
        }
    }

    // MARK: - 通知标识

    static func notificationBaseIdentifier(for reminderID: String) -> String {
        "home-reminder-\(reminderID)"
    }

    static func notificationIdentifiers(for reminder: HomeReminder) -> [String] {
        let base = notificationBaseIdentifier(for: reminder.id)
        switch reminder.repeatType {
        case .none, .daily:
            return [base]
        case .workday:
            return [2, 3, 4, 5, 6].map { "\(base)-\($0)" }
        }
    }

    private static func isWorkday(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return (2...6).contains(weekday)
    }
}

extension HomeReminderStore {
    /// 三类内置默认模板：久坐（工作日上午 10 点）、喝水（每天上午 10:30）、用药（每天早 8 点）。
    static let defaultTemplates: [HomeReminderTemplate] = [
        HomeReminderTemplate(
            id: "template-sedentary",
            category: .sedentary,
            title: String(localized: "Stand up and stretch (sitting reminder)"),
            hour: 10,
            minute: 0,
            repeatType: .workday
        ),
        HomeReminderTemplate(
            id: "template-water",
            category: .water,
            title: String(localized: "Drink some water"),
            hour: 10,
            minute: 30,
            repeatType: .daily
        ),
        HomeReminderTemplate(
            id: "template-medication",
            category: .medication,
            title: String(localized: "Take your medication"),
            hour: 8,
            minute: 0,
            repeatType: .daily
        )
    ]
}