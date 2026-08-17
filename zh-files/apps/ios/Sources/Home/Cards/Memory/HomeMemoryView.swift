import SwiftUI

/// 「记忆」主页（G-memory）：
/// 数据接 OpenClaw 网关 `doctor.memory.*` RPC，浏览 / 搜索 / 详情。
/// - 「梦境日记」：按天分块的日记正文；
/// - 「记忆库」：dreaming 提升出的长期记忆条目（promotedEntries）；
/// - 「信号条目 / 短期召回」：dreaming 信号与近期召回。
/// 网关未连接或 RPC 不可用 → 中文空态；不造假数据。
@MainActor
struct HomeMemoryView: View {
    enum MemorySection: String, CaseIterable, Identifiable {
        case all
        case dreamDiary
        case memoryBank

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: String(localized: "All")
            case .dreamDiary: String(localized: "Dream Diary")
            case .memoryBank: String(localized: "Memory Bank")
            }
        }
    }

    @Environment(NodeAppModel.self) private var appModel
    @State private var store = HomeMemoryStore()
    @State private var section: MemorySection
    @State private var isSearchPresented: Bool

    init(initialSection: MemorySection = .all, initialSearchFocused: Bool = false) {
        _section = State(initialValue: initialSection)
        _isSearchPresented = State(initialValue: initialSearchFocused)
    }

    var body: some View {
        List {
            Section {
                Picker(String(localized: "Memory"), selection: $section) {
                    ForEach(MemorySection.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)

            if store.errorMessage != nil && !store.hasAnyData {
                unavailableSection
            } else {
                switch section {
                case .all:
                    memoryBankSection
                    dreamDiarySection
                    signalSection
                    shortTermSection
                case .dreamDiary:
                    dreamDiarySection
                case .memoryBank:
                    memoryBankSection
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Memory"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $store.searchText,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: String(localized: "Search memories and dream diary")
        )
        .task {
            await store.loadIfNeeded(appModel: appModel)
        }
        .refreshable {
            await store.reload(appModel: appModel)
        }
        .overlay {
            if store.isLoading && !store.hasAnyData {
                ProgressView()
            }
        }
    }

    // MARK: - 网关不可用

    private var unavailableSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text(String(localized: "Memory Unavailable"))
                    .font(OpenClawType.headline)
                Text(store.errorMessage ?? "")
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await store.reload(appModel: appModel) }
                } label: {
                    Text(String(localized: "Retry"))
                        .font(OpenClawType.subheadSemiBold)
                }
                .buttonStyle(.borderedProminent)
                .tint(OpenClawBrand.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - 记忆库（长期记忆条目）

    @ViewBuilder
    private var memoryBankSection: some View {
        Section {
            if store.isLoading && store.promotedEntries.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "Loading memory…"))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } else if store.filteredPromotedEntries.isEmpty {
                emptyRow(
                    icon: "tray",
                    title: String(localized: "No Memory Entries"),
                    detail: store.trimmedSearch.isEmpty
                        ? String(localized: "Dreaming has not promoted any durable memory entries yet.")
                        : String(localized: "No memory entries match your search."))
            } else {
                ForEach(store.filteredPromotedEntries) { entry in
                    NavigationLink {
                        HomeMemoryEntryDetailView(entry: entry)
                    } label: {
                        memoryEntryRow(entry)
                    }
                }
            }
        } header: {
            SectionHeaderWithCount(
                title: String(localized: "Memory Bank"),
                count: store.promotedEntries.count,
                searchActive: !store.trimmedSearch.isEmpty)
        }
    }

    // MARK: - 梦境日记

    @ViewBuilder
    private var dreamDiarySection: some View {
        Section {
            if store.isLoading && store.diary == nil {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "Loading dream diary…"))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } else if store.diary == nil || !store.hasDiary {
                emptyRow(
                    icon: "moon.stars",
                    title: String(localized: "No Dream Diary"),
                    detail: store.diary == nil
                        ? String(localized: "The gateway did not return a dream diary.")
                        : String(localized: "The dream diary is empty so far."))
            } else if store.filteredDiaryDays.isEmpty {
                emptyRow(
                    icon: "magnifyingglass",
                    title: String(localized: "No Matching Days"),
                    detail: String(localized: "No diary days match your search."))
            } else {
                ForEach(store.filteredDiaryDays) { day in
                    NavigationLink {
                        HomeMemoryDiaryDetailView(day: day)
                    } label: {
                        diaryDayRow(day)
                    }
                }
            }
        } header: {
            if let diary {
                SectionHeaderWithCount(
                    title: String(localized: "Dream Diary"),
                    count: store.diaryDays.count,
                    searchActive: !store.trimmedSearch.isEmpty,
                    detail: diary.updatedAtMs.map { HomeMemoryRelativeTime.string(fromMilliseconds: $0) })
            } else {
                SectionHeaderWithCount(
                    title: String(localized: "Dream Diary"),
                    count: 0,
                    searchActive: !store.trimmedSearch.isEmpty)
            }
        }
    }

    // MARK: - 信号条目 / 短期召回

    @ViewBuilder
    private var signalSection: some View {
        Section {
            if store.filteredSignalEntries.isEmpty {
                emptyRow(
                    icon: "waveform.path.ecg",
                    title: String(localized: "No Signal Entries"),
                    detail: store.trimmedSearch.isEmpty
                        ? String(localized: "No recent recall, daily, grounded, or phase signals were reported.")
                        : String(localized: "No signal entries match your search."))
            } else {
                ForEach(store.filteredSignalEntries) { entry in
                    NavigationLink {
                        HomeMemoryEntryDetailView(entry: entry)
                    } label: {
                        memoryEntryRow(entry)
                    }
                }
            }
        } header: {
            SectionHeaderWithCount(
                title: String(localized: "Signal Entries"),
                count: store.signalEntries.count,
                searchActive: !store.trimmedSearch.isEmpty)
        }
    }

    @ViewBuilder
    private var shortTermSection: some View {
        Section {
            if store.filteredShortTermEntries.isEmpty {
                emptyRow(
                    icon: "clock.arrow.circlepath",
                    title: String(localized: "No Short-Term Entries"),
                    detail: store.trimmedSearch.isEmpty
                        ? String(localized: "The short-term dreaming store is empty.")
                        : String(localized: "No short-term entries match your search."))
            } else {
                ForEach(store.filteredShortTermEntries) { entry in
                    NavigationLink {
                        HomeMemoryEntryDetailView(entry: entry)
                    } label: {
                        memoryEntryRow(entry)
                    }
                }
            }
        } header: {
            SectionHeaderWithCount(
                title: String(localized: "Short-Term Recall"),
                count: store.shortTermEntries.count,
                searchActive: !store.trimmedSearch.isEmpty)
        }
    }

    // MARK: - 行视图

    private func memoryEntryRow(_ entry: DreamingEntryLite) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.page")
                .font(.system(size: 15))
                .foregroundStyle(OpenClawBrand.accent)
                .frame(width: 28, height: 28)
                .background(OpenClawBrand.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.entryTitle(entry))
                    .font(OpenClawType.subheadSemiBold)
                    .lineLimit(1)
                Text(entry.snippet)
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(Self.entryDetail(entry))
                    .font(OpenClawType.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(verbatim: entry.totalSignalCount.formatted())
                .font(OpenClawType.caption2SemiBold)
                .foregroundStyle(OpenClawBrand.accent)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func diaryDayRow(_ day: HomeMemoryDiaryDay) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(day.title)
                .font(OpenClawType.subheadSemiBold)
                .lineLimit(1)
            Text(day.body)
                .font(OpenClawType.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }

    private func emptyRow(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(OpenClawType.subheadSemiBold)
            Text(detail)
                .font(OpenClawType.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - 文案

    static func entryTitle(_ entry: DreamingEntryLite) -> String {
        let name = entry.path.split(separator: "/").last.map(String.init) ?? entry.path
        return "\(name):\(entry.startLine)"
    }

    static func entryDetail(_ entry: DreamingEntryLite) -> String {
        var parts: [String] = []
        if let promotedAt = entry.promotedAt {
            parts.append(String(format: String(localized: "Promoted %@"), promotedAt))
        }
        if let lastRecalledAt = entry.lastRecalledAt {
            parts.append(String(format: String(localized: "Recalled %@"), lastRecalledAt))
        }
        parts.append(String(localized: "\(entry.recallCount) recalls"))
        if entry.groundedCount > 0 {
            parts.append(String(localized: "\(entry.groundedCount) grounded"))
        }
        return parts.joined(separator: " • ")
    }
}

/// Section 头部：标题 + 总数（搜索态显示命中数）+ 可选更新时间。
private struct SectionHeaderWithCount: View {
    let title: String
    let count: Int
    let searchActive: Bool
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            if let detail {
                Text(detail)
                    .font(OpenClawType.caption2)
                    .foregroundStyle(.tertiary)
            }
            if searchActive {
                Image(systemName: "magnifyingglass")
                    .font(OpenClawType.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(verbatim: "\(count)")
                .font(OpenClawType.caption2SemiBold)
                .foregroundStyle(.secondary)
        }
    }
}