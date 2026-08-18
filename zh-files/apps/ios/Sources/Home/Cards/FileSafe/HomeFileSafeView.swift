import SwiftUI

/// 「文件防丢」主页：本地文件登记簿，搜索 / 列表 / 详情。
/// 注意：OpenClaw 的 Files 是网关文件，本卡是本地登记簿，数据独立、不混。
@MainActor
struct HomeFileSafeView: View {
    @State private var store: HomeFileSafeStore
    @State private var searchText = ""
    @State private var showEditor = false
    /// 快捷动作「登记文件」：进入后自动弹登记表单（消费一次）。
    @State private var openAddOnAppear: Bool
    @State private var editingEntry: HomeFileEntry?

    init(openAddOnAppear: Bool = false) {
        _store = State(initialValue: HomeFileSafeStore.shared)
        _openAddOnAppear = State(initialValue: openAddOnAppear)
    }

    private var visibleEntries: [HomeFileEntry] {
        store.matching(searchText)
    }

    var body: some View {
        List {
            if store.entries.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label(String(localized: "No Files Registered"), systemImage: "lock.doc.fill")
                    } description: {
                        Text(String(localized: "Register important files with name, type and storage location, so nothing is quietly lost. This is a local registry and data stays on this device."))
                    } actions: {
                        Button(String(localized: "Register your first file")) {
                            editingEntry = nil
                            showEditor = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(OpenClawBrand.accent)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else if visibleEntries.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label(String(localized: "No matching files"), systemImage: "magnifyingglass")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(visibleEntries) { entry in
                        fileRow(entry)
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            store.delete(id: visibleEntries[offset].id)
                        }
                    }
                } header: {
                    Text(String(localized: "Entries"))
                } footer: {
                    Text(String(localized: "Local registry only, independent from gateway Files. Swipe a row to delete."))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "File Safe"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(String(localized: "Search files"))
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingEntry = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Register File"))
            }
        }
        .sheet(isPresented: $showEditor) {
            HomeFileEntryEditor(entry: editingEntry) { entry in
                if editingEntry != nil {
                    store.update(entry)
                } else {
                    store.add(entry)
                }
            }
        }
        .task {
            guard openAddOnAppear else { return }
            openAddOnAppear = false
            editingEntry = nil
            showEditor = true
        }
    }

    private func fileRow(_ entry: HomeFileEntry) -> some View {
        NavigationLink {
            HomeFileSafeDetailView(entryID: entry.id, store: store)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: entry.fileType.icon)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(typeColor(entry.fileType))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.fileName)
                        .font(OpenClawType.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(entry.fileType.title)
                        Text("·")
                        Text(entry.location)
                    }
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    Text(String.localizedStringWithFormat(String(localized: "Registered %@"), HomeFileSafeDateFormat.fullText(entry.registeredAt)))
                        .font(OpenClawType.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }

    private func typeColor(_ type: HomeFileSafeType) -> Color {
        switch type {
        case .document: OpenClawBrand.info
        case .photo: OpenClawBrand.teal
        case .video: OpenClawBrand.accent
        case .audio: OpenClawBrand.statusWarning
        case .archive: OpenClawBrand.statusSuccess
        case .other: Color.secondary
        }
    }
}

/// 登记 / 编辑文件条目表单（列表页新增 + 详情页编辑共用）。
@MainActor
struct HomeFileEntryEditor: View {
    let entry: HomeFileEntry?
    let onSave: (HomeFileEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftFileName: String
    @State private var draftType: HomeFileSafeType
    @State private var draftLocation: String
    @State private var draftNote: String
    @State private var errorMessage: String?

    init(entry: HomeFileEntry?, onSave: @escaping (HomeFileEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _draftFileName = State(initialValue: entry?.fileName ?? "")
        _draftType = State(initialValue: entry?.fileType ?? .other)
        _draftLocation = State(initialValue: entry?.location ?? "")
        _draftNote = State(initialValue: entry?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "e.g. Passport scan"), text: $draftFileName)
                } header: {
                    Text(String(localized: "File Name"))
                }

                Section {
                    Picker(String(localized: "File Type"), selection: $draftType) {
                        ForEach(HomeFileSafeType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(String(localized: "File Type"))
                }

                Section {
                    TextField(String(localized: "e.g. Documents / Downloads"), text: $draftLocation)
                } header: {
                    Text(String(localized: "Storage Location"))
                }

                Section {
                    TextField(String(localized: "Optional"), text: $draftNote, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text(String(localized: "Note"))
                }

                Section {
                    Button(String(localized: "Save")) { save() }
                        .frame(maxWidth: .infinity)
                    Button(String(localized: "Cancel"), role: .cancel) { dismiss() }
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(entry == nil ? String(localized: "Register File") : String(localized: "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                Text(String(localized: "Notice")),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(String(localized: "OK"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let name = draftFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = draftLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = String(localized: "Please enter a file name")
            return
        }
        let note = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = HomeFileEntry(
            id: entry?.id ?? UUID().uuidString,
            fileName: name,
            fileType: draftType,
            location: location,
            note: note.isEmpty ? nil : note,
            registeredAt: entry?.registeredAt ?? Date()
        )
        onSave(saved)
        dismiss()
    }
}
