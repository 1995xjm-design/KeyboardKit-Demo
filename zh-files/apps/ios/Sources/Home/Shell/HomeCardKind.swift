import SwiftUI

/// 主页可配置卡片种类（B-home）。
///
/// 布局约定：
/// - 顶部语音助手大卡固定（C-voice 实现，不进本枚举）；
/// - OPEN CLAW 卡固定第一张（A-root 路由，不进本枚举、不参与 enabled 存储与排序）；
/// - 本枚举 = 12 张可配置卡（已删除 ClawTalk 的 keyboard / emergency）。
enum HomeCardKind: String, CaseIterable, Identifiable, Hashable, Codable {
    case memory
    case cloneTalk
    case record
    case reminders
    case health
    case report
    case expense
    case travel
    case knowledge
    case automation
    case fileSafe
    case winddown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memory: String(localized: "Memory")
        case .cloneTalk: String(localized: "AI Clone")
        case .record: String(localized: "Record")
        case .reminders: String(localized: "Reminders")
        case .health: String(localized: "Health")
        case .report: String(localized: "Report")
        case .expense: String(localized: "Expense")
        case .travel: String(localized: "Travel")
        case .knowledge: String(localized: "Knowledge")
        case .automation: String(localized: "Automation")
        case .fileSafe: String(localized: "File Safe")
        case .winddown: String(localized: "Wind Down")
        }
    }

    var icon: String {
        switch self {
        case .memory: return "brain.head.profile"
        case .cloneTalk: return "person.crop.circle.badge.clock"
        case .record: return "square.and.pencil"
        case .reminders: return "bell.badge.fill"
        case .health: return "heart.fill"
        case .report: return "doc.text.fill"
        case .expense: return "yensign.circle.fill"
        case .travel: return "airplane"
        case .knowledge: return "books.vertical.fill"
        case .automation: return "clock.badge.checkmark"
        case .fileSafe: return "lock.doc.fill"
        case .winddown: return "moon.stars.fill"
        }
    }

    /// 卡面色相：全部 OpenClaw 语义色（OpenClawBrand），
    /// 仅 expense 用系统 mint（swiftlint openclaw_design_colors 未禁用色，且非语义状态色）。
    /// 相近语义映射，深浅色自适应；禁止裸系统 status 色（red/green/blue/purple 等）。
    var tint: Color {
        switch self {
        case .memory: return OpenClawBrand.info
        case .cloneTalk: return OpenClawBrand.carapaceCoral
        case .record: return OpenClawBrand.teal
        case .reminders: return OpenClawBrand.warn
        case .health: return OpenClawBrand.ok
        case .report: return OpenClawBrand.accent
        case .expense: return Color.mint
        case .travel: return Color.indigo
        case .knowledge: return OpenClawBrand.carapaceSea
        case .automation: return OpenClawBrand.accentHot
        case .fileSafe: return OpenClawBrand.teal
        case .winddown: return OpenClawBrand.info
        }
    }

    var summary: String {
        switch self {
        case .memory: return String(localized: "Personal profile · memory search")
        case .cloneTalk: return String(localized: "Replies drafted in your voice")
        case .record: return String(localized: "Voice diary · dictation · meetings")
        case .reminders: return String(localized: "Reminders · anniversaries · geofence")
        case .health: return String(localized: "Steps · habits · health report")
        case .report: return String(localized: "Daily briefing · weekly and monthly reports")
        case .expense: return String(localized: "Voice bookkeeping · monthly summary")
        case .travel: return String(localized: "Travel manager · parking spot")
        case .knowledge: return String(localized: "Knowledge base Q&A · summaries")
        case .automation: return String(localized: "Scheduled tasks · gateway sync")
        case .fileSafe: return String(localized: "File registry · backup · expiry reminders")
        case .winddown: return String(localized: "Goodnight · white noise · tomorrow preview")
        }
    }

    /// 所有可配置卡默认中卡（一行 2 个，明哥要求；small 已废弃）。
    var defaultSize: HomeCardSize {
        .medium
    }
}