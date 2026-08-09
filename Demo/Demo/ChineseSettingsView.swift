//
//  ChineseSettingsView.swift
//  Demo
//
//  ?????????????? App Group ?????
//  ???????????? KeyboardViewController.setupDemoState??
//

import SwiftUI

/// ????????????? KK ??????????
/// ??????????????????????????
struct ChineseSettingsView: View {

    @AppStorage("kk.settings.isAutocorrectEnabled",
                store: UserDefaults(suiteName: AppConstants.appGroupId))
    private var isAutocorrectEnabled = true

    @AppStorage("kk.settings.isPredictiveTextEnabled",
                store: UserDefaults(suiteName: AppConstants.appGroupId))
    private var isPredictiveTextEnabled = true

    @AppStorage("kk.settings.isAutocapitalizationEnabled",
                store: UserDefaults(suiteName: AppConstants.appGroupId))
    private var isAutocapitalizationEnabled = true

    @AppStorage("kk.settings.isPeriodShortcutEnabled",
                store: UserDefaults(suiteName: AppConstants.appGroupId))
    private var isPeriodShortcutEnabled = true

    @AppStorage("kk.settings.isAudioFeedbackEnabled",
                store: UserDefaults(suiteName: AppConstants.appGroupId))
    private var isAudioFeedbackEnabled = false

    @AppStorage("kk.settings.isHapticFeedbackEnabled",
                store: UserDefaults(suiteName: AppConstants.appGroupId))
    private var isHapticFeedbackEnabled = true

    @AppStorage("kk.settings.spacebarLongPressBehavior",
                store: UserDefaults(suiteName: AppConstants.appGroupId))
    private var spacebarLongPressBehavior = "moveInputCursor"

    var body: some View {
        Form {
            Section {
                Toggle("????", isOn: $isAutocorrectEnabled)
                Toggle("????", isOn: $isPredictiveTextEnabled)
                Toggle("????", isOn: $isAutocapitalizationEnabled)
            } header: {
                Text("??")
            }

            Section {
                Toggle("?????", isOn: $isPeriodShortcutEnabled)
            } header: {
                Text("?????")
            } footer: {
                Text("??????????????????")
            }

            Section {
                Toggle("???", isOn: $isAudioFeedbackEnabled)
                Toggle("????", isOn: $isHapticFeedbackEnabled)
            } header: {
                Text("??")
            }

            Section {
                Picker("?????", selection: $spacebarLongPressBehavior) {
                    Text("????").tag("moveInputCursor")
                    Text("?????").tag("openLocaleContextMenu")
                }
            } header: {
                Text("???")
            }

            Section {
                Text("??????? App ????????????????????????")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("????")
        .navigationBarTitleDisplayMode(.inline)
    }
}
