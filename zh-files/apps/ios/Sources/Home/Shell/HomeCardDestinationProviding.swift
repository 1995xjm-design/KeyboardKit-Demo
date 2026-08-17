import SwiftUI

/// 卡片目标页协议（B-home 定义；其他子代理只实现、不定义）。
/// 每个 Provider 只负责自己 supportedKinds 里的卡：
/// - destination 命中返回目标页，未实现返回 nil（主页壳 fallback 显示「建设中」占位视图）；
/// - quickActions 未实现返回 nil（主页壳回落空菜单）。
@MainActor
protocol HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { get }
    static func destination(for kind: HomeCardKind) -> AnyView?
    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]?
}

/// 长按快捷动作（懒构建目标页：仅在长按菜单展示时才构造视图，避免主线程预构建卡顿）。
struct HomeCardQuickAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let destination: () -> AnyView
}

/// 12 个 Provider 统一聚合（CONTRACT 硬约定符号清单，顺序与契约一致）。
/// 主页壳在 HomeTabView 中经此查 destination / quickActions。
@MainActor
enum HomeDestinationProviderRegistry {
    static let all: [any HomeCardDestinationProviding.Type] = [
        HomeAutomationCardProvider.self,
        HomeHealthCardProvider.self,
        HomeRecordCardProvider.self,
        HomeExpenseCardProvider.self,
        HomeTravelCardProvider.self,
        HomeFileSafeCardProvider.self,
        HomeWindDownCardProvider.self,
        HomeRemindersCardProvider.self,
        HomeMemoryCardProvider.self,
        HomeCloneTalkCardProvider.self,
        HomeReportCardProvider.self,
        HomeKnowledgeCardProvider.self,
    ]

    /// 遍历 Provider 查 destination；命中即返回，全未命中返回 nil。
    static func destination(for kind: HomeCardKind) -> AnyView? {
        for provider in Self.all where provider.supportedKinds.contains(kind) {
            if let destination = provider.destination(for: kind) {
                return destination
            }
        }
        return nil
    }

    /// 遍历 Provider 查快捷动作；全未命中返回空数组。
    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction] {
        for provider in Self.all where provider.supportedKinds.contains(kind) {
            if let actions = provider.quickActions(for: kind) {
                return actions
            }
        }
        return []
    }
}