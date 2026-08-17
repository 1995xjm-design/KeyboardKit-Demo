import SwiftUI

/// 极简 Markdown 渲染（报告 / 知识两卡共用，自包含、不依赖第三方库）。
///
/// 支持的语法：
/// - 标题 `#` / `##` / `###`
/// - 段落（连续非空行合并）
/// - 无序列表 `- ` / `* `，有序列表 `1. `
/// - 代码块 ``` ``` ```
/// - 引用 `> `
/// - 行内 **粗体** *斜体* `代码` [链接](url)（由 AttributedString 内联解析）
struct HomeMarkdownText: View {
    let markdown: String

    var body: some View {
        let blocks = Self.parseBlocks(markdown)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 块解析

    enum Block {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullet(String)
        case numbered(index: Int, text: String)
        case code([String])
        case quote(String)
    }

    static func parseBlocks(_ markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [Block] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var inCode = false

        func flushParagraph() {
            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
                paragraphLines = []
            }
        }

        for rawLine in lines {
            let line = rawLine
            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(codeLines))
                    codeLines = []
                    inCode = false
                } else {
                    flushParagraph()
                    inCode = true
                }
                continue
            }
            if inCode {
                codeLines.append(line)
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
                continue
            }
            if let heading = headingLevel(line) {
                flushParagraph()
                blocks.append(.heading(level: heading.level, text: heading.text))
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.bullet(String(line.dropFirst(2))))
                continue
            }
            if let numbered = numberedItem(line) {
                flushParagraph()
                blocks.append(.numbered(index: numbered.index, text: numbered.text))
                continue
            }
            if line.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.quote(String(line.dropFirst(2))))
                continue
            }
            paragraphLines.append(line)
        }
        if inCode {
            blocks.append(.code(codeLines))
        }
        flushParagraph()
        return blocks
    }

    private static func headingLevel(_ line: String) -> (level: Int, text: String)? {
        let trimmedLeading = line.drop(while: { $0 == " " })
        var level = 0
        for character in trimmedLeading {
            guard character == "#" else { break }
            level += 1
        }
        guard level >= 1, level <= 3 else { return nil }
        let text = String(trimmedLeading.dropFirst(level))
            .trimmingCharacters(in: .whitespaces)
        return (level, text)
    }

    private static func numberedItem(_ line: String) -> (index: Int, text: String)? {
        let trimmedLeading = line.drop(while: { $0 == " " })
        let digits = trimmedLeading.prefix(while: { $0.isNumber })
        guard !digits.isEmpty, digits.count <= 4 else { return nil }
        let rest = trimmedLeading.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        let index = Int(String(digits)) ?? 0
        let text = String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return (index, text)
    }

    // MARK: - 渲染

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            inlineText(text, font: headingFont(level), color: .primary)
                .padding(.top, level == 1 ? 2 : 0)
        case .paragraph(let text):
            inlineText(text, font: OpenClawType.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(OpenClawType.body)
                    .foregroundStyle(OpenClawBrand.accent)
                inlineText(text, font: OpenClawType.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .numbered(let index, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(index).")
                    .font(OpenClawType.body)
                    .foregroundStyle(.secondary)
                inlineText(text, font: OpenClawType.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .code(let lines):
            Text(lines.joined(separator: "\n"))
                .font(OpenClawType.monoSmall)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        case .quote(let text):
            inlineText(text, font: OpenClawType.body)
                .foregroundStyle(.secondary)
                .italic()
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(OpenClawBrand.accent.opacity(0.4))
                        .frame(width: 3)
                }
        }
    }

    private func inlineText(_ text: String, font: Font, color: Color) -> Text {
        let attributed: AttributedString
        if let parsed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace))
        {
            attributed = parsed
        } else {
            attributed = AttributedString(text)
        }
        return Text(attributed)
            .font(font)
            .foregroundColor(color)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return OpenClawType.title3SemiBold
        case 2: return OpenClawType.headlineBold
        default: return OpenClawType.subheadSemiBold
        }
    }
}

