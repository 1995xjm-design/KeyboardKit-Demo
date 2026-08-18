import SwiftUI

/// 会议记录页：纪要列表（按日期分组）+ 右上角新建（录制 → 本地整理 → 预览编辑保存）。
struct MeetingScreen: View {
    @State private var store = MeetingStore()
    @State private var showRecorder = false
    @State private var editingNote: MeetingNote?

    var body: some View {
        Group {
            if store.sortedNotes.isEmpty {
                emptyState
            } else {
                noteList
            }
        }
        .navigationTitle(String(localized: "Record.Meeting"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showRecorder = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Record.Meeting.New"))
            }
        }
        .sheet(isPresented: $showRecorder) {
            MeetingRecorderView(store: store)
        }
        .sheet(item: $editingNote) { note in
            NavigationStack {
                MeetingEditorView(store: store, note: note, isNew: false)
            }
        }
    }

    private var noteList: some View {
        List {
            ForEach(daySections) { section in
                Section(RecordDaySection.header(for: section.day)) {
                    ForEach(section.notes) { note in
                        Button {
                            editingNote = note
                        } label: {
                            MeetingNoteRow(note: note)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(id: note.id)
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

    private struct MeetingDaySection: Identifiable {
        let day: Date
        let notes: [MeetingNote]
        var id: Date { day }
    }

    private var daySections: [MeetingDaySection] {
        let grouped = Dictionary(grouping: store.sortedNotes) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { day in
            MeetingDaySection(day: day, notes: (grouped[day] ?? []).sorted { $0.createdAt > $1.createdAt })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 40))
                .foregroundStyle(OpenClawBrand.textSecondary)
            Text(String(localized: "Record.Meeting.Empty"))
                .font(OpenClawType.headline)
                .foregroundStyle(.secondary)
            Text(String(localized: "Record.Meeting.EmptyHint"))
                .font(OpenClawType.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 会议纪要列表行：标题 + 来源标注 + 摘要。
private struct MeetingNoteRow: View {
    let note: MeetingNote

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(note.title.isEmpty ? String(localized: "Record.Meeting.Untitled") : note.title)
                    .font(OpenClawType.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text(note.organizationLabel)
                    .font(OpenClawType.caption2Medium)
                    .foregroundStyle(OpenClawBrand.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(OpenClawBrand.textSecondary.opacity(0.12), in: Capsule())
            }
            Text(note.summary.isEmpty ? String(localized: "Record.Meeting.NoSummary") : note.summary)
                .font(OpenClawType.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 4)
    }
}

/// 会议记录录制页：按住说话 → 转写 → 本地整理 → 预览/编辑保存。
struct MeetingRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    let store: MeetingStore

    @State private var recorder = HomeSpeechRecorder()
    @State private var recordingStartedAt: Date?
    @State private var transcript = ""
    @State private var participantsText = ""
    @State private var organizedNote: MeetingNote?

    var body: some View {
        NavigationStack {
            if let organizedNote {
                MeetingEditorView(store: store, note: organizedNote, isNew: true, participantsText: participantsText)
            } else {
                recorderBody
            }
        }
        .onDisappear { recorder.cancel(); recordingStartedAt = nil }
    }

    private var recorderBody: some View {
        VStack(spacing: 0) {
            List {
                Section(String(localized: "Record.Meeting.Participants")) {
                    TextField(
                        String(localized: "Record.Meeting.ParticipantsPlaceholder"),
                        text: $participantsText,
                        axis: .vertical
                    )
                        .lineLimit(1...3)
                }
                Section(String(localized: "Record.Meeting.Transcript")) {
                    Text(transcript.isEmpty ? String(localized: "Record.Meeting.TranscriptPlaceholder") : transcript)
                        .font(OpenClawType.body)
                        .foregroundStyle(transcript.isEmpty ? Color.secondary : Color.primary)
                        .frame(minHeight: 110, alignment: .topLeading)
                }
            }
            .listStyle(.insetGrouped)

            Divider()
            recordArea
        }
        .navigationTitle(String(localized: "Record.Meeting.Record"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Common.Cancel")) { dismiss() }
            }
        }
    }

    private var recordArea: some View {
        VStack(spacing: 10) {
            statusLabel
            HoldToTalkButton(
                phase: recorder.phase,
                audioLevel: recorder.audioLevel,
                tint: OpenClawBrand.teal,
                onHoldBegan: handleHoldBegan,
                onHoldEnded: handleHoldEnded
            )
            Button {
                organizeAndEdit()
            } label: {
                Text(String(localized: "Record.Meeting.Organize"))
                    .font(OpenClawType.headlineBold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OpenClawPrimaryActionButtonStyle())
            .disabled(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            transcript = text
        }
    }

    private func organizeAndEdit() {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let participants = participantsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        organizedNote = MeetingLocalOrganizer.makeNote(
            transcript: trimmed,
            title: nil,
            participants: participants,
            date: Date()
        )
    }
}

/// 会议纪要编辑页：标题/日期/参与人/摘要/议题/决定/待办/原始转写，本地保存。
struct MeetingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let store: MeetingStore
    var note: MeetingNote
    var isNew: Bool

    @State private var title: String
    @State private var date: Date
    @State private var participantsText: String
    @State private var summary: String
    @State private var topicsText: String
    @State private var decisionsText: String
    @State private var actionsText: String
    @State private var rawTranscript: String

    init(store: MeetingStore, note: MeetingNote, isNew: Bool, participantsText: String? = nil) {
        self.store = store
        self.note = note
        self.isNew = isNew
        _title = State(initialValue: note.title)
        _date = State(initialValue: note.date)
        _participantsText = State(initialValue: participantsText ?? note.participants.joined(separator: "\n"))
        _summary = State(initialValue: note.summary)
        _topicsText = State(initialValue: note.topics.joined(separator: "\n"))
        _decisionsText = State(initialValue: note.decisions.joined(separator: "\n"))
        _actionsText = State(initialValue: note.actionItems.map { action in
            if let assignee = action.assignee, !assignee.isEmpty {
                return "\(action.text) @\(assignee)"
            }
            return action.text
        }.joined(separator: "\n"))
        _rawTranscript = State(initialValue: note.rawTranscript)
    }

    var body: some View {
        Form {
            Section(String(localized: "Record.Meeting.Title")) {
                TextField(String(localized: "Record.Meeting.TitlePlaceholder"), text: $title)
            }
            Section(String(localized: "Record.Meeting.Date")) {
                DatePicker(selection: $date, displayedComponents: [.date, .hourAndMinute]) {
                    Text(String(localized: "Record.Meeting.Date"))
                }
            }
            Section(String(localized: "Record.Meeting.Participants")) {
                TextField(
                    String(localized: "Record.Meeting.ParticipantsPlaceholder"),
                    text: $participantsText,
                    axis: .vertical
                )
                    .lineLimit(1...4)
            }
            Section(String(localized: "Record.Meeting.Summary")) {
                TextEditor(text: $summary)
                    .frame(minHeight: 70)
            }
            Section(String(localized: "Record.Meeting.Topics")) {
                TextField(String(localized: "Record.Meeting.LinesPlaceholder"), text: $topicsText, axis: .vertical)
                    .lineLimit(1...6)
            }
            Section(String(localized: "Record.Meeting.Decisions")) {
                TextField(String(localized: "Record.Meeting.LinesPlaceholder"), text: $decisionsText, axis: .vertical)
                    .lineLimit(1...6)
            }
            Section {
                TextField(String(localized: "Record.Meeting.ActionsPlaceholder"), text: $actionsText, axis: .vertical)
                    .lineLimit(1...6)
            } header: {
                Text(String(localized: "Record.Meeting.ActionItems"))
            } footer: {
                Text(String(localized: "Record.Meeting.ActionsFooter"))
            }
            Section(String(localized: "Record.Meeting.RawTranscript")) {
                TextEditor(text: $rawTranscript)
                    .frame(minHeight: 90)
            }
        }
        .navigationTitle(String(localized: "Record.Meeting.Edit"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Common.Cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Common.Save")) { save() }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = note
        updated.title = trimmedTitle.isEmpty ? String(localized: "Record.Meeting.Untitled") : trimmedTitle
        updated.date = date
        updated.participants = splitLines(participantsText)
        updated.summary = summary
        updated.topics = splitLines(topicsText)
        updated.decisions = splitLines(decisionsText)
        updated.actionItems = parseActions(actionsText)
        updated.rawTranscript = rawTranscript
        if isNew {
            store.add(updated)
        } else {
            store.update(updated)
        }
        dismiss()
    }

    private func splitLines(_ text: String) -> [String] {
        text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 待办行格式：「文本 @负责人」（负责人可空）。
    private func parseActions(_ text: String) -> [ActionItem] {
        splitLines(text).map { line in
            if let range = line.range(of: " @") {
                let actionText = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let assignee = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return ActionItem(text: actionText, assignee: assignee.isEmpty ? nil : assignee)
            }
            return ActionItem(text: line)
        }
    }
}
