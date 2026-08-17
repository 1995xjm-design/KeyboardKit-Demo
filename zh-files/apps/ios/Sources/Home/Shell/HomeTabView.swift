import Observation
import OpenClawKit
import OpenClawProtocol
import SwiftUI

/// 主页 Tab（首屏）：顶部语音助手大卡位（C-voice 实现，本文件只摆位置）+
/// 「今日概览」横向统计卡（OpenClaw 真实数据，接不到显示「--」，禁止造假）+
/// OPEN CLAW 固定卡（第一张，不参与 enabled 存储/排序/管理）+
/// 可配置卡片网格（12 卡，长按管理/排序/尺寸切换，动画与交互照 ClawTalk HomeTabView）。
struct HomeTabView: View {
    @Environment(NodeAppModel.self) private var appModel
    @EnvironmentObject private var router: HomeRouterModel

    @AppStorage(HomeCardRegistry.storageKey) private var enabledCardKindsStorage = HomeCardRegistry.defaultStorageValue
    @AppStorage(HomeCardRegistry.sizeStorageKey) private var cardSizesStorage = ""
    @AppStorage(HomeWallpaper.glassEnabledStorageKey) private var glassEnabled = true

    /// 卡片编辑态（长按卡片进入；点空白 / 「完成」退出）。
    @State private var isEditingCards = false
    /// 主页「常用卡片」标题行「管理」按钮弹出卡片管理页。
    @State private var isManagingCards = false
    /// 拖拽目标高亮卡片。
    @State private var targetedKind: HomeCardKind?
    /// 编辑态抖动驱动。
    @State private var wobbleTick = false
    /// 今日概览数据源（OpenClaw 真实服务）。
    @State private var overview = HomeOverviewModel()

