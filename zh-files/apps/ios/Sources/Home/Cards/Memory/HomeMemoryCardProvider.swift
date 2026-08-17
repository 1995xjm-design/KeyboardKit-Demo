import SwiftUI

/// 「记忆」卡 Provider（G-memory）：
/// destination → 记忆主页（网关 doctor.memory.* RPC：梦境状态 / 梦境日记 / 长期记忆条目）；
/// quickActions → 搜索记忆 / 梦境日记。
/// 实现 B-home 定义的 HomeCardDestinationProviding（只实现、不重新定义协议）。
enum HomeMemoryCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.memory] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .memory else { return nil }
        return AnyView(HomeMemoryView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .memory else { return nil }
        return [
            HomeCardQuickAction(
                id: "memory.search",
                title: String(localized: "Search Memories"),
                icon: "magnifyingglass",
                destination: { AnyView(HomeMemoryView(initialSearchFocused: true)) }
            ),
            HomeCardQuickAction(
                id: "memory.dreamDiary",
                title: String(localized: "Dream Diary"),
                icon: "moon.stars.fill",
                destination: { AnyView(HomeMemoryView(initialSection: .dreamDiary)) }
            ),
        ]
    }
}