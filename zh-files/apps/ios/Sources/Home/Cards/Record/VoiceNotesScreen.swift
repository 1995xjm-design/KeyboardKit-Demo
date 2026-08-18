import SwiftUI

/// 语音速记页：按日期分组的速记列表 + 底部按住说话录音按钮。
/// - 按住底部按钮说话，松开后自动转写并分类（待办/灵感/日记）
/// - 录音中显示外圈脉冲；转写期间显示「正在整理…」
/// - 无速记时显示诚实空状态（不塞假数据）
struct VoiceNotesScreen: View {
    @State private var store = VoiceNotesStore()
    @State private var recorder = HomeSpeechRecorder()
    @State private var recordingStartedAt: Date?
    @State private var editingEntry: VoiceNoteEntry?
    @State private var showNewNote = false

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
        .navigationTitle(String(localized: "Record.VoiceNotes"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewNote = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(String(localized: "Record.Note.New"))
            }
        }
        .sheet(isPresented: $showNewNote) {
            VoiceNoteEditorView(store: store, entry: nil)
        }
        .sheet(item: $editingEntry) { entry in
            VoiceNoteEditorView(store: store, entry: entry)
        }
        .onDisappear { recorder.cancel(); recordingStartedAt = nil }
    }

    // MARK: - 列表（按日期分组）

    private var entryList: some View {
        List {
            ForEach(daySections) { section in
                Section(RecordDaySection.header(for: section.day)) {
                    ForEach(section.entries) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            VoiceNoteRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(id: entry.id)
                            } label: {
                                Label(String(localized: "Common.Delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private struct VoiceNoteDaySection: Identifiable {
        let day: Date
        let entries: [VoiceNoteEntry]
        var id: Date { day }
    }

    private var daySections: [VoiceNoteDaySection] {
        let grouped = Dictionary(grouping: store.sortedEntries) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { day in
            VoiceNoteDaySection(day: day, entries: (grouped[day] ?? []).sorted { $0.createdAt > $1.createdAt })
        }
    }

    // MARK: - 录音区

    private var recordArea: some View {
        VStack(spacing: 8) {
            statusLabel
            HoldToTalkButton(
                phase: recorder.phase,
                audioLevel: recorder.audioLevel,
                tint: OpenClawBrand.teal,
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
                Text(String(localized: "Record.Hint.HoldToTalk"))
            case .recording:
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let seconds = Int(Date().timeIntervalSince(recordingStartedAt ?? Date()))
                    Text(String(localized: "Recording") + " " + String(format: "%02d:%02d", seconds / 60, seconds % 60))
                }
            case .transcribing:
                Text(String(localized: "Record.Hint.Transcribing"))
            }
        }
        .font(OpenClawType.footnote)
        .foregroundStyle(.secondary)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(OpenClawBrand.textSecondary)
            Text(String(localized: "Record.VoiceNotes.Empty"))
                .font(OpenClawType.headline)
                .foregroundStyle(.secondary)
            Text(String(localized: "Record.VoiceNotes.EmptyHint"))
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
            store.add(VoiceNoteEntry(date: Date(), text: text, category: VoiceNoteCategory.classify(text)))
        }
    }
}

/// 语音速记列表行：分类徽章 + 正文摘要 + 时间。
private struct VoiceNoteRow: View {
    let entry: VoiceNoteEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VoiceNoteCategoryBadge(category: entry.category)
                Spacer()
                Text(RecordDaySection.time(for: entry.createdAt))
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
            }
            Text(entry.text)
                .font(OpenClawType.body)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 4)
    }
}

/// 分类徽章：类别名 + 图标 + 主题色胶囊背景。
private struct VoiceNoteCategoryBadge: View {
    let category: VoiceNoteCategory

    var body: some View {
        Label(category.title, systemImage: category.iconName)
            .font(OpenClawType.caption2SemiBold)
            .foregroundStyle(category.themeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(category.themeColor.opacity(0.14), in: Capsule())
    }
}

/// 语音速记新建/编辑页：正文 + 分类 + 日期，本地保存。
struct VoiceNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let store: VoiceNotesStore
    var entry: VoiceNoteEntry?

    @State private var text: String
    @State private var category: VoiceNoteCategory
    @State private var date: Date

    init(store: VoiceNotesStore, entry: VoiceNoteEntry? = nil) {
        self.store = store
        self.entry = entry
        _text = State(initialValue: entry?.text ?? "")
        _category = State(initialValue: entry?.category ?? .diary)
        _date = State(initialValue: entry?.date ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Record.Note.Content")) {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                }
                Section(String(localized: "Record.Note.Category")) {
                    Picker(String(localized: "Record.Note.Category"), selection: $category) {
                        ForEach(VoiceNoteCategory.allCases) { category in
                            Label(category.title, systemImage: category.iconName)
                                .foregroundStyle(category.themeColor)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section(String(localized: "Record.Note.Date")) {
                    DatePicker(selection: $date, displayedComponents: [.date, .hourAndMinute]) {
                        Text(String(localized: "Record.Note.Date"))
                    }
                }
                if entry != nil {
                    Section {
                        Button(role: .destructive) {
                            deleteAndDismiss()
                        } label: {
                            Text(String(localized: "Common.Delete"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(
                entry == nil ? String(localized: "Record.Note.New") : String(localized: "Record.Note.Edit")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Common.Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Common.Save")) { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let entry {
            var updated = entry
            updated.text = trimmed
            updated.category = category
            updated.date = date
            store.update(updated)
        } else {
            store.add(VoiceNoteEntry(date: date, text: trimmed, category: category))
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let entry {
            store.delete(id: entry.id)
        }
        dismiss()
    }
}
