import CoreLocation
import MapKit
import SwiftUI

/// 「出行」主页：行程列表 + 停车位登记，顶部分段切换。
/// 移植自 ClawTalk TravelListView / ParkingView：去掉语音/日历/提醒依赖，数据只存本机。
@MainActor
struct HomeTravelView: View {
    enum TravelSection: String, CaseIterable, Identifiable {
        case trips
        case parking

        var id: String { rawValue }

        var title: String {
            switch self {
            case .trips: String(localized: "Trips")
            case .parking: String(localized: "Parking")
            }
        }
    }

    @State private var store: HomeTravelStore
    @State private var section: TravelSection
    /// 快捷动作「新增行程」：进入后自动弹新增表单（消费一次）。
    @State private var openAddTripOnAppear: Bool

    @State private var showAddTripSheet = false
    @State private var showAddParkingSheet = false
    @State private var noticeMessage: String?
    @State private var statusMessage: String?
    @State private var isLocating = false

    // 行程草稿
    @State private var draftDestination = ""
    @State private var draftDeparture = Date()
    @State private var hasReturn = false
    @State private var draftReturn = Date()
    @State private var draftNotes = ""

    // 停车位草稿（新增/编辑共用）
    @State private var editingSpot: HomeParkingSpot?
    @State private var draftLocation = ""
    @State private var draftNote = ""

    init(initialSection: TravelSection = .trips, openAddTripOnAppear: Bool = false) {
        _store = State(initialValue: HomeTravelStore.shared)
        _section = State(initialValue: initialSection)
        _openAddTripOnAppear = State(initialValue: openAddTripOnAppear)
    }

