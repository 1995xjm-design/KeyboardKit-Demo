import SwiftUI

/// 文件防丢详情：展示登记字段，可编辑 / 删除。
@MainActor
struct HomeFileSafeDetailView: View {
    let entryID: String
    @State private var store: HomeFileSafeStore
    @State private var showEditor = false

    @Environment(\.dismiss) private var dismiss

    init(entryID: String, store: HomeFileSafeStore) {
        self.entryID = entryID
        _store = State(initialValue: store)
    }

    private var entry: HomeFileEntry? {
        store.entry(id: entryID)
    }

    var body: some View {
        List {
            if let entry {
                Section {
                    LabeledContent {
                        Text(entry.fileName)
                    } label: {
                        Text(String(localized: "File Name"))
                    }
                    LabeledContent {
                        Text(entry.fileType.title)
                    } label: {
                        Text(String(localized: "File Type"))
                    }
                    LabeledContent {
                        Text(entry.location)
                    } label: {
                        Text(String(localized: "Storage Location"))
                    }
                    LabeledContent {
                        Text(HomeFileSafeDateFormat.fullText(entry.registeredAt))
                    } label: {
                        Text(String(localized: "Registered At"))
                    }
                    if let note = entry.note, !note.isEmpty {
                        LabeledContent {
                            Text(note)
                        } label: {
                            Text(String(localized: "Note"))
                        }
                    }
                }

                Section {
                    Button {
                        showEditor = true
                    } label: {
                        Label(String(localized: "Edit"), systemImage: "square.and.pencil")
                    }
                    Button(role: .destructive) {
                        delete()
                    } label: {
                        Label(String(localized: "Delete Registration"), systemImage: "trash")
                            .foregroundStyle(OpenClawBrand.statusError)
                    }
                }
            } else {
                Section {
                    ContentUnavailableView {
                        Label(String(localized: "File registration not found"), systemImage: "questionmark.circle")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(entry?.fileName ?? String(localized: "File Details"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            if let entry {
                HomeFileEntryEditor(entry: entry) { updated in
                    store.update(updated)
                }
            }
        }
    }

    private func delete() {
        store.delete(id: entryID)
        dismiss()
    }
}