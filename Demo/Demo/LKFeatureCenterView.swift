//
//  LKFeatureCenterView.swift
//  Demo
//
//  LK ?????? LoveKeyboard ?????? KeyboardKit
//  ??????????? List/Section???? KK ?????
//

import SwiftUI
import UIKit

/// LK ???????????????????? API???????????
struct LKFeatureCenterView: View {

    var body: some View {
        List {
            aiSection
            keyboardToolsSection
            settingsSection
            guideSection
        }
        .navigationTitle("LK ??")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension LKFeatureCenterView {

    var aiSection: some View {
        Section {
            NavigationLink {
                InAppHelpReplyView()
            } label: {
                Label("???", systemImage: "bubble.left.and.bubble.right")
            }
            NavigationLink {
                InAppSuperTalkView()
            } label: {
                Label("???", systemImage: "wand.and.stars")
            }
        } header: {
            Text("AI ??")
        } footer: {
            Text("AI ????????? API????????????")
        }
    }

    var keyboardToolsSection: some View {
        Section {
            NavigationLink {
                InAppSymbolPadView()
            } label: {
                Label("????", systemImage: "number")
            }
        } header: {
            Text("????")
        } footer: {
            Text("????????????????????")
        }
    }

    var settingsSection: some View {
        Section {
            NavigationLink {
                APISettingsView()
            } label: {
                Label("?? API", systemImage: "key.horizontal")
            }
            NavigationLink {
                ChineseSettingsView()
            } label: {
                Label("????", systemImage: "gearshape")
            }
        } header: {
            Text("??")
        }
    }

    var guideSection: some View {
        Section {
            LabeledContent("? 1 ?", value: "??????")
            LabeledContent("? 2 ?", value: "?? > ?? > ??")
            LabeledContent("? 3 ?", value: "???????? KeyboardKit")
            LabeledContent("? 4 ?", value: "??????????")
        } header: {
            Text("????")
        } footer: {
            Text("????????????/EN????????????????????????????????")
        }
    }
}

/// App ?????????????????????
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
        .navigationTitle("???")
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

/// App ?????????????????????
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
        .navigationTitle("???")
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

/// App ??????????????????
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
        .navigationTitle("????")
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

/// ???????
private extension View {

    func copyToast(isShowing: Binding<Bool>) -> some View {
        overlay {
            if isShowing.wrappedValue {
                Text("???????")
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
