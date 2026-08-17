import Foundation

/// 梦境日记「一天」的轻量模型（由 DreamDiaryLite.content 解析而来）。
/// 解析规则对齐 OpenClaw AgentProDreamingDestination：
/// - 优先按 `<!-- openclaw:dreaming:diary:day=YYYY-MM-DD -->` 分块（每块一天）；
/// - 无标记时按 `* January 1, 2026 …` / `* 2026-01-01 …` 日期行分块；
/// - 都没有时整段作为一条。
struct HomeMemoryDiaryDay: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let entryCount: Int
}

enum HomeMemoryDiaryParser {
    /// 解析梦境日记内容；空内容返回空数组（视图显示诚实空态）。
    static func parse(_ content: String?) -> [HomeMemoryDiaryDay] {
        guard let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let markerBlocks = Self.splitByMarker(content)
        if !markerBlocks.isEmpty {
            return markerBlocks.compactMap { block in
                guard let day = Self.dayFromMarker(block.marker) else { return nil }
                return Self.makeDay(
                    id: day,
                    title: Self.dayTitle(day),
                    body: Self.cleanBody(block.body))
            }
        }

        let dateBlocks = Self.splitByDateLine(content)
        if dateBlocks.count > 1 {
            return dateBlocks.enumerated().compactMap { index, block in
                let rawTitle = block.dateLine.flatMap(Self.unwrappedEmphasis)
                    ?? Self.isoDateIn(block.dateLine ?? "")
                let title = rawTitle.map(Self.dayTitle) ?? String(localized: "Dream Diary")
                let id = rawTitle.map(Self.dayID) ?? "day-\(index)"
                return Self.makeDay(id: id, title: title, body: Self.cleanBody(block.body))
            }
        }

        return [
            Self.makeDay(
                id: "diary",
                title: String(localized: "Dream Diary"),
                body: Self.cleanBody(content))
        ]
    }

    // MARK: - 按 marker 分块

    private static let markerPattern =
        #"<!--\s*openclaw:dreaming:diary:day=(\d{4}-\d{2}-\d{2})\s*-->"#

    private struct MarkerBlock {
        let marker: String
        let body: String
    }

    private static func splitByMarker(_ content: String) -> [MarkerBlock] {
        var blocks: [MarkerBlock] = []
        var currentMarker: String?
        var currentLines: [String] = []

        func flush() {
            guard let marker = currentMarker else { return }
            let body = currentLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                blocks.append(MarkerBlock(marker: marker, body: body))
            }
            currentMarker = nil
            currentLines = []
        }

        for line in content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if let range = line.range(
                of: Self.markerPattern,
                options: .regularExpression)
            {
                flush()
                let match = String(line[range])
                if let dayRange = match.range(
                    of: #"\d{4}-\d{2}-\d{2}"#,
                    options: .regularExpression)
                {
                    currentMarker = String(match[dayRange])
                }
                continue
            }
            currentLines.append(line)
        }
        flush()
        return blocks
    }

    private static func dayFromMarker(_ marker: String) -> String? {
        guard marker.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil else {
            return nil
        }
        return marker
    }

    // MARK: - 按日期行分块

    private struct DateBlock {
        let dateLine: String?
        let body: String
    }

    private static func splitByDateLine(_ content: String) -> [DateBlock] {
        var blocks: [DateBlock] = []
        var currentDateLine: String?
        var currentLines: [String] = []

        func flush() {
            let body = currentLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                blocks.append(DateBlock(dateLine: currentDateLine, body: body))
            }
            currentDateLine = nil
            currentLines = []
        }

        for line in content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if Self.isDiaryDateLine(line), !currentLines.isEmpty {
                flush()
                currentDateLine = line
                continue
            }
            if Self.isDiaryDateLine(line), currentDateLine == nil {
                currentDateLine = line
                continue
            }
            currentLines.append(line)
        }
        flush()
        return blocks
    }

    private static func isDiaryDateLine(_ line: String) -> Bool {
        guard let value = unwrappedEmphasis(line) else { return false }
        let monthNames = "January|February|March|April|May|June|July|August|September|October|November|December"
        let monthDatePattern = #"\b("# + monthNames + #")\s+\d{1,2},\s+\d{4}\b"#
        let isoDatePattern = #"\b\d{4}-\d{2}-\d{2}\b"#
        return value.range(
            of: "\(monthDatePattern)|\(isoDatePattern)",
            options: .regularExpression) != nil
    }

    // MARK: - 行处理

    private static func unwrappedEmphasis(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("*"), trimmed.hasSuffix("*"), trimmed.count > 2 else { return nil }
        return String(trimmed.dropFirst().dropLast())
    }

    private static func isoDateIn(_ line: String) -> String? {
        guard let range = line.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) else {
            return nil
        }
        return String(line[range])
    }

    private static func dayTitle(_ raw: String) -> String {
        let noTime = raw.replacingOccurrences(
            of: #"\s+at\s+\d{1,2}:\d{2}.*$"#,
            with: "",
            options: .regularExpression)
        return noTime.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dayID(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// 去掉分块内外的注释行 / 大标题行，保留正文。
    private static func cleanBody(_ body: String) -> String {
        body.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("<!--") && trimmed.hasSuffix("-->") { return false }
                if trimmed == "#" || trimmed == "# Dream Diary" { return false }
                return true
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeDay(id: String, title: String, body: String) -> HomeMemoryDiaryDay {
        HomeMemoryDiaryDay(
            id: id.isEmpty ? "day" : id,
            title: title.isEmpty ? String(localized: "Dream Diary") : title,
            body: body.isEmpty ? String(localized: "No diary prose for this day.") : body,
            entryCount: 1)
    }
}

/// 相对时间文案（毫秒时间戳 → 刚刚 / N 分钟前 / N 小时前 / N 天前）。
enum HomeMemoryRelativeTime {
    static func string(fromMilliseconds ms: Int?) -> String {
        guard let ms else { return String(localized: "No update timestamp") }
        let seconds = max(0, (Date().timeIntervalSince1970 * 1000 - Double(ms)) / 1000)
        if seconds < 60 {
            return String(localized: "Just now")
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return String(localized: "\(minutes) minutes ago")
        }
        let hours = minutes / 60
        if hours < 24 {
            return String(localized: "\(hours) hours ago")
        }
        let days = hours / 24
        return String(localized: "\(days) days ago")
    }
}