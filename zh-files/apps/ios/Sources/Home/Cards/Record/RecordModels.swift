import Foundation
import SwiftUI

// MARK: - 语音速记条目

/// 语音速记条目类别：按转写文本简单规则自动归类（待办 / 灵感 / 其余为日记）。
enum VoiceNoteCategory: String, Codable, CaseIterable, Identifiable, Equatable {
    case diary
    case todo
    case inspiration

    var id: String { rawValue }

    /// 优先级：待办 > 灵感 > 日记。规则点集中在此，后续可替换为语义分类。
    static func classify(_ text: String) -> VoiceNoteCategory {
        let todoKeywords = [
            "提醒我", "提醒一下", "记得", "别忘了", "别忘", "要记得",
            "帮我设", "帮我设置", "帮我定", "设个提醒", "设置提醒", "设提醒",
            "定个提醒", "安排个提醒", "安排提醒"
        ]
        if todoKeywords.contains(where: { text.contains($0) }) {
            return .todo
        }
        let inspirationKeywords = ["灵感", "想法", "点子", "我想", "主意", "创意"]
        if inspirationKeywords.contains(where: { text.contains($0) }) {
            return .inspiration
        }
        return .diary
    }
}

/// 一条语音速记（本地暂存，UserDefaults JSON）。
struct VoiceNoteEntry: Identifiable, Codable, Equatable {
    let id: UUID
    /// 记录日期（按日分组用）
    var date: Date
    /// 转写/手写正文
    var text: String
    /// 自动分类：日记 / 待办 / 灵感
    var category: VoiceNoteCategory
    /// 创建时间
    let createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        text: String,
        category: VoiceNoteCategory,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.category = category
        self.createdAt = createdAt
    }
}

// MARK: - 手记（语音写文章）

/// 文章语气：正式 / 轻松 / 专业 / 感人。
enum ArticleTone: String, Codable, CaseIterable, Identifiable {
    case formal
    case casual
    case professional
    case touching

    var id: String { rawValue }
}

/// 一篇手记草稿。
/// 诚实约定：`generatedByAI` 恒为 false（本地实现未接 AI），列表/详情显示「本地生成（未接 AI）」。
struct ArticleDraft: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    /// 口述要点（可空：纯手动输入场景）
    var outline: [String]?
    var tone: ArticleTone
    let createdAt: Date
    var updatedAt: Date
    /// true = AI 生成；本地实现恒为 false
    var generatedByAI: Bool
    var generationNotice: String?

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        outline: [String]? = nil,
        tone: ArticleTone = .formal,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        generatedByAI: Bool = false,
        generationNotice: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.outline = outline
        self.tone = tone
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.generatedByAI = generatedByAI
        self.generationNotice = generationNotice
    }
}

// MARK: - 会议记录

/// 会议纪要里的一条待办（负责人/截止时间不确定时不编造，保持诚实）。
struct ActionItem: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    /// 负责人（不确定时为 nil）
    var assignee: String?
    /// 截止时间（不确定时为 nil）
    var dueDate: Date?

    init(id: UUID = UUID(), text: String, assignee: String? = nil, dueDate: Date? = nil) {
        self.id = id
        self.text = text
        self.assignee = assignee
        self.dueDate = dueDate
    }
}

/// 一份结构化会议纪要。
/// 诚实约定：`organizedByAI` 恒为 false（本地规则整理），UI 标注「本地整理（未接 AI）」；
/// `rawTranscript` 保留原始转写全文，整理过程不删除、不篡改。
struct MeetingNote: Identifiable, Codable, Equatable {
    let id: UUID
    /// 会议发生日期（= 录音日期）
    var date: Date
    var title: String
    var participants: [String]
    var topics: [String]
    var decisions: [String]
    var actionItems: [ActionItem]
    var summary: String
    /// 原始转写全文
    var rawTranscript: String
    let createdAt: Date
    /// true = AI 整理；本地实现恒为 false
    var organizedByAI: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        participants: [String] = [],
        topics: [String] = [],
        decisions: [String] = [],
        actionItems: [ActionItem] = [],
        summary: String,
        rawTranscript: String,
        createdAt: Date = Date(),
        organizedByAI: Bool = false
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.participants = participants
        self.topics = topics
        self.decisions = decisions
        self.actionItems = actionItems
        self.summary = summary
        self.rawTranscript = rawTranscript
        self.createdAt = createdAt
        self.organizedByAI = organizedByAI
    }
}

// MARK: - 展示扩展（主题色 / 图标 / 文案）

extension VoiceNoteCategory {
    var title: String {
        switch self {
        case .diary: return String(localized: "Record.Category.Diary")
        case .todo: return String(localized: "Record.Category.Todo")
        case .inspiration: return String(localized: "Record.Category.Inspiration")
        }
    }

    var iconName: String {
        switch self {
        case .diary: return "book.closed.fill"
        case .todo: return "checkmark.circle.fill"
        case .inspiration: return "lightbulb.fill"
        }
    }

    var themeColor: Color {
        switch self {
        case .diary: return OpenClawBrand.info
        case .todo: return OpenClawBrand.warn
        case .inspiration: return OpenClawBrand.teal
        }
    }
}

extension ArticleTone {
    var title: String {
        switch self {
        case .formal: return String(localized: "Record.Tone.Formal")
        case .casual: return String(localized: "Record.Tone.Casual")
        case .professional: return String(localized: "Record.Tone.Professional")
        case .touching: return String(localized: "Record.Tone.Touching")
        }
    }
}

extension ArticleDraft {
    /// 生成来源展示文案：本地实现诚实标注。
    var sourceLabel: String {
        generatedByAI ? String(localized: "Record.Source.AI") : String(localized: "Record.Source.Local")
    }
}

extension MeetingNote {
    /// 整理来源展示文案：本地实现诚实标注。
    var organizationLabel: String {
        organizedByAI ? String(localized: "Record.Source.AI") : String(localized: "Record.Meeting.Source.Local")
    }
}

// MARK: - 分组辅助

/// 按天分组标题：今天 / 昨天 / M月d日 星期X；时间 HH:mm。
enum RecordDaySection {
    static func header(for day: Date, relativeTo reference: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Record.Day.Today") }
        if calendar.isDateInYesterday(day) { return String(localized: "Record.Day.Yesterday") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: day)
    }

    static func time(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}