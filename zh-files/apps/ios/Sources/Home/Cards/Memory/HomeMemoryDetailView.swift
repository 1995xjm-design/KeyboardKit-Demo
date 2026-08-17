import SwiftUI

/// 记忆条目详情（G-memory）：路径 / 行号 / 摘要全文 / 召回统计。
/// 数据来自网关 `doctor.memory.status` 返回的条目，只读展示。
@MainActor
struct HomeMemoryEntryDetailView: View {
    let entry: DreamingEntryLite

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: entry.path)
                        .font(OpenClawType.captionSemiBold)
                        .foregroundStyle(OpenClawBrand.accent)
                        .textSelection(.enabled)
                    Text(String(format: String(localized: "Lines %lld–%lld"), entry.startLine, entry.endLine))
                        .font(OpenClawType.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            } header: {
                SectionHeader(String(localized: "Location"))
            }

            Section {
                Text(entry.snippet)
                    .font(OpenClawType.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } header: {
                SectionHeader(String(localized: "Snippet"))
            }

            Section {
                statRow(title: String(localized: "Recall count"), value: "\(entry.recallCount)")
                statRow(title: String(localized: "Daily count"), value: "\(entry.dailyCount)")
                statRow(title: String(localized: "Grounded count"), value: "\(entry.groundedCount)")
                statRow(title: String(localized: "Total signal count"), value: "\(entry.totalSignalCount)")
                statRow(title: String(localized: "Light hits"), value: "\(entry.lightHits)")
                statRow(title: String(localized: "REM hits"), value: "\(entry.remHits)")
                statRow(title: String(localized: "Phase hit count"), value: "\(entry.phaseHitCount)")
                if let promotedAt = entry.promotedAt {
                    statRow(title: String(localized: "Promoted at"), value: promotedAt)
                }
                if let lastRecalledAt = entry.lastRecalledAt {
                    statRow(title: String(localized: "Last recalled at"), value: lastRecalledAt)
                }
            } header: {
                SectionHeader(String(localized: "Statistics"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Memory Entry"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(OpenClawType.body)
            Spacer()
            Text(verbatim: value)
                .font(OpenClawType.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

/// 梦境日记「一天」详情（G-memory）：标题 + 正文，只读展示。
@MainActor
struct HomeMemoryDiaryDetailView: View {
    let day: HomeMemoryDiaryDay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(day.title)
                    .font(OpenClawType.title3SemiBold)
                Text(day.body)
                    .font(OpenClawType.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(OpenClawProMetric.pagePadding)
        }
        .navigationTitle(day.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
    }
}