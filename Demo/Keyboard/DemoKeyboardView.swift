//
//  DemoKeyboardView.swift
//  KeyboardPro
//
//  Created by Daniel Saidi on 2022-02-04.
//  Copyright © 2022-2025 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import SwiftUI
import UIKit

/// This demo-specific keyboard view sets up a `KeyboardView`
/// and customizes it with Pro features.
///
/// This keyboard view replaces the default top toolbar with
/// a toggle toolbar that has an alternate menu.
struct DemoKeyboardView: View {

    var services: Keyboard.Services
    var state: Keyboard.State
    let controller: KeyboardInputViewController
    @ObservedObject var chinese: ChineseInputController

    @AppStorage("com.keyboardkit.demo.isToolbarToggled")
    var isToolbarToggled = false

    @EnvironmentObject var themeContext: KeyboardThemeContext

    @State var activeSheet: DemoSheet?
    @State var isTextInputActive = false
    @State var theme: KeyboardTheme?

    var keyboardContext: KeyboardContext { state.keyboardContext }

    var body: some View {
        VStack(spacing: 0) {

            // 💡 Pinyin candidate bar while composing Chinese.
            if chinese.hasActiveInput {
                CandidateBarView(
                    pinyin: chinese.pinyinBuffer,
                    candidates: chinese.candidates
                ) { candidate in
                    controller.textDocumentProxy.insertText(chinese.select(candidate))
                }
            }

            // 💡 Chinese feature bar: mode, symbols, AI panels.
            featureBar

            keyboardContent
        }
        .overlay(menuGrid)
        .animation(.bouncy, value: isToolbarToggled)

        // 💡 Customize callout actions in any way you want.
        .keyboardCalloutActions { params in                 // Apply custom actions to "K" key
            if case .character(let char) = params.action, char == "K" {
                let keyboardkit = String("keyboardkit".reversed())
                return .init(characters: keyboardkit)
            }
            return params.standardActions()
        }

        // 💡 Apply the currently selected theme, if any.
        .keyboardTheme(
            themeContext.currentTheme
        )

        // 💡 This sheet can be used to show the main menu.
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                sheetContent
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Button.Done") {
                                activeSheet = nil
                            }
                        }
                    }
            }
        }
    }
}

private extension DemoKeyboardView {

    // 💡 Chinese feature bar shown above the keyboard.
    var featureBar: some View {
        HStack(spacing: 18) {
            Button {
                toggleInputMode()
            } label: {
                Text(chinese.isChineseMode ? "中" : "EN")
                    .font(.subheadline.bold())
                    .frame(width: 34, height: 26)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }

            Button {
                chinese.toggleSymbolKeyboard()
            } label: {
                Text(LKString("符号", "Symbols"))
                    .font(.subheadline)
            }

            Button {
                chinese.showHelpReply()
            } label: {
                Text(LKString("帮你回", "Help Reply"))
                    .font(.subheadline)
            }

            Button {
                chinese.showSuperTalk()
            } label: {
                Text(LKString("超会说", "Super Talk"))
                    .font(.subheadline)
            }

            Spacer()
        }
        .buttonStyle(.plain)
        .padding(.leading, 10)
        .frame(height: 34)
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // 💡 Switches between symbol keyboard, feature panels and
    // the standard KeyboardKit keyboard.
    @ViewBuilder
    var keyboardContent: some View {
        if chinese.isSymbolKeyboard {
            SymbolKeyboardView(
                isChineseMode: chinese.isChineseMode,
                onSymbol: { insertText($0) },
                onABC: { chinese.toggleSymbolKeyboard() },
                onSpace: { insertText(" ") },
                onDelete: { deleteBackward() },
                onReturn: { insertText("\n") }
            )
        } else if let panel = chinese.activePanel {
            panelView(panel)
        } else {
            mainKeyboard
        }
    }

    // 💡 The standard KeyboardKit keyboard.
    var mainKeyboard: some View {
        KeyboardView(
            layout: demoLayout,
            services: services,
            buttonContent: { $0.view },                     // $0.view lets you use the default view
            buttonView: {
                $0.view.opacity(isToolbarToggled ? 0 : 1)   // Hide keys when the toolbar is toggled
            },
            collapsedView: { $0.view },
            emojiKeyboard: { $0.view },
            toolbar: { params in                            // All view builders have parameters
                if isTextInputActive {
                    DemoTextInputToolbar(
                        isTextInputActive: $isTextInputActive
                    )
                } else {
                    DemoToolbar(
                        services: services,
                        toolbar: params.view,               // Use the default toolbar as base view
                        isTextInputActive: $isTextInputActive,
                        isToolbarToggled: $isToolbarToggled
                    )
                }
            }
        )
    }

    // 💡 Feature panels: Help Reply and Super Talk.
    @ViewBuilder
    func panelView(_ panel: ChineseInputController.Panel) -> some View {
        switch panel {
        case .helpReply:
            HelpReplyPanelView(
                onClose: { chinese.closePanel() },
                onPaste: {
                    guard controller.hasFullAccess else { return nil }
                    return UIPasteboard.general.string
                },
                onSelect: { text in
                    insertText(text)
                    chinese.closePanel()
                }
            )
        case .superTalk:
            SuperTalkPanelView(
                onClose: { chinese.closePanel() },
                onSelectResult: { text in
                    insertText(text)
                    chinese.closePanel()
                }
            )
        }
    }

    // 💡 Toggles Chinese/English mode and syncs the keyboard locale.
    func toggleInputMode() {
        chinese.toggleMode()
        keyboardContext.locale = Locale(identifier: chinese.isChineseMode ? "zh-Hans" : "en")
    }

    // 💡 Text output helpers.
    func insertText(_ text: String) {
        controller.textDocumentProxy.insertText(text)
    }

    func deleteBackward() {
        controller.textDocumentProxy.deleteBackward()
    }

    // 💡 Setup a custom keyboard layout
    var demoLayout: KeyboardLayout {
        NSLog("Creating a custom layout")
        let context = state.keyboardContext
        var layout = KeyboardLayout.standard(for: context)
        guard context.keyboardType.isAlphabetic else { return layout }
        var item = layout.createIdealItem(for: .rocket)
        item.size.width = .input
        layout.itemRows.insert(item, after: .space)
        return layout
    }

    // 💡 This menu view is shown when the menu is activated.
    @ViewBuilder var menuGrid: some View {
        if isToolbarToggled {
            DemoKeyboardMenu(
                actionHandler: services.actionHandler,
                isTextInputActive: $isTextInputActive,
                isToolbarToggled: $isToolbarToggled,
                sheet: $activeSheet
            )
            .padding(.top, 55)  // Give room for the toolbar
            .padding(.horizontal, 10)
            .transition(.move(edge: .bottom))
        }
    }

    // 💡 This view builder creates misc sheet content views.
    @ViewBuilder var sheetContent: some View {
        switch activeSheet {
        case .autocompleteSettings: Autocomplete.SettingsScreen()
        case .clipboardSettings: Clipboard.SettingsScreen()
        case .experimentSettings: Experiments.SettingsScreen()
        case .feedbackSettings: Feedback.SettingsScreen()
        case .fontSettings: Fonts.SettingsScreen()
        case .fullDocumentReader: FullDocumentContextSheet()
        case .keyboardSettings: KeyboardSettingsScreen()
        case .localeSettings: KeyboardLocaleSettingsScreen()
        case .themeSettings: KeyboardThemeSettingsScreen()
        case .none: EmptyView()
        }
    }
}
