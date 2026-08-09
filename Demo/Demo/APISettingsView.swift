//
//  APISettingsView.swift
//  Demo
//
//  接入 API 设置：Base URL、密钥、模型，供 App 和键盘共用
//

import SwiftUI

/// 设置 App 与键盘共用的 AI 接口，保存到 APIKeyStore
/// 支持 DeepSeek 等 OpenAI 兼容接口
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
                TextField("接口地址", text: $baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API 密钥", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("模型名称", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("接口配置")
            } footer: {
                Text("App 与键盘共用一套接口，默认支持 DeepSeek：https://api.deepseek.com / deepseek-chat")
            }

            Section {
                Button {
                    save()
                } label: {
                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("保存中…")
                        }
                    } else {
                        Text("保存设置")
                    }
                }
                .disabled(isSaving)

                Button {
                    Task { await testConnection() }
                } label: {
                    if isTesting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("测试中…")
                        }
                    } else {
                        Text("测试连接")
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
        .navigationTitle("API 设置")
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
        statusMessage = "已保存，设置会同步到键盘"
    }

    private func testConnection() async {
        isTesting = true
        statusMessage = nil
        defer { isTesting = false }
        do {
            let reply = try await APIService.shared.testConnection()
            statusIsError = false
            statusMessage = "连接成功：" + reply
        } catch {
            statusIsError = true
            statusMessage = "连接失败：" + error.localizedDescription
        }
    }
}
