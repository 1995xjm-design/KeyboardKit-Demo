import Foundation

/// 文件类型（登记必选；预设 + 「其他」兜底）。
enum HomeFileSafeType: String, Codable, CaseIterable, Identifiable, Equatable {
    case document
    case photo
    case video
    case audio
    case archive
    case other

    var id: String { rawValue }

    /// 本地化展示名。
    var title: String {
        switch self {
        case .document: String(localized: "Document")
        case .photo: String(localized: "Photo")
        case .video: String(localized: "Video")
        case .audio: String(localized: "Audio")
        case .archive: String(localized: "Archive")
        case .other: String(localized: "Other")
        }
    }

    /// SF Symbol 图标（列表/详情用）。
    var icon: String {
        switch self {
        case .document: "doc.text.fill"
        case .photo: "photo.fill"
        case .video: "film.fill"
        case .audio: "waveform"
        case .archive: "archivebox.fill"
        case .other: "doc.fill"
        }
    }
}

/// 一条本地文件登记（文件名 / 类型 / 存放位置 / 备注 / 登记时间）。
/// 本卡是「本地登记簿」：不读取、不复制 OpenClaw 网关文件，与网关 Files 不混。
struct HomeFileEntry: Identifiable, Codable, Equatable {
    let id: String
    var fileName: String
    var fileType: HomeFileSafeType
    var location: String
    var note: String?
    let registeredAt: Date

    init(
        id: String = UUID().uuidString,
        fileName: String,
        fileType: HomeFileSafeType,
        location: String,
        note: String? = nil,
        registeredAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.fileType = fileType
        self.location = location
        self.note = note
        self.registeredAt = registeredAt
    }
}
/// 登记时间文案（中文短格式，按数据展示，不参与 xcstrings）。
enum HomeFileSafeDateFormat {
    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()

    static func fullText(_ date: Date) -> String {
        full.string(from: date)
    }
}