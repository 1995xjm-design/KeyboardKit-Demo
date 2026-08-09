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