    /// 2 列弹性网格（小卡 1 列 / 中卡 2 列 / 大卡 4 列，对齐 iOS 小组件比例；明哥要求一行 2 个）。
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    assistantSection
                    todayOverviewSection
                    cardsSection
                }
                .padding(.vertical, 16)
                .padding(.bottom, 240)
            }
            .scrollContentBackground(.hidden)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            // 壁纸垫在滚动内容后面（扩展到导航栏/标签栏区域），避免被容器背景盖住。
            .background { HomeWallpaper.background().ignoresSafeArea() }
            .onAppear {
                migrateCardStorageIfNeeded()
                overview.loadIfNeeded(appModel: appModel)
            }
            .onChange(of: isEditingCards) { _, editing in
                if editing {
                    withAnimation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true)) {
                        wobbleTick = true
                    }
                } else {
                    wobbleTick = false
                }
            }
        }
    }

    // MARK: - 顶部语音助手大卡

    /// 语音助手大卡：C-voice 实现完整可用视图，本文件只摆位置、不实现。
    private var assistantSection: some View {
        VoiceAssistantCardView(appModel: appModel)
            .padding(.horizontal, 16)
            .accessibilityLabel(String(localized: "Voice Assistant"))
    }

    // MARK: - 卡片区

    /// 「常用卡片」区：OPEN CLAW 固定卡 + 可配置卡片网格 + 编辑态头部（提示 / 完成按钮）。
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Favorite Cards"))
                        .font(OpenClawType.headline)
                        .foregroundStyle(.primary)
                    Text(isEditingCards
                         ? String(localized: "Drag to reorder · tap corner to resize · tap empty space to finish")
                         : String(localized: "Long-press a card for quick actions · tap the slider to edit"))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                NavigationLink {
                    SettingsProTab(ownsNavigationStack: false)
                } label: {
                    Image(systemName: "gearshape")
                        .font(OpenClawType.subheadSemiBold)
                        .foregroundStyle(OpenClawBrand.accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Settings"))
                if isEditingCards {
                    Button(String(localized: "Done")) {
                        withAnimation(.easeOut(duration: 0.2)) { isEditingCards = false }
                    }
                    .font(OpenClawType.subheadSemiBold)
                    .foregroundStyle(OpenClawBrand.accent)
                } else {
                    Button {
                        withAnimation(.easeIn(duration: 0.15)) { isEditingCards = true }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(OpenClawType.subheadSemiBold)
                            .foregroundStyle(OpenClawBrand.accent)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Edit cards"))

                    Button {
                        isManagingCards = true
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(OpenClawType.subheadSemiBold)
                            .foregroundStyle(OpenClawBrand.accent)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Manage cards"))
                }
            }

            openClawCard

            cardGrid
        }
        .sheet(isPresented: $isManagingCards) {
            HomeCardManagerView()
        }
        .padding(.horizontal, 16)
    }

    /// OPEN CLAW 固定卡：永远第一张，不参与 enabled 存储/排序/管理；
    /// 角标 = 网关状态（router.gatewayStateText，数据订阅 OpenClaw 网关状态服务），点击全屏推入。
    private var openClawCard: some View {
        Button {
            router.openOpenClaw()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "pawprint.fill")
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        OpenClawBrand.activationPrimaryGradient,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .shadow(color: OpenClawBrand.accent.opacity(0.35), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("OPEN CLAW")
                        .font(OpenClawType.headlineBold)
                        .foregroundStyle(.primary)
                    Text(String(localized: "Full OpenClaw experience"))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                gatewayStatusBadge

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(HomeWallpaper.glassCardBackground(enabled: glassEnabled))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(OpenClawBrand.accent.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "Opens the full OpenClaw interface"))
    }

    /// 网关状态角标：绿=已连接 / 橙=连接中 / 红=异常 / 灰=未连接。
    private var gatewayStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(gatewayStatusColor)
                .frame(width: 8, height: 8)
            Text(router.gatewayStateText)
                .font(OpenClawType.caption2SemiBold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.systemGray5), in: Capsule())
    }

    /// 网关状态色（与 router.gatewayStateText 同一数据源：OpenClaw 网关状态服务自查）。
    private var gatewayStatusColor: Color {
        switch GatewayStatusBuilder.build(appModel: appModel) {
        case .connected: return OpenClawBrand.statusSuccess
        case .connecting: return OpenClawBrand.statusWarning
        case .error: return OpenClawBrand.statusError
        case .disconnected: return Color.secondary
        }
    }

    /// 可配置卡片网格（编辑态拖动排序 + 尺寸调整；全部移除后一键恢复）。
    private var cardGrid: some View {
        let kinds = HomeCardRegistry.enabledKinds(from: enabledCardKindsStorage)
        return Group {
            if kinds.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "All home cards have been removed"))
                        .font(OpenClawType.subheadMedium)
                    Text(String(localized: "Long-press a card in edit mode to remove it; restore everything here."))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "Restore All Cards")) {
                        enabledCardKindsStorage = HomeCardRegistry.defaultStorageValue
                    }
                    .font(OpenClawType.subheadSemiBold)
                    .buttonStyle(.borderedProminent)
                    .tint(OpenClawBrand.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ZStack(alignment: .top) {
                    // 编辑态：点空白区域退出编辑（卡片在上层，不受影响）
                    if isEditingCards {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.2)) { isEditingCards = false }
                            }
                            .frame(minHeight: 320)
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(kinds) { kind in
                            cardCell(for: kind)
                        }
                    }
                }
            }
        }
    }

    /// 卡片跨列数：大卡占满整行（全部列），中卡小卡各占 1 列（一行 2 个）。
    private func gridSpan(for size: HomeCardSize) -> Int {
        size.gridColumns >= 4 ? columns.count : 1
    }

    /// 单个卡片单元：编辑态 = 可拖动 / 移除 × / 尺寸切换；普通态 = 导航链接。
    @ViewBuilder
    private func cardCell(for kind: HomeCardKind) -> some View {
        let size = HomeCardRegistry.size(for: kind, storage: cardSizesStorage)

        if isEditingCards {
            cardContent(for: kind, size: size)
                .overlay(alignment: .topLeading) {
                    removeOverlay(kind)
                }
                .overlay(alignment: .bottomTrailing) {
                    sizeOverlay(kind)
                }
                .overlay {
                    if targetedKind == kind {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(OpenClawBrand.accent, lineWidth: 2)
                    }
                }
                .rotationEffect(.degrees(wobbleTick ? 0.6 : -0.6))
                .scaleEffect(0.97)
                .animation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true), value: wobbleTick)
                .draggable(kind) {
                    dragPreview(for: kind, size: size)
                }
                .dropDestination(for: HomeCardKind.self) { items, _ in
                    guard let dragged = items.first, dragged != kind else { return false }
                    enabledCardKindsStorage = HomeCardRegistry.moving(dragged, before: kind, in: enabledCardKindsStorage)
                    return true
                } isTargeted: { targeted in
                    withAnimation(.easeOut(duration: 0.15)) {
                        targetedKind = targeted ? kind : nil
                    }
                }
                .gridCellColumns(gridSpan(for: size))
        } else {
            NavigationLink {
                destination(for: kind)
            } label: {
                cardContent(for: kind, size: size)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "Open \(kind.title)"))
            .contextMenu {
                ForEach(HomeDestinationProviderRegistry.quickActions(for: kind)) { action in
                    NavigationLink(destination: action.destination()) {
                        Label(action.title, systemImage: action.icon)
                    }
                }
            }
            .gridCellColumns(gridSpan(for: size))
        }
    }

    /// 卡片内容：统一 HomeMergedCard 视觉（OpenClaw 毛玻璃）。
    private func cardContent(for kind: HomeCardKind, size: HomeCardSize) -> some View {
        HomeMergedCard(
            kind: kind,
            size: size,
            glassEnabled: glassEnabled,
            // 编辑态 wobble 动画每帧重建卡片，跳过 badge/实时摘要/角标重算避免卡顿。
            badge: isEditingCards ? nil : badgeText(for: kind),
            liveSummary: isEditingCards ? nil : liveSummary(for: kind),
            redDotCount: isEditingCards ? 0 : redDotCount(for: kind)
        )
    }

    /// 卡片目标页：统一经 12 个 Provider 查表；nil 时显示「建设中」占位视图。
    @ViewBuilder
    private func destination(for kind: HomeCardKind) -> some View {
        if let destination = HomeDestinationProviderRegistry.destination(for: kind) {
            destination
        } else {
            HomeCardPlaceholderView(kind: kind)
        }
    }

    /// 编辑态：左上角移除按钮。
    private func removeOverlay(_ kind: HomeCardKind) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                enabledCardKindsStorage = HomeCardRegistry.removing(kind, from: enabledCardKindsStorage)
            }
        } label: {
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(OpenClawBrand.danger, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
        }
        .padding(8)
        .accessibilityLabel(String(localized: "Remove \(kind.title) card"))
    }

    /// 编辑态：右下角尺寸循环按钮（中 → 大 → 中）。
    private func sizeOverlay(_ kind: HomeCardKind) -> some View {
        Button {
            let current = HomeCardRegistry.size(for: kind, storage: cardSizesStorage)
            cardSizesStorage = HomeCardRegistry.settingSize(current.next, for: kind, in: cardSizesStorage)
        } label: {
            Text(HomeCardRegistry.size(for: kind, storage: cardSizesStorage).shortName)
                .font(OpenClawType.caption2SemiBold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.45), in: Capsule())
        }
        .padding(8)
        .accessibilityLabel(String(localized: "Adjust \(kind.title) card size"))
    }

    /// 拖拽预览（编辑态拖动时显示的浮层卡片）。
    private func dragPreview(for kind: HomeCardKind, size: HomeCardSize) -> some View {
        cardContent(for: kind, size: size)
            .frame(width: dragPreviewWidth(for: size))
    }

    private func dragPreviewWidth(for size: HomeCardSize) -> CGFloat {
        switch size {
        case .small: return 140
        case .medium: return 300
        case .large: return 600
        }
    }

    /// 老用户存储迁移（一次性）：记忆并入网格置首、分身插到记忆后、线 I 卡末尾追加。
    private func migrateCardStorageIfNeeded() {
        var stored = enabledCardKindsStorage
        HomeCardRegistry.runMigrations(&stored)
        if stored != enabledCardKindsStorage {
            enabledCardKindsStorage = stored
        }
    }

    // MARK: - 卡片实时数据（只接 OpenClaw 真实数据；无数据回落静态简介，不造假）

    /// 卡面实时徽标：automation = 网关 cron 任务数。
    private func badgeText(for kind: HomeCardKind) -> String? {
        switch kind {
        case .automation:
            return overview.cronJobCount.map { "\($0)" }
        default:
            return nil
        }
    }

    /// 卡面实时摘要：automation = 网关 cron 状态；其余卡回落 kind.summary。
    private func liveSummary(for kind: HomeCardKind) -> String? {
        switch kind {
        case .automation:
            guard let count = overview.cronJobCount else { return nil }
            return count > 0
                ? String(localized: "\(count) scheduled")
                : String(localized: "No scheduled tasks")
        default:
            return nil
        }
    }

    /// 红点角标：暂无（其他卡的真实计数由对应 Provider/子代理接入）。
    private func redDotCount(for kind: HomeCardKind) -> Int? {
        nil
    }

    // MARK: - 今日概览

    /// 「今日概览」区：语音助手下方、常用卡片上方，4 个横向小统计卡。
    private var todayOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Today at a Glance"))
                .font(OpenClawType.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                OverviewStatCard(
                    title: String(localized: "Gateway"),
                    value: overview.gatewayStateText,
                    icon: "network",
                    tint: overview.gatewayStateTint,
                    glassEnabled: glassEnabled
                )
                OverviewStatCard(
                    title: String(localized: "Sessions"),
                    value: overview.sessionCountText,
                    icon: "bubble.left.and.bubble.right.fill",
                    tint: OpenClawBrand.info,
                    glassEnabled: glassEnabled
                )
                OverviewStatCard(
                    title: String(localized: "Automations"),
                    value: overview.cronJobCountText,
                    icon: "clock.badge.checkmark",
                    tint: OpenClawBrand.warn,
                    glassEnabled: glassEnabled
                )
                OverviewStatCard(
                    title: String(localized: "Next Run"),
                    value: overview.cronNextRunText,
                    icon: "bolt.fill",
                    tint: OpenClawBrand.accent,
                    glassEnabled: glassEnabled
                )
            }
        }
        .padding(.horizontal, 16)
    }
}

