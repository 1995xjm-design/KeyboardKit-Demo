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
///
/// All user-visible texts use catalog keys (see
/// `Localizable.xcstrings`) so the string-catalog build step
/// can resolve them at runtime.
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
            .navigationTitle("Home.AppName")
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
            Text("Home.AppName")
                .font(.title)
                .fontWeight(.bold)
            Text("Home.Slogan")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 30)
    }

    /// Step-by-step setup guide.
    var setupGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Home.SetupGuideTitle")
                .font(.headline)

            SetupStepView(step: "1", title: "Home.Step1")
            SetupStepView(step: "2", title: "Home.Step2")
            SetupStepView(step: "3", title: "Home.Step3")
            SetupStepView(step: "4", title: "Home.Step4")

            Text("Home.Tip")
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
            Text("Home.TestFieldsTitle")
                .font(.headline)

            TextField("Home.FieldPlain", text: $text)
                .keyboardType(.default)
            TextField("Home.FieldEmail", text: $textEmail)
                .keyboardType(.emailAddress)
            TextField("Home.FieldNumber", text: $textNumberPad)
                .keyboardType(.numberPad)
            TextField("Home.FieldURL", text: $textURL)
                .keyboardType(.URL)
            TextField("Home.FieldMultiline", text: $textMultiline, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .keyboardType(.default)
        }
        .textFieldStyle(.roundedBorder)
    }
}

/// A single setup-guide step row.
struct SetupStepView: View {

    let step: String
    let title: LocalizedStringKey

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
