//
//  SuperTalkPanelView.swift
//  Keyboard
//
//  "Super Talk" love-message panel, ported from LoveKeyboard.
//  Includes its own mini keyboard with pinyin candidates and
//  preset love-message templates.
//

import SwiftUI

/// Love-message composer with a mini keyboard, pinyin input
/// and preset templates. Ported from LoveKeyboard.
struct SuperTalkPanelView: View {

    let onClose: () -> Void
    let onSelectResult: (String) -> Void

    /// Preset love templates (from LoveKeyboard).
    private let loveTemplates = [
        "早上好，今天也要开心哦",
        "晚安，好梦",
        "我爱你，永远爱你",
        "想你了，你在干嘛",
        "吃饭了吗？记得按时吃饭",
        "天冷了，多穿点衣服",
        "工作顺利吗？加油哦",
        "今天辛苦了，好好休息"
    ]

    /// Mini keyboard rows (from LoveKeyboard).
    private let keyboardRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m", "⌫"]
    ]

    @StateObject private var input = ChineseInputController()
    @State private var content = ""
    @State private var cursor = 0

    /// Renders the input area with a cursor marker.
    private var displayText: String {
        guard cursor >= 0, cursor <= content.count else { return content }
        let index = content.index(content.startIndex, offsetBy: cursor)
        return String(content[..<index]) + "|" + String(content[index...])
    }

    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Button {
                    onClose()
                } label: {
                    Text(verbatim: "×")
                        .font(.title)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(LKString("超会说", "Super Talk"))
                    .font(.headline)

                Spacer()

                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 8)

            // Input area with cursor controls
            HStack(spacing: 4) {
                Button {
                    moveCursor(-1)
                } label: {
                    Text(verbatim: "<")
                        .font(.body)
                        .frame(width: 40, height: 36)
                }
                .buttonStyle(.plain)

                Text(displayText)
                    .font(.body)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    moveCursor(1)
                } label: {
                    Text(verbatim: ">")
                        .font(.body)
                        .frame(width: 40, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            // Pinyin candidates
            if input.hasActiveInput {
                CandidateBarView(
                    pinyin: input.pinyinBuffer,
                    candidates: input.candidates
                ) { candidate in
                    insert(input.select(candidate))
                }
            }

            // Mini keyboard
            VStack(spacing: 4) {
                ForEach(keyboardRows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.self) { key in
                            if key == "⌫" {
                                Button {
                                    handleDelete()
                                } label: {
                                    Text(verbatim: "⌫")
                                        .font(.title2)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 34)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    handleKey(key)
                                } label: {
                                    Text(verbatim: key)
                                        .font(.body)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 34)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    handleSpace()
                } label: {
                    Text(LKString("空格", "Space"))
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Love templates
            VStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { column in
                            let index = row * 2 + column
                            if index < loveTemplates.count {
                                Button {
                                    onSelectResult(loveTemplates[index])
                                } label: {
                                    Text(loveTemplates[index])
                                        .font(.caption)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .background(Color(.systemBackground))
    }

    // MARK: - Input handling

    private func handleKey(_ key: String) {
        if let output = input.handleCharacter(key) {
            insert(output)
        }
    }

    private func handleDelete() {
        if input.handleDelete() { return }
        guard cursor > 0 else { return }
        let index = content.index(content.startIndex, offsetBy: cursor - 1)
        content.remove(at: index)
        cursor -= 1
    }

    private func handleSpace() {
        if let output = input.handleSpace() {
            insert(output)
        }
    }

    private func insert(_ text: String) {
        guard !text.isEmpty else { return }
        let index = content.index(content.startIndex, offsetBy: cursor)
        content.insert(contentsOf: text, at: index)
        cursor += text.count
    }

    private func moveCursor(_ delta: Int) {
        let target = cursor + delta
        guard target >= 0, target <= content.count else { return }
        cursor = target
    }
}
