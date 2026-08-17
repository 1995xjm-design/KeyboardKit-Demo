import SwiftUI

/// 「出行」卡 Provider：目的地 = 出行主页（行程 + 停车位）；快捷动作 = 新增行程 / 停车位。
/// 实现 B-home 定义的 HomeCardDestinationProviding（只实现、不重新定义协议）。
@MainActor
struct HomeTravelCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.travel] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .travel else { return nil }
        return AnyView(HomeTravelView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .travel else { return nil }
        return [
            HomeCardQuickAction(
                id: "travel.newTrip",
                title: String(localized: "New Trip"),
                icon: "plus",
                destination: { AnyView(HomeTravelView(openAddTripOnAppear: true)) }
            ),
            HomeCardQuickAction(
                id: "travel.parking",
                title: String(localized: "Parking"),
                icon: "parkingsign.circle.fill",
                destination: { AnyView(HomeTravelView(initialSection: .parking)) }
            ),
        ]
    }
}