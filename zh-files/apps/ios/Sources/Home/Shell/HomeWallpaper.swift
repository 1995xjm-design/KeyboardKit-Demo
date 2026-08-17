import SwiftUI

/// 主页背景壁纸：OpenClaw 语义色渐变 + 品牌色柔光斑 + 毛玻璃材质。
/// 参考 ClawTalk HomeWallpaper.swift 的层级结构，色值全部换成 OpenClaw 语义色。
enum HomeWallpaper {
    /// 主页毛玻璃总开关存储 key（本模块自用，默认开）。
    static let glassEnabledStorageKey = "home.glassEnabled"

    /// 背景壁纸层：void/obsidian 自适应底色 + 品牌红/青柔光斑。
    /// 默认（未选壁纸）= 渐变底色，跟随系统深浅色；深浅切换只改蒙层与卡片。
    static func background() -> some View {
        LinearGradient(
            colors: [
                OpenClawBrand.void,
                OpenClawBrand.obsidian,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [OpenClawBrand.accent.opacity(0.14), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [OpenClawBrand.teal.opacity(0.10), Color.clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 460
            )
        }
    }

    /// 背景材质：开=ultraThinMaterial 磨砂；关=系统分组背景纯色。
    static func glassBackground(enabled: Bool) -> AnyShapeStyle {
        enabled
            ? AnyShapeStyle(.ultraThinMaterial)
            : AnyShapeStyle(Color(.systemGroupedBackground))
    }

    /// 卡片材质：开=ultraThinMaterial 磨砂；关=纯色卡片底。
    static func glassCardBackground(enabled: Bool) -> AnyShapeStyle {
        enabled
            ? AnyShapeStyle(.ultraThinMaterial)
            : AnyShapeStyle(Color(.secondarySystemBackground))
    }
}