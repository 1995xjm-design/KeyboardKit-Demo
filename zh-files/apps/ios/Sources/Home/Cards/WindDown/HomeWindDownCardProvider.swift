import SwiftUI

/// 「睡前陪伴」卡 Provider：目的地 = 睡前陪伴主页；快捷动作 = 播放白噪音 / 开始睡前模式。
/// 实现 B-home 定义的 HomeCardDestinationProviding（只实现、不重新定义协议）。
@MainActor
struct HomeWindDownCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.winddown] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .winddown else { return nil }
        return AnyView(HomeWindDownView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .winddown else { return nil }
        return [
            HomeCardQuickAction(
                id: "winddown.noise",
                title: String(localized: "Play White Noise"),
                icon: "waveform",
                destination: { AnyView(HomeWindDownView(launchMode: .noise)) }
            ),
            HomeCardQuickAction(
                id: "winddown.sleep",
                title: String(localized: "Start Sleep Mode"),
                icon: "moon.stars.fill",
                destination: { AnyView(HomeWindDownView(launchMode: .sleep)) }
            ),
        ]
    }
}