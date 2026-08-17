import SwiftUI

/// 「AI 分身」卡 Provider（G-memory）：
/// destination → 分身主页（人设 + 聊天入口）；quickActions → 开始聊天 / 设置人设。
/// 实现 B-home 定义的 HomeCardDestinationProviding（只实现、不重新定义协议）。
enum HomeCloneTalkCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.cloneTalk] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .cloneTalk else { return nil }
        return AnyView(CloneTalkHomeView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .cloneTalk else { return nil }
        return [
            HomeCardQuickAction(
                id: "cloneTalk.chat",
                title: String(localized: "Start Chat"),
                icon: "bubble.left.and.bubble.right.fill",
                destination: { AnyView(CloneTalkChatView()) }
            ),
            HomeCardQuickAction(
                id: "cloneTalk.persona",
                title: String(localized: "Edit Persona"),
                icon: "person.crop.circle.badge.gearshape",
                destination: { AnyView(CloneTalkHomeView(launchPersonaEditor: true)) }
            ),
        ]
    }
}