/// 今日概览数据源（B-home）：全部来自 OpenClaw 真实服务——
/// 网关状态（GatewayStatusBuilder 自查）、会话数（NodeAppModel 缓存会话）、
/// 自动化 cron（网关 cron.status RPC）。接不到显示「--」，禁止造假。
@MainActor
@Observable
final class HomeOverviewModel {
    private(set) var gatewayState: GatewayDisplayState?
    private(set) var sessionCount: Int?
    private(set) var cronJobCount: Int?
    private(set) var cronNextRunAtMs: Int?

    private var loadTask: Task<Void, Never>?

    func loadIfNeeded(appModel: NodeAppModel) {
        guard loadTask == nil else { return }
        loadTask = Task { await self.refresh(appModel: appModel) }
    }

    func refresh(appModel: NodeAppModel) async {
        gatewayState = GatewayStatusBuilder.build(appModel: appModel)
        sessionCount = await appModel.loadCachedChatSessions().count
        let cron = await HomeAutomationCardProvider.fetchCronStatus(appModel: appModel)
        cronJobCount = cron?.jobs
        cronNextRunAtMs = cron?.nextwakeatms
    }

    var gatewayStateText: String {
        switch gatewayState {
        case .connected: return String(localized: "Connected")
        case .connecting: return String(localized: "Connecting")
        case .error: return String(localized: "Connection error")
        case .disconnected: return String(localized: "Disconnected")
        case nil: return "--"
        }
    }

    var gatewayStateTint: Color {
        switch gatewayState {
        case .connected: return OpenClawBrand.statusSuccess
        case .connecting: return OpenClawBrand.statusWarning
        case .error: return OpenClawBrand.statusError
        case .disconnected: return Color.secondary
        case nil: return Color.secondary
        }
    }

    var sessionCountText: String {
        sessionCount.map { "\($0)" } ?? "--"
    }

    var cronJobCountText: String {
        cronJobCount.map { "\($0)" } ?? "--"
    }

    /// 自动化下次执行：网关 cron 排程时间（HH:mm）；未接数据时诚实显示「--」。
    var cronNextRunText: String {
        guard let ms = cronNextRunAtMs else { return "--" }
        return Self.timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(ms) / 1000))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// 今日概览小统计卡：图标 + 数值 + 标签，横向四连排布（OpenClaw 毛玻璃材质）。
private struct OverviewStatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    let glassEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(OpenClawType.footnoteSemiBold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(value)
                .font(OpenClawType.subheadSemiBold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(OpenClawType.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HomeWallpaper.glassCardBackground(enabled: glassEnabled))
        )
    }
}