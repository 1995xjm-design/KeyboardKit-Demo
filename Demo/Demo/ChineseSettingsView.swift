//
//  ChineseSettingsView.swift
//  Demo
//
//  中文输入设置：通过 App Group 与键盘共享
//  修改后由键盘 KeyboardViewController.applySharedSettings 实时生效
//

import SwiftUI

/// 中文输入设置：控制 KK 键盘的输入与反馈选项
/// 设置保存在 App Group，App 与键盘实时同步
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
                Toggle("自动纠正", isOn: $isAutocorrectEnabled)
                Toggle("预测文本", isOn: $isPredictiveTextEnabled)
                Toggle("自动大写", isOn: $isAutocapitalizationEnabled)
            } header: {
                Text("输入")
            }

            Section {
                Toggle("句号快捷键", isOn: $isPeriodShortcutEnabled)
            } header: {
                Text("标点快捷键")
            } footer: {
                Text("双击句号键可快速输入句号。")
            }

            Section {
                Toggle("按键声", isOn: $isAudioFeedbackEnabled)
                Toggle("触感反馈", isOn: $isHapticFeedbackEnabled)
            } header: {
                Text("反馈")
            }

            Section {
                Picker("长按空格键", selection: $spacebarLongPressBehavior) {
                    Text("移动光标").tag("moveInputCursor")
                    Text("切换输入法").tag("openLocaleContextMenu")
                }
            } header: {
                Text("空格键")
            }

            Section {
                Text("这些设置保存在 App Group 中，App 与键盘实时共享，修改后立即生效。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("中文设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
