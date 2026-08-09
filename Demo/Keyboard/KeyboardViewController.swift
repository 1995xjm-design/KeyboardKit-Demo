//
//  KeyboardViewController.swift
//  KeyboardPro
//
//  Created by Daniel Saidi on 2023-02-13.
//  Copyright © 2023-2025 Daniel Saidi. All rights reserved.
//

import Foundation
import KeyboardKit
import SwiftUI

/// This keyboard shows how to set up `KeyboardKit Pro` with
/// a `KeyboardApp` and customize the keyboard.
///
/// This keyboard lets you test open-source and Pro features,
/// like fully localized keyboards, iPad Pro layouts, emojis,
/// autocomplete, themes, etc.
///
/// For app-specific features, check out the main app target.
class KeyboardViewController: KeyboardInputViewController {

    /// Chinese input state shared by the action handler and
    /// the keyboard view (candidate bar, symbol keyboard,
    /// help reply and super talk panels).
    lazy var chineseInput = ChineseInputController()

    /// ‼️ If this doesn't log when the debugger is attached,
    /// there is a memory leak.
    deinit {
        NSLog("__DEINIT__")
    }


    /// This function is called when the controller launches,
    /// and is where you can set up KeyboardKit for your app.
    override func viewWillSetupKeyboardKit() {

        /// 🧪 Enable experimental features
        Experiment.keyboardDictation.setIsEnabled(true)

        // Set up the keyboard with the demo-specific app.
        setupKeyboardKit(for: .keyboardKitDemo) { [weak self] result in

            /// 💡 If the setup worked, we can customize the
            /// keyboard. If not, we should handle the error.
            switch result {
            case .success:
                self?.setupDemoServices()
                self?.setupDemoState()
            case .failure(let error):
                print(error)
            }
        }
    }

    /// This function is called when the controller needs to
    /// redraw the keyboard view, and is where you can setup
    /// a custom view or customize the standard KeyboardView.
    override func viewWillSetupKeyboardView() {

        // ⚠️ Don't call `super.viewWillSetupKeyboardView()`.
        // super.viewWillSetupKeyboardView()

        // Set up a custom, demo-specific keyboard view.
        setupKeyboardView { [weak self] controller in

            // 💡 This demo keyboard view will apply various
            // view modifiers based on this controller state.
            DemoKeyboardView(
                services: controller.services,
                state: controller.state,
                controller: controller,
                chinese: self?.chineseInput ?? ChineseInputController()
            )
        }
    }
}

private extension KeyboardViewController {

    /// Make demo-specific changes to your keyboard services.
    func setupDemoServices() {

        // 💡 Set up am action handler for our rocket button.
        let handler = DemoActionHandler(controller: self)
        handler.chinese = chineseInput
        services.actionHandler = handler
    }

    /// Make demo-specific changes to your keyboard's state.
    ///
    /// Many configurations and settings can be made from
    /// the demo keyboard's custom toolbar.
    func setupDemoState() {

        /// 💡 Set up which locale to use to present locales.
        state.keyboardContext.localePresentationLocale = .current


        /// 💡 Configure the space key's behavior and action.
        state.keyboardContext.settings.spacebarLongPressBehavior = .moveInputCursor

        // Apply settings saved in the Chinese settings page.
        applySharedSettings()
        // state.keyboardContext.settings.spacebarContextMenuLeading = .locale

        /// 💡 Disable autocorrection.
        // state.autocompleteContext.isAutocorrectEnabled = false

        /// 💡 Setup demo-specific haptic & audio feedback.
        let feedback = state.feedbackContext
        feedback.registerCustomFeedback(.haptic(.selectionChanged, for: .repeat, on: .rocket))
        feedback.registerCustomFeedback(.audio(.rocketFuse, for: .press, on: .rocket))
        feedback.registerCustomFeedback(.audio(.rocketLaunch, for: .release, on: .rocket))
    }

    /// Applies keyboard behavior saved by the Chinese settings
    /// page. Values are stored in the App Group defaults so
    /// the main app and the keyboard share the same config.
    func applySharedSettings() {
        guard let defaults = UserDefaults(suiteName: AppConstants.appGroupId) else { return }

        if defaults.object(forKey: "kk.settings.isAutocorrectEnabled") != nil {
            state.autocompleteContext.isAutocorrectEnabled =
                defaults.bool(forKey: "kk.settings.isAutocorrectEnabled")
        }
        if defaults.object(forKey: "kk.settings.isPredictiveTextEnabled") != nil {
            state.keyboardContext.settings.isPredictiveTextEnabled =
                defaults.bool(forKey: "kk.settings.isPredictiveTextEnabled")
        }
        if defaults.object(forKey: "kk.settings.isAutocapitalizationEnabled") != nil {
            state.keyboardContext.settings.isAutocapitalizationEnabled =
                defaults.bool(forKey: "kk.settings.isAutocapitalizationEnabled")
        }
        if defaults.object(forKey: "kk.settings.isPeriodShortcutEnabled") != nil {
            state.keyboardContext.settings.isPeriodShortcutEnabled =
                defaults.bool(forKey: "kk.settings.isPeriodShortcutEnabled")
        }
        if defaults.object(forKey: "kk.settings.isAudioFeedbackEnabled") != nil {
            state.feedbackContext.isAudioFeedbackEnabled =
                defaults.bool(forKey: "kk.settings.isAudioFeedbackEnabled")
        }
        if defaults.object(forKey: "kk.settings.isHapticFeedbackEnabled") != nil {
            state.feedbackContext.isHapticFeedbackEnabled =
                defaults.bool(forKey: "kk.settings.isHapticFeedbackEnabled")
        }
        if let raw = defaults.string(forKey: "kk.settings.spacebarLongPressBehavior") {
            state.keyboardContext.settings.spacebarLongPressBehavior =
                raw == "openLocaleContextMenu" ? .openLocaleContextMenu : .moveInputCursor
        }
    }

}
