import SwiftUI

/// 记账主页：本月收支摘要 + 按日分组的账目列表 + 底部按住说话记账。
/// - 按住底部按钮说话，松开后语音解析成一条/多条草稿，确认后全部保存
/// - 解析不出金额时诚实提示改用手动添加
/// - 无账目时显示诚实空状态（不塞假数据）
struct ExpenseHomeView: View {
    @State private var store = ExpenseStore()
    @State private var recorder = HomeSpeechRecorder()
    @State private var recordingStartedAt: Date?
    @State private var showNewEntry = false
    @State private var editingEntry: ExpenseEntry?
    @State private var showStats = false
    @State private var showDrafts = false
    @State private var drafts: [ExpenseVoiceParser.Draft] = []
    @State private var showNoDraftsAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if store.sortedEntries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            recordArea
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(String(localized: "Expense.Card"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showStats = true
                } label: {
                    Image(systemName: "chart.pie.fill")
                }
                .accessibilityLabel(String(localized: "Expense.Stats"))
                Button {
                    showNewEntry = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Expense.Editor.New"))
            }
        }
        .sheet(isPresented: $showNewEntry) {
            NavigationStack {
                ExpenseEditorView(store: store)
            }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                ExpenseEditorView(store: store, entry: entry)
            }
        }
        .sheet(isPresented: $showStats) {
            NavigationStack {
                ExpenseStatsView(store: store)
            }
        }
        .sheet(isPresented: $showDrafts) {
            ExpenseDraftConfirmView(drafts: drafts, store: store) {
                showDrafts = false
            }
        }
        .alert(String(localized: "Expense.Home.NoDraftsTitle"), isPresented: $showNoDraftsAlert) {
            Button(String(localized: "Common.OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Expense.Home.NoDraftsMessage"))
        }
        .onDisappear { recorder.cancel(); recordingStartedAt = nil }
    }

    // MARK: - 列表（月摘要 + 按日分组）

    private var entryList: some View {
        List {
            Section {
                summaryCard
            }
            ForEach(daySections) { section in
                Section(ExpenseDaySection.header(for: section.day)) {
                    ForEach(section.entries) { entry in
                        ExpenseEntryRow(
                            entry: entry,
                            onTap: { editingEntry = entry },
                            onDelete: { store.delete(entry.id) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private struct ExpenseDayGroup: Identifiable {
        let day: Date
        let entries: [ExpenseEntry]
        var id: Date { day }
    }

    private var daySections: [ExpenseDayGroup] {
        let grouped = Dictionary(grouping: store.sortedEntries) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { day in
            ExpenseDayGroup(day: day, entries: (grouped[day] ?? []).sorted { $0.createdAt > $1.createdAt })
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Expense.Home.MonthSummary"))
                .font(OpenClawType.footnoteMedium)
                .foregroundStyle(.secondary)
            let summary = store.monthSummary()
            HStack(spacing: 16) {
                summaryStat(
                    title: String(localized: "Expense.Home.Expense"),
                    amount: summary.expense,
                    color: OpenClawBrand.warn,
                    icon: "arrow.up.right.circle.fill"
                )
                summaryStat(
                    title: String(localized: "Expense.Home.Income"),
                    amount: summary.income,
                    color: OpenClawBrand.ok,
                    icon: "arrow.down.left.circle.fill"
                )
                summaryStat(
                    title: String(localized: "Expense.Home.Balance"),
                    amount: summary.balance,
                    color: OpenClawBrand.info,
                    icon: "equal.circle.fill"
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func summaryStat(title: String, amount: Double, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(OpenClawType.caption)
                .foregroundStyle(.secondary)
            Text("¥\(amount.expenseAmountText)")
                .font(OpenClawType.headlineBold)
                .foregroundStyle(amount == 0 ? .secondary : color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 录音区

    private var recordArea: some View {
        VStack(spacing: 8) {
            statusLabel
            HoldToTalkButton(
                phase: recorder.phase,
                audioLevel: recorder.audioLevel,
                tint: Color.mint,
                onHoldBegan: handleHoldBegan,
                onHoldEnded: handleHoldEnded
            )
            if let errorMessage = recorder.errorMessage {
                Text(errorMessage)
                    .font(OpenClawType.caption)
                    .foregroundStyle(OpenClawBrand.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    private var statusLabel: some View {
        Group {
            switch recorder.phase {
            case .idle:
                Text(String(localized: "Expense.Hint.HoldToTalk"))
            case .recording:
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let seconds = Int(Date().timeIntervalSince(recordingStartedAt ?? Date()))
                    Text("录音中 " + String(format: "%02d:%02d", seconds / 60, seconds % 60))
                }
            case .transcribing:
                Text(String(localized: "Expense.Hint.Transcribing"))
            }
        }
        .font(OpenClawType.footnote)
        .foregroundStyle(.secondary)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "yensign.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(OpenClawBrand.textSecondary)
            Text(String(localized: "Expense.Home.Empty"))
                .font(OpenClawType.headline)
                .foregroundStyle(.secondary)
            Text(String(localized: "Expense.Home.EmptyHint"))
                .font(OpenClawType.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 录音处理

    private func handleHoldBegan() {
        guard recorder.phase == .idle else { return }
        Task { @MainActor in
            guard await recorder.requestAuthorization(), recorder.start() else { return }
            recordingStartedAt = Date()
        }
    }

    private func handleHoldEnded() {
        guard recorder.phase == .recording else { return }
        recordingStartedAt = nil
        Task { @MainActor in
            guard let text = await recorder.finish() else { return }
            let parsed = ExpenseVoiceParser.parseAll(text)
            if parsed.isEmpty {
                showNoDraftsAlert = true
                return
            }
            drafts = parsed
            showDrafts = true
        }
    }
}

/// 账目列表行：类别图标 + 类别名 + 备注 + 金额（带正负号）。
private struct ExpenseEntryRow: View {
    let entry: ExpenseEntry
    var onTap: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: entry.category.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(entry.category.themeColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.category.title)
                        .font(OpenClawType.body)
                        .foregroundStyle(.primary)
                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(OpenClawType.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(entry.type.signText)¥\(entry.amount.expenseAmountText)")
                    .font(OpenClawType.subheadSemiBold)
                    .foregroundStyle(entry.type.themeColor)
            }
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "Common.Delete"), systemImage: "trash")
            }
        }
    }
}

/// 语音解析草稿确认页：一次语音可能拆出多笔，逐条展示后一键全部保存。
private struct ExpenseDraftConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    let drafts: [ExpenseVoiceParser.Draft]
    let store: ExpenseStore
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(drafts.enumerated()), id: \.offset) { _, draft in
                        HStack(spacing: 12) {
                            Image(systemName: draft.category.iconName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(draft.category.themeColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(draft.type.title) · \(draft.category.title)")
                                    .font(OpenClawType.body)
                                    .foregroundStyle(.primary)
                                Text(draft.note)
                                    .font(OpenClawType.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text("\(draft.type.signText)¥\(draft.amount.expenseAmountText)")
                                .font(OpenClawType.subheadSemiBold)
                                .foregroundStyle(draft.type.themeColor)
                        }
                    }
                } header: {
                    Text(String(localized: "Expense.Drafts.Header"))
                } footer: {
                    Text(String(localized: "Expense.Drafts.Footer"))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "Expense.Drafts.Title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Common.Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Expense.Drafts.SaveAll")) { saveAll() }
                }
            }
        }
    }

    private func saveAll() {
        for draft in drafts {
            store.add(amount: draft.amount, type: draft.type, category: draft.category, note: draft.note)
        }
        onClose()
        dismiss()
    }
}

/// 记账按日分组标题：今天 / 昨天 / M月d日。
enum ExpenseDaySection {
    static func header(for day: Date, relativeTo reference: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Record.Day.Today") }
        if calendar.isDateInYesterday(day) { return String(localized: "Record.Day.Yesterday") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: day)
    }
}