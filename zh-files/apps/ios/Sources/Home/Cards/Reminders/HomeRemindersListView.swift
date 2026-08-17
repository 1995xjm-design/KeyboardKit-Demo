import SwiftUI

/// 提醒列表页筛选：全部 / 今日 / 已完成。
enum HomeReminderFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .today: String(localized: "Today")
        case .completed: String(localized: "Completed")
        }
    }
}

/// 提醒列表页：按时间排序，每条显示时间 / 标题 / 类别徽章 / 启用开关。
/// 顶部快速添加模板；右上角「+」手动添加；左滑完成 / 右滑删除；
/// 空列表诚实空状态；通知权限被拒时列表底部提示。
/// 数据由 ClawTalk ReminderListView 移植，去掉语音输入（OpenClaw 语音栈未接入本卡）。
@MainActor
struct HomeRemindersListView: View {
    @State private var store: HomeReminderStore
    @State private var showAdd = false
    @State private var draftTitle = ""
    @State private var draftDateTime = Date()
    /// 编辑目标（nil = 新建）；点行进入编辑，预填后保存走 update。
    @State private var editingReminder: HomeReminder?
    @State private var draftCategory: HomeReminderCategory = .custom
    @State private var draftRepeat: HomeReminderRepeat = .none
    @State private var filter: HomeReminderFilter

