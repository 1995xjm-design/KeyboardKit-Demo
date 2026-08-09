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
// T9 (nine-grid) keyboard matching the LOVE KEY layout:
// a 4x5 grid with a punctuation column, letter keys and a
// high-frequency action column, plus a bottom navigation bar.
// The space key spans two columns and supports long-press
// drag to move the input cursor.
//
// Structure: the left side is a 4-column grid (punctuation +
// letters + bottom row); the right side is a 1-column action
// stack (delete / return / tall confirm). This mirrors the
// reference layout where the search key spans two rows.

/// Nine-grid keyboard with the LOVE KEY 4x5 layout.
struct T9KeyboardView: View {

    let isChineseMode: Bool
    let onDigit: (String) -> Void
    let onPunctuation: (String) -> Void
    let onSymbol1: () -> Void
    let onSymbols: () -> Void
    let onNumeric: () -> Void
    let onConfirm: () -> Void
    let onToggleMode: () -> Void
    let onSpace: () -> Void
    let onSpaceDrag: (CGFloat) -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void
    let onDictation: () -> Void
    let onLocaleSwitch: () -> Void

    @State private var isSpaceDragging = false
    @State private var accumulatedDrag: CGFloat = 0

    var body: some View {
        VStack(spacing: 6) {
            keyGrid
            bottomBar
        }
        .padding(4)
        .background(Color(.systemGroupedBackground))
    }
}

private extension T9KeyboardView {

    // Left 4-column grid + right action column.
    var keyGrid: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                    GridRow {
                        punctButton("\uFF0C")
                        symbol1Button
                        letterKey("2", letters: "ABC")
                        letterKey("3", letters: "DEF")
                    }
                    GridRow {
                        punctButton("\u3002")
                        letterKey("4", letters: "GHI")
                        letterKey("5", letters: "JKL")
                        letterKey("6", letters: "MNO")
                    }
                    GridRow {
                        punctButton("\uFF1F")
                        letterKey("7", letters: "PQRS")
                        letterKey("8", letters: "TUV")
                        letterKey("9", letters: "WXYZ")
                    }
                    GridRow {
                        symbolsButton
                        numericButton
                        spaceButton
                            .gridCellColumns(2)
                        modeButton
                    }
                }
                .gridCellColumns(4)

                // Right action column: delete, return, tall confirm.
                VStack(spacing: 4) {
                    deleteButton
                    returnButton
                    confirmButton
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }

    // Bottom navigation bar (LOVE KEY L4): language + dictation.
    var bottomBar: some View {
        HStack(spacing: 4) {
            Button(action: onLocaleSwitch) {
                Label(LKString("\u4E2D/EN", "EN"), systemImage: "globe")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)

            Button(action: onDictation) {
                Label(LKString("\u8BED\u97F3", "Dictation"), systemImage: "mic.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
    }

    // Letter keys show the digit with its T9 letters.
    func letterKey(_ digit: String, letters: String) -> some View {
        Button {
            onDigit(digit)
        } label: {
            VStack(spacing: 1) {
                Text(digit)
                    .font(.title3.bold())
                Text(letters)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // Punctuation column keys (gray).
    func punctButton(_ symbol: String) -> some View {
        Button {
            onPunctuation(symbol)
        } label: {
            Text(symbol)
                .font(.title2)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // The "@#" key inserts "@" directly.
    var symbol1Button: some View {
        Button(action: onSymbol1) {
            Text(verbatim: "@#")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // Symbols key: opens the symbol keyboard.
    var symbolsButton: some View {
        Button(action: onSymbols) {
            Text(LKString("\u7B26\u53F7", "Sym"))
                .font(.body)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // Numeric key: opens the symbol keyboard for numbers.
    var numericButton: some View {
        Button(action: onNumeric) {
            Text(verbatim: "123")
                .font(.body)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // Confirm (search) key, spans the two lower rows.
    var confirmButton: some View {
        Button(action: onConfirm) {
            VStack(spacing: 2) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                Text(LKString("\u786E\u8BA4", "OK"))
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    var deleteButton: some View {
        Button(action: onDelete) {
            Text(verbatim: "\u232B")
                .font(.title2)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    var returnButton: some View {
        Button(action: onReturn) {
            Text(LKString("\u6362\u884C", "Return"))
                .font(.body)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    var modeButton: some View {
        Button(action: onToggleMode) {
            Text(isChineseMode ? LKString("\u4E2D/\u82F1", "CN") : "EN")
                .font(.body)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // Space key spans two columns; long-press drag moves the cursor.
    var spaceButton: some View {
        Text(LKString("\u7A7A\u683C", "Space"))
            .font(.body)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                isSpaceDragging
                    ? Color(.systemGray4)
                    : Color(.secondarySystemBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
            .gridCellColumns(2)
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
}
