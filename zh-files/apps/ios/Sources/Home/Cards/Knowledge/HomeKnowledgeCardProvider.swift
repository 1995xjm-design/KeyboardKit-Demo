import SwiftUI

/// 「知识」卡 Provider：目的地 = 知识主页（网关文件浏览 + Agent 问答）；
/// 快捷动作 = 浏览文件 / 提问。
/// 实现 B-home 定义的 HomeCardDestinationProviding（只实现、不重新定义协议）。
@MainActor
struct HomeKnowledgeCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.knowledge] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .knowledge else { return nil }
        return AnyView(HomeKnowledgeView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .knowledge else { return nil }
        return [
            HomeCardQuickAction(
                id: "knowledge.files",
                title: String(localized: "Browse Files"),
                icon: "folder",
                destination: { AnyView(HomeKnowledgeFileBrowserHost()) }
            ),
            HomeCardQuickAction(
                id: "knowledge.ask",
                title: String(localized: "Ask a Question"),
                icon: "questionmark.bubble.fill",
                destination: { AnyView(HomeKnowledgeView(focusQuestionOnAppear: true)) }
            ),
        ]
    }
}
