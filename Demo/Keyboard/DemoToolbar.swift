//
//  DemoToolbar.swift
//  KeyboardPro
//
//  Created by Daniel Saidi on 2023-11-27.
//  Copyright © 2023-2025 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import SwiftUI

/// This demo-specific toolbar is used as the `ToggleToolbar`
/// toggled view in ``DemoKeyboardView``.
///
/// This toolbar has a textfield to let you type and buttons
/// to toggle state, trigger actions, etc.
struct DemoToolbar<Toolbar: View>: View {

    var services: Keyboard.Services
    var toolbar: Toolbar

    @Binding var isTextInputActive: Bool
    @Binding var isToolbarToggled: Bool

    @EnvironmentObject var autocompleteContext: AutocompleteContext
    @EnvironmentObject var feedbackContext: FeedbackContext
    @EnvironmentObject var keyboardContext: KeyboardContext

    @FocusState var isTextFieldFocused

    @State var fullDocumentContext = ""
    @State var isThemePickerPresented = false
    @State var isFullDocumentContextActive = false
    @State var text = ""

    var body: some View {
        try? Keyboard.ToggleToolbar(
            isToggled: $isToolbarToggled,
            toolbar: autocompleteToolbar,                   // Suggestions + system keyboard switcher
            toggledToolbar: toggledToolbar
        )
        .tint(.primary)
        .font(.title3)
        .buttonStyle(.plainKeyboard)
        .padding(.trailing)
    }
}

private extension DemoToolbar {

    var autocompleteToolbar: some View {
        HStack {
            toolbar.frame(maxWidth: .infinity)
            systemKeyboardSwitcher
        }
    }

    var toggledToolbar: some View {
        HStack {
            Spacer()
            Button {
                keyboardContext.isKeyboardCollapsed.toggle()
            } label: {
                Image.keyboardDismiss
            }
        }
    }
}

private extension DemoToolbar {

    /// This button switches to the next iOS system keyboard.
    /// It's how users can type real Chinese with the built-in
    /// system IME, since KeyboardKit doesn't ship a Chinese
    /// layout in the 10.7.3 binary.
    var systemKeyboardSwitcher: some View {
        Keyboard.NextKeyboardButton {
            Image.keyboardGlobe
        }
        .background(Color.clearInteractable)
    }
}
