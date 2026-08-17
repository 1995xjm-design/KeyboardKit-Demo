import Foundation
import SwiftUI
import UIKit

/// 「报告」主页：
/// - 类型选择：日报 / 周报 / 自定义 prompt；
/// - 生成：走 OpenClaw Agent（HomeAgentPromptClient，见 Sources/Chat 传输接口），生成中显示进度态；
/// - 结果：Markdown 简化渲染 + 保存为文件 / 复制 / 分享；
/// - 历史：本机保存的已生成报告，可重看 / 删除。
@MainActor
struct HomeReportView: View {

    @Environment(NodeAppModel.self) private var appModel
    @State private var store = HomeReportStore.shared

    @State private var selectedKind: HomeReportKind
    @State private var customPrompt = ""
    @State private var isGenerating = false
    @State private var phaseText: String?
    @State private var currentResult: HomeReportEntry?
    @State private var errorMessage: String?
    @State private var noticeMessage: String?
    @State private var shareItem: ShareItem?

    private struct ShareItem: Identifiable {
        let id = UUID()
        let fileURL: URL
    }

    init(initialKind: HomeReportKind = .daily) {
        _selectedKind = State(initialValue: initialKind)
    }

    var body: some View {
        List {
            generationSection
            if let currentResult {
                resultSection(currentResult)
            }
            historySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Report"))
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
        .sheet(item: $shareItem) { item in
            ChatTranscriptShareSheet(fileURL: item.fileURL)
        }
    }

    // MARK: - 生成区

    @ViewBuilder
    private var generationSection: some View {
        Section {
            Picker(String(localized: "Report Type"), selection: $selectedKind) {
                ForEach(HomeReportKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isGenerating)

            if selectedKind == .custom {
                TextField(
                    String(localized: "Enter your prompt"),
                    text: $customPrompt,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .font(OpenClawType.body)
                .disabled(isGenerating)
            } else {
                Text(selectedKind.detail)
                    .font(OpenClawType.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(OpenClawType.footnote)
                    .foregroundStyle(OpenClawBrand.warn)
            }

            Button {
                Task { await generate() }
            } label: {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                    }
                    Text(
                        isGenerating
                            ? String(localized: "Generating…")
                            : String(localized: "Generate Report")
                    )
                    .font(OpenClawType.subheadMedium)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(OpenClawBrand.accent)
            .disabled(isGenerating || !canGenerate)

            if isGenerating, let phaseText {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(phaseText)
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "Generate Report"))
        }
    }

    private var canGenerate: Bool {
        switch selectedKind {
        case .custom:
            return !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .daily, .weekly:
            return true
        }
    }

    // MARK: - 结果区

    private func resultSection(_ entry: HomeReportEntry) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title)
                        .font(OpenClawType.headline)
                    Spacer()
                    Text(entry.subtitle)
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }

                HomeMarkdownText(markdown: entry.text)
                    .font(OpenClawType.body)

                HStack(spacing: 10) {
                    resultActionButton(
                        title: String(localized: "Save"),
                        icon: "square.and.arrow.down"
                    ) {
                        saveToFile(entry)
                    }
                    resultActionButton(
                        title: String(localized: "Copy"),
                        icon: "doc.on.doc"
                    ) {
                        copy(entry)
                    }
                    resultActionButton(
                        title: String(localized: "Share"),
                        icon: "square.and.arrow.up"
                    ) {
                        share(entry)
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
        } header: {
            Text(String(localized: "Result"))
        }
    }

    private func resultActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OpenClawType.subheadMedium)
        }
    }

    // MARK: - 历史区

    @ViewBuilder
    private var historySection: some View {
        Section {
            if store.reports.isEmpty {
                Text(String(localized: "No reports yet. Pick a type and generate one with the OpenClaw agent."))
                    .font(OpenClawType.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.reports) { entry in
                    Button {
                        currentResult = entry
                    } label: {
                        HStack {
                            Image(systemName: entry.kind.icon)
                                .foregroundStyle(OpenClawBrand.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(OpenClawType.subhead)
                                    .foregroundStyle(.primary)
                                Text(entry.subtitle)
                                    .font(OpenClawType.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(OpenClawType.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let entry = store.reports[index]
                        store.delete(id: entry.id)
                        if currentResult?.id == entry.id {
                            currentResult = nil
                        }
                    }
                }
            }
        } header: {
            Text(String(localized: "History"))
        }
    }

    // MARK: - 动作

    private func generate() async {
        let prompt = resolvedPrompt()
        guard !prompt.isEmpty else {
            noticeMessage = String(localized: "Please enter a prompt first.")
            return
        }
        isGenerating = true
        phaseText = String(localized: "Connecting to the gateway and waiting for the agent…")
        errorMessage = nil
        defer {
            isGenerating = false
            phaseText = nil
        }
        do {
            let text = try await HomeAgentPromptClient.prompt(
                appModel: appModel,
                prompt: prompt,
                sessionBaseKey: "report")
            let entry = HomeReportEntry(
                kind: selectedKind,
                customPrompt: customPrompt,
                text: text)
            store.add(entry)
            currentResult = entry
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolvedPrompt() -> String {
        switch selectedKind {
        case .daily:
            let dateText = Date.now.formatted(date: .long, time: .omitted)
            return """
            请生成今天的日报（\(dateText)）。用中文输出，Markdown 格式，包含以下小节（没有对应信息就写「暂无」）：
            # 今日概览
            # 主要进展
            # 待办与风险
            # 明日计划
            只输出报告正文，不要任何额外说明。
            """
        case .weekly:
            return """
            请生成本周周报（\(Self.thisWeekRangeText())）。用中文输出，Markdown 格式，包含以下小节（没有对应信息就写「暂无」）：
            # 本周概览
            # 主要进展
            # 问题与风险
            # 下周计划
            只输出报告正文，不要任何额外说明。
            """
        case .custom:
            return customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func thisWeekRangeText() -> String {
        let calendar = Calendar.current
        let today = Date.now
        guard let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let sunday = calendar.date(byAdding: .day, value: 6, to: monday)
        else {
            return today.formatted(date: .long, time: .omitted)
        }
        return "\(monday.formatted(date: .abbreviated, time: .omitted)) — \(sunday.formatted(date: .abbreviated, time: .omitted))"
    }

    private func saveToFile(_ entry: HomeReportEntry) {
        do {
            let url = try store.saveToFile(entry)
            noticeMessage = String.localizedStringWithFormat(
                String(localized: "Saved to %@"), url.lastPathComponent)
        } catch {
            noticeMessage = String(localized: "Failed to save the report.")
        }
    }

    private func copy(_ entry: HomeReportEntry) {
        UIPasteboard.general.string = entry.text
        noticeMessage = String(localized: "Copied to clipboard.")
    }

    private func share(_ entry: HomeReportEntry) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenClawHomeReports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent(
            "report-\(entry.kind.rawValue).md",
            isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try entry.text.write(to: url, atomically: true, encoding: .utf8)
            shareItem = ShareItem(fileURL: url)
        } catch {
            noticeMessage = String(localized: "Failed to share the report.")
        }
    }
}

