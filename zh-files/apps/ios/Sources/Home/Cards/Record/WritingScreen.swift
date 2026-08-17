import SwiftUI

/// 手记页：文章草稿列表（点击编辑），右上角新建。
struct WritingScreen: View {
    @State private var store = WritingStore()
    @State private var editingDraft: ArticleDraft?
    @State private var showEditor = false

    var body: some View {
        Group {
            if store.sortedDrafts.isEmpty {
                emptyState
            } else {
                draftList
            }
        }
        .navigationTitle(String(localized: "Record.Writing"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingDraft = nil
                    showEditor = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(String(localized: "Record.Note.New"))
            }
        }
        .sheet(isPresented: $showEditor) {
            WritingEditorView(store: store, draft: editingDraft)
        }
    }

    private var draftList: some View {
        List {
            ForEach(store.sortedDrafts) { draft in
                Button {
                    editingDraft = draft
                    showEditor = true
                } label: {
                    WritingListRow(draft: draft)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        store.delete(id: draft.id)
                    } label: {
                        Label(String(localized: "Common.Delete"), systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 40))
                .foregroundStyle(OpenClawBrand.textSecondary)
            Text(String(localized: "Record.Writing.Empty"))
                .font(OpenClawType.headline)
                .foregroundStyle(.secondary)
            Text(String(localized: "Record.Writing.EmptyHint"))
                .font(OpenClawType.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 手记列表行：标题 + 更新时间/字数/来源标注。
private struct WritingListRow: View {
    let draft: ArticleDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(draft.title.isEmpty ? String(localized: "Record.Note.Untitled") : draft.title)
                .font(OpenClawType.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(RecordDaySection.time(for: draft.updatedAt))
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                Text("\(draft.content.count) \(String(localized: "Record.Writing.WordCount"))")
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                Text(draft.sourceLabel)
                    .font(OpenClawType.caption2Medium)
                    .foregroundStyle(OpenClawBrand.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(OpenClawBrand.textSecondary.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

/// 手记新建/编辑页：标题 + 语气 + 正文 + 口述要点（语音/手动）→ 本地整理成文。
struct WritingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let store: WritingStore
    var draft: ArticleDraft?

    @State private var title: String
    @State private var content: String
    @State private var tone: ArticleTone
    @State private var outline: [String]
    @State private var recorder = HomeSpeechRecorder()
    @State private var recordingStartedAt: Date?
    @State private var notice: String?

    init(store: WritingStore, draft: ArticleDraft? = nil) {
        self.store = store
        self.draft = draft
        _title = State(initialValue: draft?.title ?? "")
        _content = State(initialValue: draft?.content ?? "")
        _tone = State(initialValue: draft?.tone ?? .formal)
        _outline = State(initialValue: draft?.outline ?? [])
        _notice = State(initialValue: draft?.generationNotice)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Record.Note.Title")) {
                    TextField(String(localized: "Record.Note.TitlePlaceholder"), text: $title)
                }
                Section(String(localized: "Record.Note.Tone")) {
                    Picker(String(localized: "Record.Note.Tone"), selection: $tone) {
                        ForEach(ArticleTone.allCases) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(String(localized: "Record.Note.Content")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 140)
                }
                Section {
                    ForEach($outline, id: \.self) { $point in
                        TextField(String(localized: "Record.Note.OutlinePoint"), text: $point)
                    }
                    .onDelete { offsets in
                        outline.remove(atOffsets: offsets)
                    }
                    Button {
                        outline.append("")
                    } label: {
                        Label(String(localized: "Record.Note.AddPoint"), systemImage: "plus")
                    }
                    Button {
                        applyLocalFallback()
                    } label: {
                        Label(String(localized: "Record.Note.GenerateFromPoints"), systemImage: "wand.and.stars")
                    }
                    .disabled(cleanOutline.isEmpty)
                } header: {
                    Text(String(localized: "Record.Note.Outline"))
                } footer: {
                    Text(String(localized: "Record.Note.OutlineFooter"))
                }
                Section(String(localized: "Record.Note.Source")) {
                    Text(notice ?? String(localized: "Record.Source.Local"))
                        .font(OpenClawType.footnote)
                        .foregroundStyle(.secondary)
                }
                if draft != nil {
                    Section {
                        Button(role: .destructive) {
                            if let draft {
                                store.delete(id: draft.id)
                            }
                            dismiss()
                        } label: {
                            Text(String(localized: "Common.Delete"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(
                draft == nil ? String(localized: "Record.Note.New") : String(localized: "Record.Note.Edit")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Common.Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Common.Save")) { save() }
                        .disabled(cleanTitle.isEmpty && cleanContent.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                voiceDock
            }
            .onDisappear { recorder.cancel(); recordingStartedAt = nil }
        }
    }

    /// 底部语音要点输入条：按住说话，松开后追加为一条要点。
    private var voiceDock: some View {
        VStack(spacing: 6) {
            if !recorder.partialText.isEmpty {
                Text(recorder.partialText)
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let errorMessage = recorder.errorMessage {
                Text(errorMessage)
                    .font(OpenClawType.caption)
                    .foregroundStyle(OpenClawBrand.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                Group {
                    if recorder.phase == .recording {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            let seconds = Int(Date().timeIntervalSince(recordingStartedAt ?? Date()))
                            Text("录音中 " + String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        }
                    } else {
                        Text(String(localized: "Record.Note.VoiceAddPoint"))
                    }
                }
                .font(OpenClawType.footnote)
                .foregroundStyle(.secondary)
                Spacer()
                HoldToTalkButton(
                    phase: recorder.phase,
                    audioLevel: recorder.audioLevel,
                    compact: true,
                    onHoldBegan: handleHoldBegan,
                    onHoldEnded: handleHoldEnded
                )
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanOutline: [String] {
        outline.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
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
            outline.append(text)
        }
    }

    /// 本地降级整理：要点拼接成段落 → 正文；未接 AI，诚实标注。
    private func applyLocalFallback() {
        let points = cleanOutline
        guard !points.isEmpty else { return }
        content = WritingLocalFallback.buildParagraphs(from: points).joined(separator: "\n\n")
        if cleanTitle.isEmpty {
            title = WritingLocalFallback.resolveTitle(firstPoint: points.first)
        }
        notice = String(localized: "Record.Source.Local")
    }

    private func save() {
        let resolvedTitle = cleanTitle.isEmpty ? String(localized: "Record.Note.Untitled") : cleanTitle
        let resolvedOutline = cleanOutline.isEmpty ? nil : cleanOutline
        if let draft {
            var updated = draft
            updated.title = resolvedTitle
            updated.content = cleanContent
            updated.outline = resolvedOutline
            updated.tone = tone
            updated.updatedAt = Date()
            updated.generationNotice = notice
            store.update(updated)
        } else {
            store.add(ArticleDraft(
                title: resolvedTitle,
                content: cleanContent,
                outline: resolvedOutline,
                tone: tone,
                generatedByAI: false,
                generationNotice: notice
            ))
        }
        dismiss()
    }
}