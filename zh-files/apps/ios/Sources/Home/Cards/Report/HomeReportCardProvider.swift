import SwiftUI

/// 「报告」卡 Provider：目的地 = 报告主页（类型选择 + Agent 生成 + 结果展示/保存/复制/分享）；
/// 快捷动作 = 直接生成日报 / 直接生成周报。
/// 实现 B-home 定义的 HomeCardDestinationProviding（只实现、不重新定义协议）。
@MainActor
struct HomeReportCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.report] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .report else { return nil }
        return AnyView(HomeReportView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .report else { return nil }
        return [
            HomeCardQuickAction(
                id: "report.daily",
                title: String(localized: "Daily Report"),
                icon: "sun.max.fill",
                destination: { AnyView(HomeReportView(initialKind: .daily)) }
            ),
            HomeCardQuickAction(
                id: "report.weekly",
                title: String(localized: "Weekly Report"),
                icon: "calendar",
                destination: { AnyView(HomeReportView(initialKind: .weekly)) }
            ),
        ]
    }
}
