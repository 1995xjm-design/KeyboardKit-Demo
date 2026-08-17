import Foundation
import Observation
import SwiftUI

/// App 根容器路由模型（A-root）：
/// - 控制「语音助手」主页与 OpenClaw 全屏界面之间的切换（OPEN CLAW 卡推入 / 顶部返回）；
/// - 发布网关状态轻量文本（OPEN CLAW 卡角标），数据订阅 OpenClaw 现有网关状态服务，禁止造假。
@MainActor
final class HomeRouterModel: ObservableObject {
    /// OPEN CLAW 卡全屏推入状态。
    @Published var isOpenClawPresented = false

    /// 网关状态轻量文本（OPEN CLAW 卡角标），初始值 = 未连接。
    @Published var gatewayStateText: String = String(localized: "Disconnected")

    private var didStartObservingGatewayStatus = false

    /// 推入 OpenClaw 全屏界面。
    func openOpenClaw() {
        self.isOpenClawPresented = true
    }

    /// 关闭 OpenClaw 全屏界面，返回「语音助手」主页。
    func closeOpenClaw() {
        self.isOpenClawPresented = false
    }

    /// 订阅 OpenClaw 现有网关状态服务（NodeAppModel 可观察属性 + GatewayStatusBuilder 自查），
    /// 状态变化时刷新 gatewayStateText。由根容器在视图出现时调用一次（幂等）。
    func startObservingGatewayStatus(appModel: NodeAppModel) {
        guard !self.didStartObservingGatewayStatus else { return }
        self.didStartObservingGatewayStatus = true
        self.refreshGatewayStateText(appModel: appModel)
        self.observeGatewayStatus(appModel: appModel)
    }

    private func observeGatewayStatus(appModel: NodeAppModel) {
        withObservationTracking {
            _ = appModel.gatewayServerName
            _ = appModel.lastGatewayProblem
            _ = appModel.gatewayStatusText
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.refreshGatewayStateText(appModel: appModel)
                self.observeGatewayStatus(appModel: appModel)
            }
        }
    }

    private func refreshGatewayStateText(appModel: NodeAppModel) {
        switch GatewayStatusBuilder.build(appModel: appModel) {
        case .connected:
            self.gatewayStateText = String(localized: "Connected")
        case .connecting:
            self.gatewayStateText = String(localized: "Connecting")
        case .error:
            self.gatewayStateText = String(localized: "Connection error")
        case .disconnected:
            self.gatewayStateText = String(localized: "Disconnected")
        }
    }
}
