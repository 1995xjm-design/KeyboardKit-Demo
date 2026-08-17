import OpenClawChatUI
import OpenClawKit
import OpenClawProtocol
import Foundation
import SwiftUI
import UIKit

/// 网关文件预览 + 基于文件内容向 Agent 提问。
/// 文件内容经 `agents.workspace.get` RPC 读取；二进制/图片如实提示不可预览，
/// 提问时不给二进制内容当上下文（避免垃圾输入）。
@MainActor
struct HomeKnowledgeFileView: View {
    let agentId: String
    let path: String
    let name: String

    @Environment(NodeAppModel.self) private var appModel

    @State private var file: AgentsWorkspaceFile?
    @State private var loading = false
    @State private var errorText: String?

    @State private var question = ""
    @State private var isAsking = false
    @State private var askError: String?
    @State private var answers: [HomeKnowledgeQA] = []
    @State private var noticeMessage: String?

    /// 预览展示上限（超出截断并标注，避免长文件拖垮列表）。
    private static let previewCharacterLimit = 120_000

    var body: some View {
        List {
            contentSection
            askSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            Text(String(localized: "Notice")),
            isPresented: Binding(
                get: { noticeMessage != nil },
                set: { if !$0 { noticeMessage = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) { noticeMessage = nil }
        } message: {
            Text(noticeMessage ?? "")
        }
        .task(id: "\(agentId)|\(path)") {
            await load()
        }
    }

    // MARK: - 内容区

    @ViewBuilder
    private var contentSection: some View {
        Section {
            if let file {
                if Self.isBinary(file) {
                    Text(String(localized: "This file cannot be previewed. It may be binary or too large."))
                        .font(OpenClawType.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    previewText(file.content)
                }
            } else if loading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "Loading…"))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let errorText {
                Text(errorText)
                    .font(OpenClawType.footnote)
                    .foregroundStyle(OpenClawBrand.warn)
            }
        } header: {
            Text(String(localized: "Content"))
        }
    }

    private func previewText(_ content: String) -> some View {
        let preview = String(content.prefix(Self.previewCharacterLimit))
        let truncated = content.count > Self.previewCharacterLimit
        return VStack(alignment: .leading, spacing: 8) {
            Text(preview)
                .font(OpenClawType.monoSmall)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if truncated {
                Text(String(localized: "File is long; only the first part is shown."))
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 提问区

    @ViewBuilder
    private var askSection: some View {
        Section {
            TextField(
                String(localized: "Ask about this file"),
                text: $question,
                axis: .vertical
            )
            .lineLimit(2...5)
            .font(OpenClawType.body)
            .disabled(isAsking)

            if let askError {
                Text(askError)
                    .font(OpenClawType.footnote)
                    .foregroundStyle(OpenClawBrand.warn)
            }

            Button {
                Task { await ask() }
            } label: {
                HStack(spacing: 8) {
                    if isAsking {
                        ProgressView()
                    }
                    Text(isAsking ? String(localized: "Asking…") : String(localized: "Ask"))
                        .font(OpenClawType.subheadMedium)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(OpenClawBrand.accent)
            .disabled(isAsking || !canAsk)

            ForEach(answers) { qa in
                qaRow(qa)
            }
        } header: {
            Text(String(localized: "Ask the Agent"))
        } footer: {
            Text(String(localized: "The agent answers based on this file's content."))
        }
    }

    private var canAsk: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func qaRow(_ qa: HomeKnowledgeQA) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(qa.question)
                    .font(OpenClawType.subheadMedium)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Button {
                    UIPasteboard.general.string = qa.answer
                    noticeMessage = String(localized: "Copied to clipboard.")
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Copy"))
            }
            HomeMarkdownText(markdown: qa.answer)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 数据

    @MainActor
    private func load() async {
        loading = true
        file = nil
        errorText = nil
        defer { loading = false }
        do {
            let params = AgentsWorkspaceGetParams(agentid: agentId, path: path)
            let paramsJSON = try HomeKnowledgeFileBrowserView.encodeParams(params)
            let data = try await appModel.operatorSession.request(
                method: "agents.workspace.get",
                paramsJSON: paramsJSON,
                timeoutSeconds: 20)
            file = try JSONDecoder().decode(AgentsWorkspaceGetResult.self, from: data).file
        } catch {
            errorText = String(localized: "Could not load this file.")
        }
    }

    private static func isBinary(_ file: AgentsWorkspaceFile) -> Bool {
        (file.encoding.value as? String) == "base64" && file.mimetype.hasPrefix("image/")
    }

    @MainActor
    private func ask() async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAsking = true
        askError = nil
        defer {
            isAsking = false
        }
        do {
            let answer: String
            if let file, !Self.isBinary(file) {
                answer = try await HomeKnowledgeAskSupport.ask(
                    appModel: appModel,
                    question: trimmed,
                    fileName: name,
                    fileContent: file.content)
            } else {
                // 二进制/图片：不把 base64 当上下文，退回通用提问。
                answer = try await HomeKnowledgeAskSupport.ask(
                    appModel: appModel,
                    question: trimmed)
            }
            answers.insert(
                HomeKnowledgeQA(question: trimmed, answer: answer, sourcePath: path),
                at: 0)
            question = ""
        } catch {
            askError = error.localizedDescription
        }
    }
}