    var body: some View {
        List {
            Section {
                Picker(String(localized: "Trips"), selection: $section) {
                    ForEach(TravelSection.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)

            switch section {
            case .trips:
                tripsContent
            case .parking:
                parkingContent
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Travel"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    switch section {
                    case .trips:
                        resetTripDraft()
                        showAddTripSheet = true
                    case .parking:
                        resetParkingDraft()
                        showAddParkingSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(section == .trips ? String(localized: "New Trip") : String(localized: "Manual entry"))
            }
        }
        .sheet(isPresented: $showAddTripSheet) {
            addTripSheet
        }
        .sheet(isPresented: $showAddParkingSheet) {
            addParkingSheet
        }
        .alert(
            Text(String(localized: "Notice")),
            isPresented: Binding(
                get: { noticeMessage != nil },
                set: { if !$0 { noticeMessage = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) { noticeMessage = nil }
        } message: {
            Text(noticeMessage ?? "")
        }
        .task {
            guard openAddTripOnAppear else { return }
            openAddTripOnAppear = false
            section = .trips
            resetTripDraft()
            showAddTripSheet = true
        }
    }

    // MARK: - 行程列表

    @ViewBuilder
    private var tripsContent: some View {
        if store.trips.isEmpty {
            Section {
                ContentUnavailableView {
                    Label(String(localized: "No Trips Yet"), systemImage: "airplane")
                } description: {
                    Text(String(localized: "Tap \"+\" to add a trip. Trips and parking spots stay on this device."))
                } actions: {
                    Button(String(localized: "New Trip")) {
                        resetTripDraft()
                        showAddTripSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OpenClawBrand.accent)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            let ongoing = store.trips.filter { $0.travelStatus == .ongoing }
            let upcoming = store.trips.filter { $0.travelStatus == .upcoming }
            let history = store.trips.filter { $0.travelStatus == .history }

            if !ongoing.isEmpty {
                Section {
                    ForEach(ongoing) { trip in
                        tripRow(trip)
                    }
                    .onDelete { deleteTrips($0, in: ongoing) }
                } header: {
                    Text(String(localized: "Ongoing"))
                }
            }
            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { trip in
                        tripRow(trip)
                    }
                    .onDelete { deleteTrips($0, in: upcoming) }
                } header: {
                    Text(String(localized: "Upcoming"))
                }
            }
            if !history.isEmpty {
                Section {
                    ForEach(history) { trip in
                        tripRow(trip)
                    }
                    .onDelete { deleteTrips($0, in: history) }
                } header: {
                    Text(String(localized: "History"))
                }
            }
        }
    }
    private func tripRow(_ trip: HomeTravelTrip) -> some View {
        NavigationLink {
            HomeTravelDetailView(tripID: trip.id, store: store)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(trip.destination)
                        .font(OpenClawType.headline)
                    Spacer(minLength: 8)
                    Text(statusBadgeText(trip))
                        .font(OpenClawType.caption2Medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusBadgeColor(trip).opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(statusBadgeColor(trip))
                }
                Text(dateRangeText(trip))
                    .font(OpenClawType.footnote)
                    .foregroundStyle(.secondary)
                if let notes = trip.notes, !notes.isEmpty {
                    Text(notes)
                        .font(OpenClawType.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                let completion = store.checklistCompletion(for: trip)
                HStack(spacing: 6) {
                    ProgressView(value: completion.total > 0 ? Double(completion.done) / Double(completion.total) : 0)
                        .tint(completion.total > 0 && completion.done == completion.total ? OpenClawBrand.statusSuccess : OpenClawBrand.accent)
                    Text(completion.total > 0 ? "\(completion.done)/\(completion.total)" : String(localized: "No checklist items"))
                        .font(OpenClawType.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func statusBadgeText(_ trip: HomeTravelTrip) -> String {
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

    private func statusBadgeColor(_ trip: HomeTravelTrip) -> Color {
        switch trip.travelStatus {
        case .upcoming: OpenClawBrand.info
        case .ongoing: OpenClawBrand.statusSuccess
        case .history: Color.secondary
        }
    }

    private func dateRangeText(_ trip: HomeTravelTrip) -> String {
        let departure = HomeTravelDateFormat.shortText(trip.departureDate)
        guard let returnDate = trip.returnDate else {
            return String.localizedStringWithFormat(String(localized: "Departs %@"), departure)
        }
        let returnText = HomeTravelDateFormat.shortText(returnDate)
        return String.localizedStringWithFormat(String(localized: "%@ — %@"), departure, returnText)
    }

    private func deleteTrips(_ offsets: IndexSet, in group: [HomeTravelTrip]) {
        for offset in offsets {
            store.deleteTrip(id: group[offset].id)
        }
    }

    // MARK: - 停车位

    @ViewBuilder
    private var parkingContent: some View {
        Section {
            VStack(spacing: 10) {
                Button {
                    recordCurrentLocation()
                } label: {
                    HStack(spacing: 10) {
                        if isLocating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "car.fill")
                        }
                        Text(isLocating ? String(localized: "Getting location…") : String(localized: "Record current location"))
                            .font(OpenClawType.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: OpenClawProMetric.controlRadius, style: .continuous)
                            .fill(OpenClawBrand.accent)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLocating)

                Button {
                    resetParkingDraft()
                    showAddParkingSheet = true
                } label: {
                    Label(String(localized: "Manual entry"), systemImage: "square.and.pencil")
                        .font(OpenClawType.subheadMedium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(OpenClawBrand.accent)

                if let statusMessage {
                    Label(statusMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(OpenClawType.caption)
                        .foregroundStyle(OpenClawBrand.statusWarning)
                }
            }
            .listRowBackground(Color.clear)
        }

        Section {
            if store.parkingSpots.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "No Parking Spots Yet"), systemImage: "parkingsign")
                } description: {
                    Text(String(localized: "Tap \"Record\" to save the current spot, or enter it manually. Data stays on this device."))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(store.parkingSpots) { spot in
                    parkingRow(spot)
                }
            }
        } header: {
            Text(String(localized: "Parking"))
        }
    }

    private func parkingRow(_ spot: HomeParkingSpot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                navigate(to: spot)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3)
                        .foregroundStyle(OpenClawBrand.accent)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(spot.location)
                            .font(OpenClawType.subheadMedium)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(String.localizedStringWithFormat(String(localized: "Recorded %@"), HomeTravelDateFormat.fullText(spot.recordedAt)))
                            .font(OpenClawType.caption)
                            .foregroundStyle(.secondary)
                        if let note = spot.note, !note.isEmpty {
                            Text(note)
                                .font(OpenClawType.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 10) {
                if spot.hasCoordinates {
                    Button {
                        navigate(to: spot)
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel(String(localized: "Navigate to this spot"))
                } else {
                    Image(systemName: "mappin.slash")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(OpenClawBrand.accent)
            .padding(.top, 2)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteParkingSpot(id: spot.id)
            } label: {
                Label(String(localized: "Delete Record"), systemImage: "trash")
            }

            Button {
                editingSpot = spot
                draftLocation = spot.location
                draftNote = spot.note ?? ""
                showAddParkingSheet = true
            } label: {
                Label(String(localized: "Edit"), systemImage: "square.and.pencil")
            }
            .tint(OpenClawBrand.accent)
        }
    }

    // MARK: - 定位记录

    private func recordCurrentLocation() {
        statusMessage = nil
        guard CLLocationManager.locationServicesEnabled() else {
            statusMessage = String(localized: "Location services are off. You can still enter the spot manually.")
            return
        }
        isLocating = true
        Task {
            defer { isLocating = false }
            do {
                let location = try await HomeParkingLocationFetcher().fetch()
                let address = await reverseGeocode(location)
                let spot = HomeParkingSpot(
                    location: address ?? String(localized: "Unknown location"),
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                store.addParkingSpot(spot)
                statusMessage = String.localizedStringWithFormat(String(localized: "Saved: %@"), spot.location)
            } catch let error as HomeParkingLocationError {
                statusMessage = error.localizedMessage
            } catch {
                statusMessage = String(localized: "Location failed. Try again.")
            }
        }
    }

    /// 反向地址解析；失败返回 nil（列表诚实显示坐标/未知位置），不造假地址。
    private func reverseGeocode(_ location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            let parts = [
                placemark.country,
                placemark.administrativeArea,
                placemark.locality,
                placemark.subLocality,
                placemark.thoroughfare,
                placemark.subThoroughfare
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            let joined = parts.joined(separator: " ")
            return joined.isEmpty ? nil : joined
        } catch {
            return nil
        }
    }

    /// 系统地图驾车路线找回（不引第三方 SDK）。
    private func navigate(to spot: HomeParkingSpot) {
        guard let latitude = spot.latitude, let longitude = spot.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.location
        let options: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]
        MKMapItem.openMaps(with: [mapItem], launchOptions: options)
    }

    // MARK: - 新增行程（sheet）

    private var addTripSheet: some View {
        NavigationStack {
            List {
                Section {
                    TextField(String(localized: "e.g. Shanghai"), text: $draftDestination)
                } header: {
                    Text(String(localized: "Destination"))
                }

                Section {
                    DatePicker(String(localized: "Departure"), selection: $draftDeparture, displayedComponents: [.date, .hourAndMinute])
                    Toggle(String(localized: "Set return date"), isOn: $hasReturn)
                    if hasReturn {
                        DatePicker(String(localized: "Return Date"), selection: $draftReturn, displayedComponents: [.date, .hourAndMinute])
                    }
                } header: {
                    Text(String(localized: "Date"))
                }

                Section {
                    TextField(String(localized: "Flight, hotel, itinerary…"), text: $draftNotes, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text(String(localized: "Notes"))
                }

                Section {
                    Button(String(localized: "Save")) { saveTripDraft() }
                        .frame(maxWidth: .infinity)
                    Button(String(localized: "Cancel"), role: .cancel) { showAddTripSheet = false }
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(String(localized: "New Trip"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func resetTripDraft() {
        draftDestination = ""
        draftDeparture = Date()
        hasReturn = false
        draftReturn = Date()
        draftNotes = ""
    }

    private func saveTripDraft() {
        let destination = draftDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else {
            noticeMessage = String(localized: "Please enter a destination")
            return
        }
        if hasReturn && draftReturn < draftDeparture {
            noticeMessage = String(localized: "Return date cannot be earlier than departure")
            return
        }
        let notes = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip = HomeTravelTrip(
            destination: destination,
            departureDate: draftDeparture,
            returnDate: hasReturn ? draftReturn : nil,
            notes: notes.isEmpty ? nil : notes
        )
        store.addTrip(trip)
        showAddTripSheet = false
        noticeMessage = nil
    }

    // MARK: - 停车位登记（sheet，新增/编辑共用）

    private var addParkingSheet: some View {
        NavigationStack {
            List {
                Section {
                    TextField(String(localized: "Spot / location"), text: $draftLocation)
                } header: {
                    Text(String(localized: "Spot / location"))
                }

                Section {
                    TextField(String(localized: "e.g. B3 level, spot 27"), text: $draftNote, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text(String(localized: "Note"))
                }

                Section {
                    Button(String(localized: "Save")) { saveParkingDraft() }
                        .frame(maxWidth: .infinity)
                    Button(String(localized: "Cancel"), role: .cancel) { showAddParkingSheet = false }
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(editingSpot == nil ? String(localized: "Manual Parking Entry") : String(localized: "Edit Parking Spot"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func resetParkingDraft() {
        editingSpot = nil
        draftLocation = ""
        draftNote = ""
    }

    private func saveParkingDraft() {
        let location = draftLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else {
            noticeMessage = String(localized: "Please enter a location")
            return
        }
        let note = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if var spot = editingSpot {
            spot.location = location
            spot.note = note.isEmpty ? nil : note
            store.updateParkingSpot(spot)
            editingSpot = nil
        } else {
            store.addParkingSpot(HomeParkingSpot(location: location, note: note.isEmpty ? nil : note))
        }
        showAddParkingSheet = false
        noticeMessage = nil
    }
}

// MARK: - 定位获取

/// 停车定位错误（面向用户的诚实文案）。
enum HomeParkingLocationError: LocalizedError {
    case timeout
    case denied

    var localizedMessage: String {
        switch self {
        case .timeout: String(localized: "Location timed out. Try again in an open area.")
        case .denied: String(localized: "Location permission is off. You can still enter the spot manually.")
        }
    }
}

/// 一次性定位：CLLocationManager.requestLocation + 20 秒超时兜底（不无限转圈）。
/// 与 ClawTalk ParkingLocationFetcher 同方案，仅 CoreLocation，无额外依赖。
@MainActor
final class HomeParkingLocationFetcher: NSObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var timeoutTask: Task<Void, Never>?

    func fetch() async throws -> CLLocation {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        self.manager = manager
        manager.requestLocation()

        return try await withCheckedThrowingContinuation { continuation in
            MainActor.assumeIsolated {
                self.continuation = continuation
                self.timeoutTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(20))
                    self?.finish(throwing: HomeParkingLocationError.timeout)
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            if let location {
                self.finish(returning: location)
            }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        Task { @MainActor in
            if nsError.domain == kCLErrorDomain && nsError.code == CLError.denied.rawValue {
                self.finish(throwing: HomeParkingLocationError.denied)
            } else {
                self.finish(throwing: nsError)
            }
        }
    }

    private func finish(returning location: CLLocation) {
        guard let continuation else { return }
        self.continuation = nil
        self.timeoutTask?.cancel()
        continuation.resume(returning: location)
    }

    private func finish(throwing error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        self.timeoutTask?.cancel()
        continuation.resume(throwing: error)
    }
}