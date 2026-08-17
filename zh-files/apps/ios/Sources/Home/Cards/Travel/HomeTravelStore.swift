import Foundation
import Observation

/// 出行存储：行程 + 停车位，本地 UserDefaults JSON，数据只保存在本机。
/// 存储 key 与 ClawTalk 完全隔离（独立新存，不混用）。
@Observable
@MainActor
final class HomeTravelStore {

    /// 全局单例：主页目的地 / 列表页 / 详情页共用同一数据。
    static let shared = HomeTravelStore()

    private(set) var trips: [HomeTravelTrip] = []
    private(set) var parkingSpots: [HomeParkingSpot] = []
    var errorMessage: String?

    private let tripsStorageKey = "openclaw_home_travel_trips_v1"
    private let parkingStorageKey = "openclaw_home_travel_parking_v1"

    init() {
        loadTrips()
        loadParking()
    }

    // MARK: - 出行

    func trip(id: UUID) -> HomeTravelTrip? {
        trips.first { $0.id == id }
    }

    @discardableResult
    func addTrip(_ trip: HomeTravelTrip) -> HomeTravelTrip {
        trips.append(trip)
        sortTrips()
        persistTrips()
        return trip
    }

    func updateTrip(_ trip: HomeTravelTrip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index] = trip
        sortTrips()
        persistTrips()
    }

    func deleteTrip(id: UUID) {
        trips.removeAll { $0.id == id }
        persistTrips()
    }

    /// 勾选/取消勾选清单项。
    func toggleChecklistItem(tripID: UUID, itemID: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }),
              let itemIndex = trips[index].checklist.firstIndex(where: { $0.id == itemID })
        else { return }
        trips[index].checklist[itemIndex].done.toggle()
        persistTrips()
    }

    /// 追加清单项（文本已由调用方裁剪，非空才入库）。
    func addChecklistItem(tripID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].checklist.append(HomeTravelChecklistItem(text: trimmed))
        persistTrips()
    }

    /// 清单完成度（诚实统计；清单为空时返回 0/0）。
    func checklistCompletion(for trip: HomeTravelTrip) -> (done: Int, total: Int) {
        let done = trip.checklist.filter(\.done).count
        return (done, trip.checklist.count)
    }

    // MARK: - 停车位

    /// 新增停车记录，最新在前（列表直接取第一行）。
    @discardableResult
    func addParkingSpot(_ spot: HomeParkingSpot) -> HomeParkingSpot {
        parkingSpots.insert(spot, at: 0)
        persistParking()
        return spot
    }

    func updateParkingSpot(_ spot: HomeParkingSpot) {
        guard let index = parkingSpots.firstIndex(where: { $0.id == spot.id }) else { return }
        parkingSpots[index] = spot
        persistParking()
    }

    func deleteParkingSpot(id: String) {
        parkingSpots.removeAll { $0.id == id }
        persistParking()
    }

    // MARK: - 本地持久化

    private func sortTrips() {
        trips.sort { $0.departureDate < $1.departureDate }
    }

    private func loadTrips() {
        guard let data = UserDefaults.standard.data(forKey: tripsStorageKey),
              let decoded = try? JSONDecoder().decode([HomeTravelTrip].self, from: data)
        else {
            trips = []
            return
        }
        trips = decoded
    }

    private func persistTrips() {
        if let data = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(data, forKey: tripsStorageKey)
        }
    }

    private func loadParking() {
        guard let data = UserDefaults.standard.data(forKey: parkingStorageKey),
              let decoded = try? JSONDecoder().decode([HomeParkingSpot].self, from: data)
        else {
            parkingSpots = []
            return
        }
        parkingSpots = decoded.sorted { $0.recordedAt > $1.recordedAt }
    }

    private func persistParking() {
        if let data = try? JSONEncoder().encode(parkingSpots) {
            UserDefaults.standard.set(data, forKey: parkingStorageKey)
        }
    }
}