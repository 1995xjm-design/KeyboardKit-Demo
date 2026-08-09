//
//  HomeScreen.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright ? 2021-2025 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import SwiftUI

/// The main demo app screen, restyled with the LoveKeyboard
/// Chinese look: an app header, a setup guide and text fields
/// that let you test the keyboard.
struct HomeScreen: View {

    let app = KeyboardApp.keyboardKitDemo

    @State var text = ""
    @State var textEmail = ""
    @State var textMultiline = ""
    @State var textNumberPad = ""
    @State var textURL = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    setupGuideSection
                    textFieldSection
                }
                .padding()
            }
            .navigationTitle("中文键盘")
        }
        .navigationViewStyle(.stack)
    }
}

private extension HomeScreen {

    /// App header in LoveKeyboard style.
    var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 60))
                .foregroundColor(.pink)
            Text("中文键盘")
                .font(.title)
                .fontWeight(.bold)
            Text("中英输入 · AI 帮你回 · 超会说")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 30)
    }

    /// Step-by-step setup guide.
    var setupGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置指南")
                .font(.headline)

            SetupStepView(step: "1", title: "打开「设置」")
            SetupStepView(step: "2", title: "通用 > 键盘 > 键盘")
            SetupStepView(step: "3", title: "添加新键盘，选择 KeyboardKit")
            SetupStepView(step: "4", title: "打开「允许完全访问」")

            Text("提示：键盘默认中文输入，点「中/EN」切换英文。")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    /// Text fields to test the keyboard.
    var textFieldSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("输入测试")
                .font(.headline)

            TextField("普通输入", text: $text)
                .keyboardType(.default)
            TextField("邮箱", text: $textEmail)
                .keyboardType(.emailAddress)
            TextField("数字键盘", text: $textNumberPad)
                .keyboardType(.numberPad)
            TextField("网址", text: $textURL)
                .keyboardType(.URL)
            TextField("多行输入", text: $textMultiline, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .keyboardType(.default)
        }
        .textFieldStyle(.roundedBorder)
    }
}

/// A single setup-guide step row.
struct SetupStepView: View {

    let step: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(step)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.pink)
                .clipShape(Circle())
            Text(title)
                .font(.subheadline)
        }
    }
}

#Preview {

    HomeScreen()
}
