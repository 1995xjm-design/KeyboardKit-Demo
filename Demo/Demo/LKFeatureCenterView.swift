//
//  LKFeatureCenterView.swift
//  Demo
//
//  LK 功能中心：把 LoveKeyboard 的 AI 功能整合进 KeyboardKit
//  沿用 KK 原生的 List/Section 风格，与 KK 界面保持一致
//

import SwiftUI
import UIKit

/// LK 功能中心：AI 帮你回、超会说、符号键盘、API 设置等
struct LKFeatureCenterView: View {

    var body: some View {
        List {
            aiSection
            keyboardToolsSection
            settingsSection
            guideSection
        }
        .navigationTitle("LK 功能")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension LKFeatureCenterView {

    var aiSection: some View {
        Section {
            NavigationLink {
                InAppHelpReplyView()
            } label: {
                Label("帮你回", systemImage: "bubble.left.and.bubble.right")
            }
            NavigationLink {
                InAppSuperTalkView()
            } label: {
                Label("超会说", systemImage: "wand.and.stars")
            }
        } header: {
            Text("AI 功能")
        } footer: {
            Text("AI 功能需要先配置 API 密钥，可在下方「API 设置」中填写。")
        }
    }

    var keyboardToolsSection: some View {
        Section {
            NavigationLink {
                InAppSymbolPadView()
            } label: {
                Label("符号键盘", systemImage: "number")
            }
        } header: {
            Text("键盘工具")
        } footer: {
            Text("快捷输入常用符号，点击即可复制到剪贴板。")
        }
    }

    var settingsSection: some View {
        Section {
            NavigationLink {
                APISettingsView()
            } label: {
                Label("API 设置", systemImage: "key.horizontal")
            }
            NavigationLink {
                ChineseSettingsView()
            } label: {
                Label("中文设置", systemImage: "gearshape")
            }
        } header: {
            Text("设置")
        }
    }

    var guideSection: some View {
        Section {
            LabeledContent("步骤 1", value: "打开「设置」")
            LabeledContent("步骤 2", value: "通用 > 键盘 > 键盘")
            LabeledContent("步骤 3", value: "添加新键盘，选择 KeyboardKit")
            LabeledContent("步骤 4", value: "打开「允许完全访问」")
        } header: {
            Text("使用引导")
        } footer: {
            Text("提示：键盘默认中文输入，点「中/EN」切换英文。")
        }
    }
}

/// App 内嵌的「帮你回」面板，点选结果后复制到剪贴板
struct InAppHelpReplyView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var copied = false

    var body: some View {
        HelpReplyPanelView(
            onClose: { dismiss() },
            onPaste: { UIPasteboard.general.string },
            onSelect: { text in
                UIPasteboard.general.string = text
                showCopied()
            }
        )
        .copyToast(isShowing: $copied)
        .navigationTitle("帮你回")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func showCopied() {
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation { copied = false }
        }
    }
}

/// App 内嵌的「超会说」面板，点选结果后复制到剪贴板
struct InAppSuperTalkView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var copied = false

    var body: some View {
        SuperTalkPanelView(
            onClose: { dismiss() },
            onSelectResult: { text in
                UIPasteboard.general.string = text
                showCopied()
            }
        )
        .copyToast(isShowing: $copied)
        .navigationTitle("超会说")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func showCopied() {
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation { copied = false }
        }
    }
}

/// App 内嵌的符号键盘，点选符号后复制到剪贴板
struct InAppSymbolPadView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var copied = false

    var body: some View {
        SymbolKeyboardView(
            isChineseMode: true,
            onSymbol: { symbol in
                UIPasteboard.general.string = symbol
                showCopied()
            },
            onABC: { dismiss() },
            onSpace: {},
            onDelete: {},
            onReturn: {}
        )
        .padding()
        .copyToast(isShowing: $copied)
        .navigationTitle("符号键盘")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func showCopied() {
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation { copied = false }
        }
    }
}

/// 复制成功的提示气泡
private extension View {

    func copyToast(isShowing: Binding<Bool>) -> some View {
        overlay {
            if isShowing.wrappedValue {
                Text("已复制到剪贴板")
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isShowing.wrappedValue)
    }
}
