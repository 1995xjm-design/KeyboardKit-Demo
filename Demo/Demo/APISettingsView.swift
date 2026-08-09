//
//  APISettingsView.swift
//  Demo
//
//  ?? API??? Base URL??????????? App ??????
//

import SwiftUI

/// ?? API ????????????APIKeyStore??
/// ?????????????????
struct APISettingsView: View {

    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""

    @State private var isSaving = false
    @State private var isTesting = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        Form {
            Section {
                TextField("????", text: $baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API ??", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("????", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("????")
            } footer: {
                Text("? App ?????????????????????? DeepSeek?https://api.deepseek.com / deepseek-chat")
            }

            Section {
                Button {
                    save()
                } label: {
                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("????")
                        }
                    } else {
                        Text("????")
                    }
                }
                .disabled(isSaving)

                Button {
                    Task { await testConnection() }
                } label: {
                    if isTesting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("????")
                        }
                    } else {
                        Text("????")
                    }
                }
                .disabled(isTesting || apiKey.isEmpty)
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(statusIsError ? Color.red : Color.green)
                }
            }
        }
        .navigationTitle("?? API")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func load() {
        let store = APIKeyStore.shared
        baseURL = store.baseURL
        apiKey = store.apiKey
        model = store.model
    }

    private func save() {
        isSaving = true
        APIKeyStore.shared.save(baseURL: baseURL, apiKey: apiKey, model: model)
        isSaving = false
        statusIsError = false
        statusMessage = "???????????????"
    }

    private func testConnection() async {
        isTesting = true
        statusMessage = nil
        defer { isTesting = false }
        do {
            let reply = try await APIService.shared.testConnection()
            statusIsError = false
            statusMessage = "?????" + reply
        } catch {
            statusIsError = true
            statusMessage = "?????" + error.localizedDescription
        }
    }
}
