import SwiftUI

/// 主页卡片管理（主页「常用卡片」标题行「管理」按钮弹出）：
/// 列出全部可配置卡，点按在主页显示 / 移除；支持一键恢复默认、清空。
/// 读写同一 UserDefaults key（HomeCardRegistry），主页 @AppStorage 自动同步，本页变更即时生效。
/// 参考 ClawTalk HomeCardManagerView.swift，视觉用 OpenClaw 主题。
struct HomeCardManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(HomeCardRegistry.storageKey) private var storage = HomeCardRegistry.defaultStorageValue

    /// 当前启用的卡片（顺序即主页排布顺序）。
    private var enabled: [HomeCardKind] {
        HomeCardRegistry.enabledKinds(from: storage)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(HomeCardKind.allCases) { kind in
                        Button {
                            toggle(kind)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: kind.icon)
                                    .font(OpenClawType.subheadSemiBold)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        kind.tint,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.title)
                                        .foregroundStyle(.primary)
                                    Text(kind.summary)
                                        .font(OpenClawType.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: enabled.contains(kind) ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.headline)
                                    .foregroundStyle(enabled.contains(kind) ? OpenClawBrand.ok : OpenClawBrand.warn)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(enabled.contains(kind) ? String(localized: "Shown") : String(localized: "Hidden"))
                    }
                } header: {
                    Text(String(localized: "Home Cards"))
                } footer: {
                    Text(String(localized: "Showing \(enabled.count) of \(HomeCardKind.allCases.count) cards. Toggle to show or hide; removing never deletes data."))
                }

                Section {
                    Button(String(localized: "Restore Default Cards")) {
                        storage = HomeCardRegistry.defaultStorageValue
                    }
                    Button(String(localized: "Clear Home Cards"), role: .destructive) {
                        storage = ""
                    }
                }
            }
            .navigationTitle(String(localized: "Manage Cards"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggle(_ kind: HomeCardKind) {
        var list = enabled
        if let index = list.firstIndex(of: kind) {
            list.remove(at: index)
        } else {
            list.append(kind)
        }
        storage = HomeCardRegistry.storageValue(for: list)
    }
}