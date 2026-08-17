import SwiftUI

/// 「文件防丢」卡 Provider：目的地 = 文件防丢主页；快捷动作 = 登记文件 / 查找。
/// 实现 B-home 定义的 HomeCardDestinationProviding（只实现、不重新定义协议）。
@MainActor
struct HomeFileSafeCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.fileSafe] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .fileSafe else { return nil }
        return AnyView(HomeFileSafeView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .fileSafe else { return nil }
        return [
            HomeCardQuickAction(
                id: "fileSafe.register",
                title: String(localized: "Register File"),
                icon: "plus",
                destination: { AnyView(HomeFileSafeView(openAddOnAppear: true)) }
            ),
            HomeCardQuickAction(
                id: "fileSafe.find",
                title: String(localized: "Find File"),
                icon: "magnifyingglass",
                destination: { AnyView(HomeFileSafeView()) }
            ),
        ]
    }
}