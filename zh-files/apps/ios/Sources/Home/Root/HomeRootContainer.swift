import OpenClawKit
import OpenClawProtocol
import SwiftUI

/// App 根容器视图（A-root）：
/// 首屏 = 「语音助手」主页（ClawTalk 卡片墙，由 B-home 的 HomeTabView 呈现），
/// OPEN CLAW 卡点击后全屏推入 OpenClaw 现有界面（RootTabs），顶部提供「← 返回」按钮。
///
/// 环境对象注入链说明：OpenClawApp 在 WindowGroup 中对本视图统一注入
/// appearanceModel / appModel / voiceWake / gatewayController（保持原有链不动），
/// 本视图再通过 environmentObject 注入 HomeRouterModel 给主页使用；
/// 全屏推入的 RootTabs() 从本视图继承同一环境，RootTabs 内部逻辑/布局零改动。
///
/// 首次启动引导：官方 OnboardingWizardView 原本由 RootTabs 评估与呈现；根替换为本容器后，
/// 由本容器沿用官方同判定逻辑（RootTabsNavigation.startupPresentationRoute +
/// OnboardingStateStore.shouldPresentOnLaunch）负责首次引导，确保全新安装先进引导页。
struct HomeRootContainer: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(GatewayConnectionController.self) private var gatewayController

    @StateObject private var router = HomeRouterModel()

    @AppStorage("gateway.onboardingComplete") private var onboardingComplete: Bool = false
    @AppStorage("gateway.hasConnectedOnce") private var hasConnectedOnce: Bool = false
    @AppStorage("gateway.preferredStableID") private var preferredGatewayStableID: String = ""
    @AppStorage("gateway.manual.enabled") private var manualGatewayEnabled: Bool = false
    @AppStorage("gateway.manual.host") private var manualGatewayHost: String = ""
    @AppStorage("onboarding.requestID") private var onboardingRequestID: Int = 0

    @State private var showOnboarding: Bool = false
    @State private var onboardingAllowSkip: Bool = true
    @State private var didEvaluateOnboarding: Bool = false
    @State private var didRequestLocalNetworkAccessOnLaunch: Bool = false

    var body: some View {
        HomeTabView()
            .environmentObject(self.router)
            .task {
                self.router.startObservingGatewayStatus(appModel: self.appModel)
            }
            .onAppear {
                self.evaluateOnboardingPresentation(force: false)
            }
            .onChange(of: self.onboardingRequestID) { _, _ in
                self.evaluateOnboardingPresentation(force: true)
            }
            .fullScreenCover(isPresented: self.$showOnboarding) {
                OnboardingWizardView(
                    allowSkip: self.onboardingAllowSkip,
                    onRequestLocalNetworkAccess: { reason in
                        self.gatewayController.requestLocalNetworkAccess(reason: reason)
                    },
                    onClose: {
                        self.showOnboarding = false
                    },
                    onComplete: {
                        self.showOnboarding = false
                    })
                    .environment(self.appModel)
                    .environment(self.appModel.voiceWake)
                    .environment(self.gatewayController)
            }
            .fullScreenCover(isPresented: self.$router.isOpenClawPresented) {
                OpenClawFullScreenHost(router: self.router)
            }
    }

    // MARK: - 首次启动引导（与官方 RootTabs 同判定逻辑）

    private func evaluateOnboardingPresentation(force: Bool) {
        if force {
            self.onboardingAllowSkip = true
            self.showOnboarding = true
            return
        }
        guard !self.didEvaluateOnboarding else { return }
        self.didEvaluateOnboarding = true
        let route = RootTabsNavigation.startupPresentationRoute(
            gatewayConnected: self.appModel.gatewayServerName != nil,
            hasConnectedOnce: self.hasConnectedOnce,
            onboardingComplete: self.onboardingComplete,
            hasExistingGatewayConfig: self.hasExistingGatewayConfig(),
            shouldPresentOnLaunch: OnboardingStateStore.shouldPresentOnLaunch(appModel: self.appModel))
        switch route {
        case .none:
            self.maybeRequestLocalNetworkAccess()
        case .onboarding:
            self.onboardingAllowSkip = true
            self.showOnboarding = true
        case .settings:
            // 主页本身可直达设置；仅请求本地网络权限，不跳转。
            self.maybeRequestLocalNetworkAccess()
        }
    }

    private func hasExistingGatewayConfig() -> Bool {
        if self.appModel.activeGatewayConnectConfig != nil { return true }
        if GatewaySettingsStore.activeGatewayEntry() != nil { return true }
        let preferredStableID = self.preferredGatewayStableID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preferredStableID.isEmpty { return true }
        let manualHost = self.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
        return self.manualGatewayEnabled && !manualHost.isEmpty
    }

    private func maybeRequestLocalNetworkAccess() {
        guard !self.didRequestLocalNetworkAccessOnLaunch else { return }
        self.didRequestLocalNetworkAccessOnLaunch = true
        self.gatewayController.requestLocalNetworkAccess(reason: "home_root_appear")
    }
}

/// OpenClaw 全屏宿主：仅将 OpenClaw 现有 RootTabs() 包一层（不修改其内部逻辑/布局），
/// 顶部叠加「← 返回」悬浮按钮；按钮避开安全区、半透明背景，在任何 OpenClaw 页面上均可见。
private struct OpenClawFullScreenHost: View {
    private let router: HomeRouterModel

    init(router: HomeRouterModel) {
        self.router = router
    }

    var body: some View {
        GeometryReader { proxy in
            RootTabs()
                .overlay(alignment: .topLeading) {
                    self.backButton
                        .padding(.leading, 12)
                        .padding(.top, proxy.safeAreaInsets.top + 8)
                }
        }
    }

    private var backButton: some View {
        Button {
            self.router.closeOpenClaw()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text(String(localized: "Back"))
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.35), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Back"))
    }
}
