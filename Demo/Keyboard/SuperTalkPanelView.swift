//
//  SuperTalkPanelView.swift
//  Keyboard
//
//  "Super Talk" love-message panel, ported from LoveKeyboard.
//  Includes its own mini keyboard with pinyin candidates,
//  preset love-message templates and DeepSeek polishing.
//

import SwiftUI

/// Love-message composer with a mini keyboard, pinyin input,
/// preset templates and DeepSeek-generated polish results.
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

    /// Identity options for DeepSeek polishing.
    private let identities = IdentityType.allCases

    /// Mini keyboard rows (from LoveKeyboard).
    private let keyboardRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m", "⌫"]
    ]

    @StateObject private var input = ChineseInputController()
    @State private var content = ""
    @State private var cursor = 0

    @State private var selectedIdentity = IdentityType.general
    @State private var polishResults: [PolishResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Renders the input area with a cursor marker.
    private var displayText: String {
        guard cursor >= 0, cursor <= content.count else { return content }
        let index = content.index(content.startIndex, offsetBy: cursor)
        return String(content[..<index]) + "|" + String(content[index...])
    }

    private var header: some View {
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
    }

    var body: some View {
        VStack(spacing: 6) {
            header

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
                                        .frame(height: 32)
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
                                        .frame(height: 32)
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
                        .frame(height: 32)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // AI polish: identity selector + button
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(identities, id: \.self) { identity in
                            Button {
                                selectedIdentity = identity
                            } label: {
                                Text(identity.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        selectedIdentity == identity
                                            ? Color.accentColor.opacity(0.2)
                                            : Color(.tertiarySystemBackground)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                Button {
                    polish()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(LKString("AI 润色", "Polish"))
                                .font(.caption.bold())
                        }
                    }
                    .frame(width: 64, height: 28)
                    .background(
                        (content.isEmpty || isLoading)
                            ? Color(.tertiarySystemBackground)
                            : Color.accentColor.opacity(0.85)
                    )
                    .foregroundStyle((content.isEmpty || isLoading) ? .secondary : Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(content.isEmpty || isLoading)
            }
            .padding(.horizontal, 8)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }

            // Polish results replace templates while available
            if !polishResults.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(polishResults) { result in
                            Button {
                                onSelectResult(result.text)
                                onClose()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.styleName)
                                        .font(.caption2.bold())
                                        .foregroundStyle(Color.accentColor)
                                    Text(result.text)
                                        .font(.caption)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } else if !isLoading {
                // Love templates
                VStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<2, id: \.self) { column in
                                let index = row * 2 + column
                                if index < loveTemplates.count {
                                    Button {
                                        onSelectResult(loveTemplates[index])
                                        onClose()
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
            }

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

    // MARK: - DeepSeek polishing

    private func polish() {
        guard !content.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let results = try await APIService.shared.generateSuperTalk(
                    content: content,
                    identity: selectedIdentity,
                    count: 4
                )
                await MainActor.run {
                    polishResults = results
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}