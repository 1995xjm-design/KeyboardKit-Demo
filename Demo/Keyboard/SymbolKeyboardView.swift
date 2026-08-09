//
//  SymbolKeyboardView.swift
//  Keyboard
//
//  Symbol keyboard with Chinese/English punctuation layouts,
//  ported from LoveKeyboard.
//

import SwiftUI

/// Symbol keyboard replacing the alphabetic layout while
/// active. Uses the LoveKeyboard symbol layouts.
struct SymbolKeyboardView: View {

    let isChineseMode: Bool
    let onSymbol: (String) -> Void
    let onABC: () -> Void
    let onSpace: () -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void

    /// Chinese punctuation layout.
    private let chineseSymbols = [
        ["，", "。", "？", "！", "、", "：", "；", "~"],
        ["（", "）", "【", "】", "《", "》", "「", "」"],
        ["@", "#", "%", "&", "*", "-", "+", "="]
    ]

    /// English punctuation layout.
    private let englishSymbols = [
        [",", ".", "?", "!", "'", "\"", ":", ";"],
        ["(", ")", "[", "]", "{", "}", "<", ">"],
        ["@", "#", "$", "%", "&", "*", "-", "+"]
    ]

    private var rows: [[String]] {
        isChineseMode ? chineseSymbols : englishSymbols
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { symbol in
                        Button {
                            onSymbol(symbol)
                        } label: {
                            Text(symbol)
                                .font(.title3)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Bottom function row: ABC / space / delete / return
            HStack(spacing: 4) {
                Button {
                    onABC()
                } label: {
                    Text(verbatim: "ABC")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)

                Button {
                    onSpace()
                } label: {
                    Text(LKString("空格", "Space"))
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)

                Button {
                    onDelete()
                } label: {
                    Text(verbatim: "⌫")
                        .font(.title2)
                        .frame(width: 64)
                        .frame(height: 42)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)

                Button {
                    onReturn()
                } label: {
                    Text(LKString("换行", "Newline"))
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.systemGroupedBackground))
    }
}


// MARK: - T9KeyboardView
//
// T9 (nine-grid) pinyin keyboard in the same system style as
// the other keyboard views. The space key supports long-press
// drag to move the input cursor, matching KeyboardKit's
// standard space key behavior.

/// Nine-grid pinyin keyboard with KK-style keys.
struct T9KeyboardView: View {

    let isChineseMode: Bool
    let onDigit: (String) -> Void
    let onSymbols: () -> Void
    let onSwitchToQwerty: () -> Void
    let onToggleMode: () -> Void
    let onSpace: () -> Void
    let onSpaceDrag: (CGFloat) -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void

    @State private var isSpaceDragging = false
    @State private var accumulatedDrag: CGFloat = 0

    private let digitRows: [[(digit: String, letters: String)]] = [
        [("1", ""), ("2", "ABC"), ("3", "DEF")],
        [("4", "GHI"), ("5", "JKL"), ("6", "MNO")],
        [("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ")]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(digitRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        digitButton(key.digit, letters: key.letters)
                    }
                }
            }

            // Fourth number row: symbols / 0 / delete
            HStack(spacing: 4) {
                functionButton(LKString("符", "?123"), action: onSymbols)
                digitButton("0", letters: "")
                deleteButton
            }

            // Function row: mode / space / delete / return
            HStack(spacing: 4) {
                modeButton
                spaceButton
                deleteButton
                returnButton
            }
        }
        .padding(4)
        .background(Color(.systemGroupedBackground))
    }
}

private extension T9KeyboardView {

    func digitButton(_ digit: String, letters: String) -> some View {
        Button {
            onDigit(digit)
        } label: {
            VStack(spacing: 1) {
                Text(digit)
                    .font(.title2.bold())
                if !letters.isEmpty {
                    Text(letters)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    func functionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    var deleteButton: some View {
        Button(action: onDelete) {
            Text(verbatim: "⌫")
                .font(.title2)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    var modeButton: some View {
        Button(action: onToggleMode) {
            Text(isChineseMode ? LKString("中/EN", "CN/EN") : "EN")
                .font(.body)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    var spaceButton: some View {
        Text(LKString("空格", "Space"))
            .font(.body)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isSpaceDragging
                    ? Color(.systemGray4)
                    : Color(.secondarySystemBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.25)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .first(true):
                            isSpaceDragging = true
                            accumulatedDrag = 0
                        case .second(true, let drag):
                            if let drag {
                                let delta = drag.translation.width - accumulatedDrag
                                accumulatedDrag = drag.translation.width
                                onSpaceDrag(delta)
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { _ in
                        if isSpaceDragging {
                            isSpaceDragging = false
                        } else {
                            onSpace()
                        }
                    }
            )
    }

    var returnButton: some View {
        Button(action: onReturn) {
            Text(LKString("换行", "Return"))
                .font(.body)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}