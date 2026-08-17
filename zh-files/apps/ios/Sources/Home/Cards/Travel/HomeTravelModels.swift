import Foundation

/// 出行清单项：文本 + 完成状态。
struct HomeTravelChecklistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var done: Bool

    init(id: UUID = UUID(), text: String, done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }
}

/// 出行状态分组（列表页分区用）。
enum HomeTravelStatus: String, Codable, Equatable {
    case ongoing
    case upcoming
    case history

    var sectionTitle: String {
        switch self {
        case .ongoing: String(localized: "Ongoing")
        case .upcoming: String(localized: "Upcoming")
        case .history: String(localized: "History")
        }
    }
}

/// 一次出行（差旅/旅行）。本地 UserDefaults 存储，数据只保存在本机。
struct HomeTravelTrip: Identifiable, Codable, Equatable {
    let id: UUID
    var destination: String
    var departureDate: Date
    var returnDate: Date?
    var notes: String?
    var checklist: [HomeTravelChecklistItem]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        destination: String,
        departureDate: Date,
        returnDate: Date? = nil,
        notes: String? = nil,
        checklist: [HomeTravelChecklistItem] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.destination = destination
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.notes = notes
        self.checklist = checklist
        self.createdAt = createdAt
    }

    /// 行程结束时刻：有返程 → 返程日次日 00:00；无返程 → 按出发日算。
    var periodEndDate: Date {
        guard let returnDate else { return departureDate }
        return Calendar.current.date(byAdding: .day, value: 1, to: returnDate) ?? returnDate
    }

    /// 距离出发剩余天数：未来为正、当天为 0、已出发为负。
    var daysUntilDeparture: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let departure = calendar.startOfDay(for: departureDate)
        return calendar.dateComponents([.day], from: today, to: departure).day ?? 0
    }

    /// 分组状态：返程已过 → 历史；还没出发 → 即将出发；其余（含无返程已出发）→ 进行中。
    var travelStatus: HomeTravelStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let returnDate, calendar.startOfDay(for: returnDate) < today {
            return .history
        }
        if calendar.startOfDay(for: departureDate) > today {
            return .upcoming
        }
        return .ongoing
    }
}

/// 停车位登记：位置（地址或手动文字）+ 备注 + 可选坐标 + 记录时间。本地存储。
struct HomeParkingSpot: Identifiable, Codable, Equatable {
    let id: String
    var location: String
    var note: String?
    var latitude: Double?
    var longitude: Double?
    var recordedAt: Date

    init(
        id: String = UUID().uuidString,
        location: String,
        note: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.location = location
        self.note = note
        self.latitude = latitude
        self.longitude = longitude
        self.recordedAt = recordedAt
    }

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}

/// 日期文案（列表/卡片共用，中文短格式；日期按数据展示，不参与 xcstrings）。
enum HomeTravelDateFormat {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()

    static func shortText(_ date: Date) -> String {
        short.string(from: date)
    }

    static func fullText(_ date: Date) -> String {
        full.string(from: date)
    }
}