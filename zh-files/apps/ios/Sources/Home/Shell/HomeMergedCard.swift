import SwiftUI

/// 合并卡子功能条目（保留壳：跳转到现有功能页时使用）。
struct HomeSection: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let subtitle: String
    let destination: AnyView
}

/// 合并卡（主页网格卡片容器壳）：图标 + 标题 + 摘要 + 可选实时徽标。
/// 纯内容视图（导航由 HomeTabView 按编辑态包裹），尺寸区分小/中/大，OpenClaw 毛玻璃材质。
/// 已去掉 ClawTalk 的键盘面板（ClawTalkPanelHost / AutoInsightPanelHost / SmartFreqPanelHost /
/// HeartTargetPanelHost）——本工程卡片目标页统一走 HomeCardDestinationProviding，不在此处接面板。
struct HomeMergedCard: View {
    let kind: HomeCardKind
    var size: HomeCardSize = .medium
    /// 主页毛玻璃开关（来自 HomeTabView @AppStorage("home.glassEnabled")）。
    var glassEnabled: Bool = true
    /// 实时徽标（右上角；nil = 显示 chevron）。
    var badge: String?
    /// 卡面实时摘要（真实数据；nil = 回落静态简介）。
    var liveSummary: String?
    /// 红点角标数量（真实未处理计数；<= 0 不显示）。
    var redDotCount: Int?

    var body: some View {
        Group {
            switch size {
            case .small:
                smallLayout
            case .medium, .large:
                standardLayout
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(HomeWallpaper.glassCardBackground(enabled: glassEnabled))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    /// 小卡：图标 + 标题（对齐 iOS 小号小组件，信息密度低）。
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: kind.icon)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(kind.tint)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(alignment: .topTrailing) { redDotBadge }

            Spacer(minLength: 0)

            Text(kind.title)
                .font(OpenClawType.captionSemiBold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// 中/大卡：图标 + 徽标 + 标题 + 摘要。
    private var standardLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: kind.icon)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(kind.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topTrailing) { redDotBadge }

                Spacer(minLength: 0)

                if let badge {
                    Text(badge)
                        .font(OpenClawType.caption2SemiBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(kind.tint.opacity(0.9), in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(OpenClawType.headline)
                    .foregroundStyle(.primary)
                Text(liveSummary ?? kind.summary)
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    /// 红点角标：真实未处理计数（如 reminders 今日未完成提醒数）。
    @ViewBuilder
    private var redDotBadge: some View {
        if let redDotCount, redDotCount > 0 {
            Text(redDotCount > 99 ? "99+" : "\(redDotCount)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(OpenClawBrand.danger, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                .offset(x: 7, y: -7)
        }
    }

    private var minHeight: CGFloat {
        switch size {
        case .small: return 100
        case .medium: return 170 // 方块卡片：一行 2 个，高≈宽（明哥要求）
        case .large: return 150
        }
    }
}