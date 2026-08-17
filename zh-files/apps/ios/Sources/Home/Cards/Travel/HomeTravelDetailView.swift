import SwiftUI

/// 行程详情：头部（目的地/状态/日期）、出行清单勾选与添加、备注展示与编辑、删除。
@MainActor
struct HomeTravelDetailView: View {
    let tripID: UUID
    @State private var store: HomeTravelStore
    @State private var showNotesEditor = false
    @State private var draftNotes = ""
    @State private var draftChecklistText = ""

    @Environment(\.dismiss) private var dismiss

    init(tripID: UUID, store: HomeTravelStore) {
        self.tripID = tripID
        _store = State(initialValue: store)
    }

    private var trip: HomeTravelTrip? {
        store.trip(id: tripID)
    }

    var body: some View {
        List {
            if let trip {
                headerSection(trip)
                checklistSection(trip)
                notesSection(trip)
            } else {
                Section {
                    ContentUnavailableView {
                        Label(String(localized: "Trip not found"), systemImage: "questionmark.circle")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(trip?.destination ?? String(localized: "Trip Details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    deleteTrip()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(String(localized: "Delete Trip"))
            }
        }
        .sheet(isPresented: $showNotesEditor) {
            notesEditorSheet
        }
    }

    // MARK: - 头部

    @ViewBuilder
    private func headerSection(_ trip: HomeTravelTrip) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(trip.destination)
                        .font(OpenClawType.title3SemiBold)
                    Spacer()
                    Text(statusText(trip))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }
                Text(fullDateRangeText(trip))
                    .font(OpenClawType.subhead)
                    .foregroundStyle(.secondary)
                if let notes = trip.notes, !notes.isEmpty {
                    Text(notes)
                        .font(OpenClawType.subhead)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func statusText(_ trip: HomeTravelTrip) -> String {
        switch trip.travelStatus {
        case .upcoming:
            let days = trip.daysUntilDeparture
            if days == 0 { return String(localized: "Departs today") }
            return String.localizedStringWithFormat(String(localized: "%lld days later"), days)
        case .ongoing:
            return String(localized: "On the way")
        case .history:
            return String(localized: "Ended")
        }
    }

    private func fullDateRangeText(_ trip: HomeTravelTrip) -> String {
        let departure = HomeTravelDateFormat.fullText(trip.departureDate)
        guard let returnDate = trip.returnDate else {
            return String.localizedStringWithFormat(String(localized: "Departs %@"), departure)
        }
        let returnText = HomeTravelDateFormat.fullText(returnDate)
        return String.localizedStringWithFormat(String(localized: "%@ — %@"), departure, returnText)
    }

    // MARK: - 出行清单

    @ViewBuilder
    private func checklistSection(_ trip: HomeTravelTrip) -> some View {
        Section {
            if trip.checklist.isEmpty {
                Text(String(localized: "No checklist items"))
                    .font(OpenClawType.subhead)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(trip.checklist) { item in
                    Button {
                        store.toggleChecklistItem(tripID: trip.id, itemID: item.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.done ? OpenClawBrand.statusSuccess : Color.secondary)
                            Text(item.text)
                                .strikethrough(item.done)
                                .foregroundStyle(item.done ? Color.secondary : Color.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                TextField(String(localized: "Add item"), text: $draftChecklistText)
                    .submitLabel(.done)
                    .onSubmit { addChecklistItem() }
                Button {
                    addChecklistItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .disabled(draftChecklistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text(String(localized: "Checklist"))
        }
    }

    private func addChecklistItem() {
        let text = draftChecklistText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addChecklistItem(tripID: tripID, text: text)
        draftChecklistText = ""
    }

    // MARK: - 备注

    @ViewBuilder
    private func notesSection(_ trip: HomeTravelTrip) -> some View {
        Section {
            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
                    .font(OpenClawType.subhead)
            } else {
                Text(String(localized: "No notes"))
                    .font(OpenClawType.subhead)
                    .foregroundStyle(.secondary)
            }
            Button {
                draftNotes = trip.notes ?? ""
                showNotesEditor = true
            } label: {
                Label(String(localized: "Edit Notes"), systemImage: "square.and.pencil")
                    .font(OpenClawType.subheadMedium)
            }
        } header: {
            Text(String(localized: "Notes"))
        }
    }

    private var notesEditorSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField(String(localized: "Flight, hotel, itinerary…"), text: $draftNotes, axis: .vertical)
                    .lineLimit(4...12)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                Spacer(minLength: 0)
            }
            .navigationTitle(String(localized: "Edit Notes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { showNotesEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { saveNotes() }
                }
            }
        }
    }

    private func saveNotes() {
        guard var trip = store.trip(id: tripID) else { return }
        let trimmed = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.notes = trimmed.isEmpty ? nil : trimmed
        store.updateTrip(trip)
        showNotesEditor = false
    }

    private func deleteTrip() {
        store.deleteTrip(id: tripID)
        dismiss()
    }
}