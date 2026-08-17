import SwiftUI

/// App 根容器视图（A-root）：
/// 首屏 = 「语音助手」主页（ClawTalk 卡片墙，由 B-home 的 HomeTabView 呈现），
/// OPEN CLAW 卡点击后全屏推入 OpenClaw 现有界面（RootTabs），顶部提供「← 返回」按钮。
///
/// 环境对象注入链说明：OpenClawApp 在 WindowGroup 中对本视图统一注入
/// appearanceModel / appModel / voiceWake / gatewayController（保持原有链不动），
/// 本视图再通过 environmentObject 注入 HomeRouterModel 给主页使用；
/// 全屏推入的 RootTabs() 从本视图继承同一环境，RootTabs 内部逻辑/布局零改动。
struct HomeRootContainer: View {
    @Environment(NodeAppModel.self) private var appModel

    @State private var router = HomeRouterModel()

    var body: some View {
        HomeTabView()
            .environmentObject(self.router)
            .task {
                self.router.startObservingGatewayStatus(appModel: self.appModel)
            }
            .fullScreenCover(isPresented: self.$router.isOpenClawPresented) {
                OpenClawFullScreenHost(router: self.router)
            }
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
