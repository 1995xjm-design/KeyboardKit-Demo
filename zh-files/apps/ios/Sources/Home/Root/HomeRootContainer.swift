import OpenClawKit
import OpenClawProtocol
import SwiftUI

/// App 根容器视图（A-root）：
/// 首屏 = 「语音助手」主页（ClawTalk 卡片墙，由 B-home 的 HomeTabView 呈现），
/// OPEN CLAW is presented as a full-screen overlay (not a sheet): swipe right from
/// the home left edge to pull it in, swipe left from the OpenClaw root right edge to return.
///
/// 环境对象注入链说明：OpenClawApp 在 WindowGroup 中对本视图统一注入
/// appearanceModel / appModel / voiceWake / gatewayController（保持原有链不动），
/// 本视图再通过 environmentObject 注入 HomeRouterModel 给主页使用；
/// 推入的 RootTabs() 从本视图继承同一环境，RootTabs 内部逻辑/布局零改动。
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

    /// Live drag offset of the OpenClaw full-screen transition (clamped to [-width, 0]).
    @State private var openClawDragOffset: CGFloat = 0
    /// True while pulling OpenClaw in with the left-edge gesture (disables entry animation).
    @State private var isOpenClawDragActive = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
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
                                self.router.isOpenClawPresented = false
                            },
                            onComplete: {
                                self.showOnboarding = false
                                self.router.isOpenClawPresented = false
                            })
                            .environment(self.appModel)
                            .environment(self.appModel.voiceWake)
                            .environment(self.gatewayController)
                    }
                self.openClawEnterEdge(width: proxy.size.width)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .leading)
                    .ignoresSafeArea()
                    .zIndex(1)
                    .allowsHitTesting(!self.router.isOpenClawPresented)
                if self.router.isOpenClawPresented {
                    OpenClawFullScreenHost(
                        router: self.router,
                        dragOffset: self.$openClawDragOffset)
                        .transition(.move(edge: .leading))
                        .zIndex(2)
                }
            }
            .animation(
                self.isOpenClawDragActive ? nil : .easeOut(duration: 0.3),
                value: self.router.isOpenClawPresented)
            .onChange(of: self.router.isOpenClawPresented) { _, presented in
                if !presented {
                    self.openClawDragOffset = 0
                }
            }
        }
    }

    // MARK: - OpenClaw edge-swipe transitions

    /// Home left-edge 36pt strip: drag right to pull OpenClaw in from the left edge.
    private func openClawEnterEdge(width: CGFloat) -> some View {
        Color.clear
            .frame(width: 36)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(self.enterOpenClawGesture(width: width))
    }

    private func enterOpenClawGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      value.translation.width > 0
                else { return }
                self.isOpenClawDragActive = true
                if !self.router.isOpenClawPresented {
                    // 复位上次齿轮入口残留的目的地，保证拖动进入从官方默认（聊天）开始。
                    self.router.openOpenClaw()
                }
                let proposed = -width + value.translation.width
                self.openClawDragOffset = max(-width, min(0, proposed))
            }
            .onEnded { value in
                self.isOpenClawDragActive = false
                let shouldEnter = value.translation.width > 80
                    || value.predictedEndTranslation.width > 240
                if shouldEnter {
                    self.router.openOpenClaw()
                    withAnimation(.easeOut(duration: 0.28)) {
                        self.openClawDragOffset = 0
                    }
                } else if self.router.isOpenClawPresented {
                    withAnimation(.easeOut(duration: 0.28)) {
                        self.openClawDragOffset = -width
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        guard !self.isOpenClawDragActive else { return }
                        self.router.closeOpenClaw()
                    }
                } else {
                    self.openClawDragOffset = 0
                }
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
        let route = RootTabs.startupPresentationRoute(
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

/// OpenClaw full-screen host: wraps the existing RootTabs() unchanged.
/// Full-screen overlay with left/right edge-swipe transitions; a subtle shadow on
/// the right side of the OpenClaw content appears while dragging.
private struct OpenClawFullScreenHost: View {
    private let router: HomeRouterModel
    @Binding private var dragOffset: CGFloat
    /// True while on the OpenClaw root page (sidebar root visible, no subpage);
    /// the back-swipe gesture is only enabled there.
    @State private var isRootPageVisible = false
    /// True while the return-settle animation runs; a new drag cancels the pending close.
    @State private var isReturnDismissPending = false

    init(router: HomeRouterModel, dragOffset: Binding<CGFloat>) {
        self.router = router
        self._dragOffset = dragOffset
    }

    var body: some View {
        GeometryReader { proxy in
            RootTabs(
                initialSidebarDestination: self.router.initialDestination,
                initialSettingsRoute: self.router.initialSettingsRoute,
                hostedByHome: true,
                onRootVisibilityChange: { visible in
                    self.isRootPageVisible = visible
                })
                .overlay(alignment: .trailing) {
                    if self.isRootPageVisible {
                        self.returnGestureEdge(width: proxy.size.width)
                    }
                }
                .shadow(
                    color: .black.opacity(self.returnShadowOpacity(width: proxy.size.width)),
                    radius: 14,
                    x: 6)
        }
        .offset(x: self.dragOffset)
    }

    /// OpenClaw root-page right-edge 36pt strip: drag left to follow, release past the threshold to return home.
    private func returnGestureEdge(width: CGFloat) -> some View {
        Color.clear
            .frame(width: 36)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(self.returnDragGesture(width: width))
    }

    private func returnDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard self.isRootPageVisible,
                      abs(value.translation.width) > abs(value.translation.height),
                      value.translation.width < 0
                else { return }
                self.isReturnDismissPending = false
                self.dragOffset = max(-width, min(0, value.translation.width))
            }
            .onEnded { value in
                guard self.isRootPageVisible else { return }
                let shouldDismiss = value.translation.width < -80
                    || value.predictedEndTranslation.width < -240
                if shouldDismiss {
                    self.isReturnDismissPending = true
                    withAnimation(.easeOut(duration: 0.28)) {
                        self.dragOffset = -width
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        guard self.isReturnDismissPending else { return }
                        self.router.closeOpenClaw()
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        self.dragOffset = 0
                    }
                }
            }
    }

    /// Shadow opacity following the drag progress (0 = idle, 0.25 = fully revealed).
    private func returnShadowOpacity(width: CGFloat) -> Double {
        let progress = Double(-self.dragOffset / max(width, 1))
        return 0.25 * max(0, min(1, progress))
    }
}
