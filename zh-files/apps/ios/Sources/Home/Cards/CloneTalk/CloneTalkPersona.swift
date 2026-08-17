import Foundation
import Observation

/// AI 分身口吻风格（沿用 ClawTalk CloneStyle 四档，文案本地化）。
enum CloneTalkTone: String, Codable, CaseIterable, Identifiable {
    case casual
    case friendly
    case formal
    case concise

    var id: String { rawValue }

    var label: String {
        switch self {
        case .casual: String(localized: "Casual")
        case .friendly: String(localized: "Friendly")
        case .formal: String(localized: "Formal")
        case .concise: String(localized: "Concise")
        }
    }

    /// 拼进人设注入消息的语气指令。
    var instruction: String {
        switch self {
        case .casual: String(localized: "Use a casual, conversational tone.")
        case .friendly: String(localized: "Use a lively, warm tone with a touch of humor.")
        case .formal: String(localized: "Use a formal, polished tone.")
        case .concise: String(localized: "Be concise, direct, and to the point.")
        }
    }
}

/// AI 分身人设（本地存储，仅本机）。
struct CloneTalkPersona: Codable, Equatable {
    var name: String
    var personality: String
    var tone: CloneTalkTone
    var avatarEmoji: String

    static let defaultName = String(localized: "AI Clone")

    static var `default`: CloneTalkPersona {
        CloneTalkPersona(
            name: defaultName,
            personality: "",
            tone: .casual,
            avatarEmoji: "🤖")
    }

    /// 是否仍是出厂默认人设（未做任何自定义）。
    var isUncustomized: Bool {
        name == Self.defaultName
            && personality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && tone == .casual
            && avatarEmoji == "🤖"
    }

    /// 人设注入消息（发给网关会话的首条消息，让 Agent 全程保持人设）。
    var setupMessage: String {
        var lines: [String] = [
            String(
                localized: "From now on you are \"\(name)\", an AI clone that chats with me in character.")
        ]
        let trimmedPersonality = personality.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPersonality.isEmpty {
            lines.append(String(localized: "Character: \(trimmedPersonality)"))
        }
        lines.append(tone.instruction)
        lines.append(
            String(localized: "Stay in this character for every reply. Start with a short greeting."))
        return lines.joined(separator: "\n")
    }

    /// 人设更新后发给已有会话的消息：让 Agent 切换/覆盖新设定。
    var updateMessage: String {
        var lines: [String] = [
            String(
                localized: "My persona has been updated. From now on you are \"\(name)\".")
        ]
        let trimmedPersonality = personality.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPersonality.isEmpty {
            lines.append(String(localized: "Character: \(trimmedPersonality)"))
        }
        lines.append(tone.instruction)
        lines.append(String(localized: "Reply according to this updated persona from now on."))
        return lines.joined(separator: "\n")
    }
}

/// AI 分身人设存储：UserDefaults JSON，本地保存。
/// 每次保存递增 revision（聊天页据此判断是否重注入更新后的人设）。
@Observable
@MainActor
final class CloneTalkPersonaStore {
    private(set) var persona: CloneTalkPersona
    private(set) var revision: Int

    private let personaKey = "openclaw_home_clone_talk_persona_v1"
    private let revisionKey = "openclaw_home_clone_talk_persona_revision_v1"

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: personaKey),
           let decoded = try? JSONDecoder().decode(CloneTalkPersona.self, from: data)
        {
            persona = decoded
        } else {
            persona = .default
        }
        revision = max(1, defaults.integer(forKey: revisionKey))
    }

    func save(_ updated: CloneTalkPersona) {
        guard updated != persona else { return }
        persona = updated
        revision += 1
        UserDefaults.standard.set(try? JSONEncoder().encode(updated), forKey: personaKey)
        UserDefaults.standard.set(revision, forKey: revisionKey)
    }
}