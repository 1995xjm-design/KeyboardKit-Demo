import OpenClawChatUI
import OpenClawKit
import OpenClawProtocol
import Foundation
import SwiftUI

/// 网关工作区文件浏览器：`agents.workspace.list` RPC（接 OpenClaw 文件能力），
/// 目录可下钻，文件进入「预览 + 基于内容提问」页。
@MainActor
struct HomeKnowledgeFileBrowserView: View {
    let agentId: String
    let path: String

    @Environment(NodeAppModel.self) private var appModel
    @State private var entries: [AgentsWorkspaceEntry] = []
    @State private var loading = false
    @State private var errorText: String?

    init(agentId: String, path: String = "") {
        self.agentId = agentId
        self.path = path
    }

    var body: some View {
        List {
            if let errorText {
                Section {
                    Text(errorText)
                        .font(OpenClawType.footnote)
                        .foregroundStyle(OpenClawBrand.warn)
                }
            } else if entries.isEmpty, !loading {
                Section {
                    Text(String(localized: "This folder is empty."))
                        .font(OpenClawType.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(entries, id: \.path) { entry in
                    entryRow(entry)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .font(OpenClawType.body)
        .overlay {
            if loading, entries.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await reload()
        }
        .task(id: "\(agentId)|\(path)") {
            await reload()
        }
        .navigationTitle(
            path.isEmpty
                ? String(localized: "Workspace Files")
                : Self.displayName(forPath: path)
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entryRow(_ entry: AgentsWorkspaceEntry) -> some View {
        let isDirectory = Self.isDirectory(entry)
        return NavigationLink {
            if isDirectory {
                HomeKnowledgeFileBrowserView(agentId: agentId, path: entry.path)
            } else {
                HomeKnowledgeFileView(agentId: agentId, path: entry.path, name: entry.name)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isDirectory ? "folder" : "doc.text")
                    .font(OpenClawType.subhead)
                    .foregroundStyle(isDirectory ? OpenClawBrand.accent : Color.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(OpenClawType.subhead)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let detail = Self.entryDetail(entry) {
                        Text(detail)
                            .font(OpenClawType.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - 数据

    @MainActor
    private func reload() async {
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let params = AgentsWorkspaceListParams(
                agentid: agentId,
                path: path.isEmpty ? nil : path,
                offset: nil,
                limit: nil)
            let paramsJSON = try Self.encodeParams(params)
            let data = try await appModel.operatorSession.request(
                method: "agents.workspace.list",
                paramsJSON: paramsJSON,
                timeoutSeconds: 12)
            let result = try JSONDecoder().decode(AgentsWorkspaceListResult.self, from: data)
            entries = result.entries
        } catch {
            entries = []
            errorText = String(localized: "Could not load this folder.")
        }
    }

    static func encodeParams(_ params: some Encodable) throws -> String {
        let data = try JSONEncoder().encode(params)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func isDirectory(_ entry: AgentsWorkspaceEntry) -> Bool {
        (entry.kind.value as? String) == "directory"
    }

    static func displayName(forPath path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    private static func entryDetail(_ entry: AgentsWorkspaceEntry) -> String? {
        var parts: [String] = []
        if let size = entry.size {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        if let updatedAtMs = entry.updatedatms {
            let date = Date(timeIntervalSince1970: Double(updatedAtMs) / 1000)
            parts.append(date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

