import Foundation

// MARK: - 会议纪要本地整理

/// 会议纪要本地整理：按句末标点切分转写文本，用关键词归类议题/决定/待办，
/// 生成标题与摘要。纯本地规则（未接 AI），整理结果诚实标注「本地整理」。
enum MeetingLocalOrganizer {
    static func makeNote(transcript: String, title: String?, participants: [String], date: Date) -> MeetingNote {
        let segments = splitSentences(transcript)
        var topics: [String] = []
        var decisions: [String] = []
        var actionItems: [ActionItem] = []

        for segment in segments {
            let text = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if containsAny(text, in: decisionKeywords) {
                decisions.append(text)
            } else if containsAny(text, in: actionKeywords) {
                actionItems.append(ActionItem(text: text, assignee: extractAssignee(from: text)))
            } else {
                topics.append(text)
            }
        }

        let resolvedTitle = resolveTitle(title, firstSegment: segments.first, date: date)
        let summary = makeSummary(topics: topics, decisions: decisions, actionItems: actionItems, transcript: transcript)

        return MeetingNote(
            date: date,
            title: resolvedTitle,
            participants: participants,
            topics: topics,
            decisions: decisions,
            actionItems: actionItems,
            summary: summary,
            rawTranscript: transcript,
            organizedByAI: false
        )
    }

    private static let decisionKeywords = ["决定", "同意", "确认", "拍板", "定了", "就这么办", "通过"]
    private static let actionKeywords = ["待办", "需要做", "要做", "我来", "记得", "别忘了", "跟进", "负责", "安排"]

    /// 按中英文句末标点切分（句号/问号/感叹号/分号/换行）。
    private static func splitSentences(_ transcript: String) -> [String] {
        let normalized = transcript
            .replacingOccurrences(of: "\n", with: "。")
            .replacingOccurrences(of: "；", with: "。")
            .replacingOccurrences(of: ";", with: "。")
        let parts = normalized.components(separatedBy: CharacterSet(charactersIn: "。！？!?."))
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func containsAny(_ text: String, in keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    /// 「由张三负责」→ 张三；「我来」→ 我（自己）；识别不到返回 nil，不编造。
    private static func extractAssignee(from text: String) -> String? {
        let patterns = ["由(.+?)负责", "由(.+?)处理", "由(.+?)来做", "交给(.+?)"]
        for pattern in patterns {
            if let match = firstMatch(pattern, in: text),
               match.groups.count > 1 {
                let name = match.groups[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    return name
                }
            }
        }
        if text.contains("我来") {
            return "我"
        }
        return nil
    }

    private static func resolveTitle(_ title: String?, firstSegment: String?, date: Date) -> String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let firstSegment, !firstSegment.isEmpty {
            let prefix = String(firstSegment.prefix(20))
            return prefix.count < firstSegment.count ? prefix + "…" : prefix
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return String(format: String(localized: "Record.Meeting.DefaultTitle"), formatter.string(from: date))
    }

    /// 摘要：议题/决定/待办数量 + 首条议题，如实反映整理结果。
    private static func makeSummary(topics: [String], decisions: [String], actionItems: [ActionItem], transcript: String) -> String {
        let countText = String(
            format: String(localized: "Record.Meeting.Summary.Count"),
            topics.count, decisions.count, actionItems.count
        )
        if let firstTopic = topics.first {
            return countText + String(format: String(localized: "Record.Meeting.Summary.FirstTopic"), firstTopic)
        }
        let prefix = String(transcript.prefix(40))
        return countText + (prefix.isEmpty ? "" : String(format: String(localized: "Record.Meeting.Summary.Transcript"), prefix))
    }

    /// 正则首个匹配：整体 + 捕获组；无匹配返回 nil。
    private static func firstMatch(_ pattern: String, in text: String) -> (whole: String, groups: [String])? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }
        var groups: [String] = []
        for index in 0..<match.numberOfRanges {
            let range = match.range(at: index)
            groups.append(range.location == NSNotFound ? "" : nsText.substring(with: range))
        }
        guard let whole = groups.first else { return nil }
        return (whole, groups)
    }
}

// MARK: - 手记本地生成

/// 手记本地降级生成：把口述要点按句号拼接、按目标长度合并成段落。
/// 纯本地规则（未接 AI），生成结果诚实标注「本地生成」。
enum WritingLocalFallback {
    /// 段落目标长度（字符）：优先保持要点完整，尽量让每段落在该长度左右。
    private static let targetParagraphLength = 120
    /// 过渡词：给非首个要点加简单过渡，让拼接读起来自然一点。
    private static let transitions = ["首先", "其次", "然后", "接着", "最后"]

    static func buildParagraphs(from points: [String]) -> [String] {
        guard !points.isEmpty else { return [] }

        var paragraphs: [String] = []
        var current = ""
        for (index, point) in points.enumerated() {
            let sentence = normalizedSentence(point, transition: transitionWord(at: index))
            if !current.isEmpty && current.count + sentence.count > targetParagraphLength {
                paragraphs.append(current)
                current = sentence
            } else {
                current = current.isEmpty ? sentence : current + sentence
            }
        }
        if !current.isEmpty {
            paragraphs.append(current)
        }
        return paragraphs
    }

    /// 保证要点以句号结尾；非首个要点加「首先/其次/…」过渡。
    private static func normalizedSentence(_ point: String, transition: String?) -> String {
        let trimmed = point.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var sentence = trimmed
        if let last = sentence.last, "。！？!?.".contains(last) == false {
            sentence += "。"
        }
        if let transition, !transition.isEmpty {
            return "\(transition)，\(sentence)"
        }
        return sentence
    }

    private static func transitionWord(at index: Int) -> String? {
        guard index > 0 else { return nil }
        let idx = min(index - 1, transitions.count - 1)
        return transitions[idx]
    }

    /// 标题：第一个要点前 15 字（本地生成不编造标题）。
    static func resolveTitle(firstPoint: String?) -> String {
        guard let firstPoint, !firstPoint.isEmpty else { return String(localized: "Record.Note.Untitled") }
        return firstPoint.count > 15 ? String(firstPoint.prefix(15)) + "…" : firstPoint
    }
}