    init(
        store: HomeReminderStore? = nil,
        autoOpenAdd: Bool = false,
        initialFilter: HomeReminderFilter = .all
    ) {
        _store = State(initialValue: store ?? HomeReminderStore())
        _showAdd = State(initialValue: autoOpenAdd)
        _filter = State(initialValue: initialFilter)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "Filter"), selection: $filter) {
                ForEach(HomeReminderFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityLabel(String(localized: "Filter"))

            List {
                templatesSection

                if store.reminders.isEmpty {
                    emptySection(emptyAll)
                } else if filter == .today && visibleReminders.isEmpty {
                    emptySection(emptyToday)
                } else if filter == .completed && visibleReminders.isEmpty {
                    emptySection(emptyCompleted)
                } else {
                    ForEach(visibleReminders) { reminder in
                        reminderRow(reminder)
                            .swipeActions(edge: .leading) {
                                Button {
                                    store.setCompleted(!reminder.completed, for: reminder.id)
                                } label: {
                                    Label(
                                        reminder.completed ? String(localized: "Undo") : String(localized: "Complete"),
                                        systemImage: reminder.completed ? "arrow.uturn.backward" : "checkmark"
                                    )
                                }
                                .tint(reminder.completed ? .gray : .green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.delete(id: reminder.id)
                                } label: {
                                    Label(String(localized: "Delete"), systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "Reminders"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        resetDraft()
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "New Reminder"))
                }
            }
            .sheet(isPresented: $showAdd) {
                reminderFormSheet
            }
            .task { await store.refreshNotificationPermission() }

            if store.notificationPermissionDenied {
                Text(String(localized: "Notifications are turned off, so reminders will not ring. Enable notifications in System Settings."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
    }

    // MARK: - 分区

    private var templatesSection: some View {
        Section {
            ForEach(HomeReminderStore.defaultTemplates) { template in
                Button {
                    applyTemplate(template)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: template.category.iconName)
                            .font(.headline)
                            .foregroundStyle(OpenClawBrand.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(template.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text("\(String(localized: "Default")) \(timeText(template.defaultTime)) · \(template.repeatType.displayName) · \(String(localized: "tap to adjust"))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(OpenClawBrand.accent)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Label(String(localized: "Quick Add Templates"), systemImage: "bolt.fill")
        } footer: {
            Text(String(localized: "Common sitting / water / medication reminders. Tap to prefill, adjust, then save."))
        }
    }

    @ViewBuilder
    private func emptySection(_ info: (title: String, description: String)) -> some View {
        ContentUnavailableView {
            Label(info.title, systemImage: "bell.badge")
        } description: {
            Text(info.description)
        } actions: {
            if filter == .completed {
                Button(String(localized: "View All")) {
                    filter = .all
                }
                .buttonStyle(.bordered)
            } else {
                Button(String(localized: "Add Reminder")) {
                    resetDraft()
                    showAdd = true
                }
                .buttonStyle(.borderedProminent)
                .tint(OpenClawBrand.accent)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var emptyAll: (title: String, description: String) {
        (
            String(localized: "No Reminders"),
            String(localized: "Tap the + button or a template above to add one. Reminders are stored only on this device.")
        )
    }

    private var emptyToday: (title: String, description: String) {
        (
            String(localized: "Nothing Due Today"),
            String(localized: "No reminders are scheduled for today.")
        )
    }

    private var emptyCompleted: (title: String, description: String) {
        (
            String(localized: "No Completed Reminders"),
            String(localized: "Swipe a reminder to the left to mark it complete.")
        )
    }

    // MARK: - 行

    private func reminderRow(_ reminder: HomeReminder) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(timeLabel(for: reminder))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    HomeReminderBadge(category: reminder.category)
                }
                Text(reminder.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .strikethrough(reminder.completed, color: .secondary)
                Text(subtitle(for: reminder))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                startEditing(reminder)
            }

            Spacer(minLength: 8)

            if reminder.completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(OpenClawBrand.ok)
            } else {
                Toggle("", isOn: enabledBinding(for: reminder))
                    .labelsHidden()
                    .tint(OpenClawBrand.accent)
            }
        }
        .padding(.vertical, 4)
        .opacity(reminder.completed ? 0.55 : 1)
    }

    /// 一次性提醒显示具体日期（今天/明天/周X），重复提醒显示时:分。
    private func timeLabel(for reminder: HomeReminder) -> String {
        if let scheduled = reminder.scheduledDate {
            if Calendar.current.isDateInToday(scheduled) {
                return "\(String(localized: "Today")) \(timeText(scheduled))"
            }
            return "\(dayLabel(scheduled)) \(timeText(scheduled))"
        }
        return timeText(reminder.time)
    }

    private func subtitle(for reminder: HomeReminder) -> String {
        if reminder.repeatType == .none, reminder.scheduledDate != nil {
            return String(localized: "Once")
        }
        return reminder.repeatType.displayName
    }

    private func enabledBinding(for reminder: HomeReminder) -> Binding<Bool> {
        Binding(
            get: { reminder.enabled },
            set: { store.setEnabled($0, for: reminder.id) }
        )
    }

    /// 当前筛选下的可见提醒。
    private var visibleReminders: [HomeReminder] {
        switch filter {
        case .all:
            return store.reminders
        case .today:
            return store.upcomingReminders
                .filter { Calendar.current.isDate($0.fireDate, inSameDayAs: Date()) }
                .map(\.reminder)
        case .completed:
            return store.reminders.filter(\.completed)
        }
    }

    // MARK: - 新建 / 编辑

    private func startEditing(_ reminder: HomeReminder) {
        editingReminder = reminder
        draftTitle = reminder.title
        draftDateTime = reminder.scheduledDate ?? reminder.time
        draftCategory = reminder.category
        draftRepeat = reminder.repeatType
        showAdd = true
    }

    private func applyTemplate(_ template: HomeReminderTemplate) {
        draftTitle = template.title
        draftDateTime = template.defaultTime
        draftCategory = template.category
        draftRepeat = template.repeatType
        editingReminder = nil
        showAdd = true
    }

    private func resetDraft() {
        editingReminder = nil
        draftTitle = ""
        draftDateTime = Date()
        draftCategory = .custom
        draftRepeat = .none
    }

    private var reminderFormSheet: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Title")) {
                    TextField(String(localized: "Reminder title"), text: $draftTitle)
                }
                Section(String(localized: "Time")) {
                    DatePicker(String(localized: "Date & Time"), selection: $draftDateTime, displayedComponents: [.date, .hourAndMinute])
                    if draftRepeat == .none {
                        Text(String(localized: "One-time reminder: rings once at the scheduled time."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Section(String(localized: "Category")) {
                    Picker(String(localized: "Category"), selection: $draftCategory) {
                        ForEach(HomeReminderCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }
                Section(String(localized: "Repeat")) {
                    Picker(String(localized: "Repeat"), selection: $draftRepeat) {
                        ForEach(HomeReminderRepeat.allCases) { repeatType in
                            Text(repeatType.displayName).tag(repeatType)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(editingReminder == nil ? String(localized: "New Reminder") : String(localized: "Edit Reminder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { showAdd = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { saveDraft() }
                        .fontWeight(.semibold)
                        .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(OpenClawBrand.accent)
    }

    private func saveDraft() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        // 一次性提醒带完整日期；重复提醒只取时:分
        let scheduledDate: Date? = draftRepeat == .none ? draftDateTime : nil
        if let editing = editingReminder {
            store.update(
                HomeReminder(
                    id: editing.id,
                    title: title,
                    time: draftDateTime,
                    category: draftCategory,
                    repeatType: draftRepeat,
                    enabled: editing.enabled,
                    scheduledDate: scheduledDate,
                    completed: editing.completed,
                    createdAt: editing.createdAt
                )
            )
        } else {
            store.add(
                HomeReminder(
                    title: title,
                    time: draftDateTime,
                    category: draftCategory,
                    repeatType: draftRepeat,
                    scheduledDate: scheduledDate
                )
            )
        }
        resetDraft()
        showAdd = false
    }

    // MARK: - 时间格式化

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow") }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - 类别徽章

/// 提醒类别徽章：类别名 + 图标 + 主题色胶囊背景。
struct HomeReminderBadge: View {
    let category: HomeReminderCategory

    var body: some View {
        Label(category.displayName, systemImage: category.iconName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(category.themeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(category.themeColor.opacity(0.14), in: Capsule())
    }
}