//
//  ChineseInputController.swift
//  Keyboard
//
//  Shared pinyin input state machine for the KeyboardKit
//  demo keyboard. Ported from LoveKeyboard's input logic.
//

import Foundation
import SwiftUI

/// Manages pinyin composition state and the keyboard
/// feature panels (symbol keyboard, help reply, super talk).
final class ChineseInputController: ObservableObject {

    // MARK: - Published state

    /// The pinyin syllables accumulated so far.
    @Published var pinyinBuffer = ""

    /// Candidate characters for the current pinyin buffer.
    @Published var candidates: [String] = []

    /// Whether pinyin composition is active (Chinese mode).
    @Published var isChineseMode = true

    /// Whether the symbol keyboard is showing.
    @Published var isSymbolKeyboard = false

    /// The currently visible feature panel, if any.
    @Published var activePanel: Panel?

    /// Feature panels that can replace the keyboard.
    enum Panel: String, Identifiable {
        case helpReply
        case superTalk
        case more

        var id: String { rawValue }
    }

    // MARK: - Dependencies

    private let engine = PinyinEngine()

    // MARK: - Computed state

    var hasActiveInput: Bool { !pinyinBuffer.isEmpty }

    var isKeyboardReplaced: Bool { activePanel != nil }

    // MARK: - Character handling

    /// Handles a tapped character key. Returns the text that
    /// should be inserted, or `nil` when the key press was
    /// consumed by the pinyin engine.
    func handleCharacter(_ char: String) -> String? {
        guard isChineseMode, char.count == 1, let c = char.first, c.isLetter else {
            return char
        }
        pinyinBuffer.append(c.lowercased())
        refreshCandidates()
        return nil
    }

    /// Handles backspace. Returns `true` when the press was
    /// consumed by the pinyin buffer.
    func handleDelete() -> Bool {
        guard isChineseMode else { return false }
        guard !pinyinBuffer.isEmpty else { return false }
        pinyinBuffer.removeLast()
        refreshCandidates()
        return true
    }

    /// Handles space. Returns the text to insert (a candidate
    /// when available, otherwise a space).
    func handleSpace() -> String? {
        guard isChineseMode else { return " " }
        if !pinyinBuffer.isEmpty, let first = candidates.first {
            return select(first)
        }
        return " "
    }

    /// Handles return. Returns the committed text to insert,
    /// or `nil` when nothing should be inserted.
    func handleReturn() -> String? {
        commit()
    }

    /// Selects a candidate, clearing the pinyin buffer.
    /// Returns the text to insert.
    @discardableResult
    func select(_ candidate: String) -> String {
        pinyinBuffer = ""
        candidates = []
        return candidate
    }

    /// Commits the current pinyin buffer. Returns the text to
    /// insert (best candidate, or the raw pinyin).
    func commit() -> String? {
        guard isChineseMode, !pinyinBuffer.isEmpty else { return nil }
        let output = candidates.first ?? pinyinBuffer
        pinyinBuffer = ""
        candidates = []
        return output
    }

    /// Toggles between Chinese and English input mode.
    @discardableResult
    func toggleMode() -> Bool {
        isChineseMode.toggle()
        if !isChineseMode { clear() }
        return isChineseMode
    }

    /// Clears the pinyin buffer.
    func clear() {
        pinyinBuffer = ""
        candidates = []
    }

    // MARK: - Panels

    func showHelpReply() {
        activePanel = .helpReply
    }

    func showSuperTalk() {
        activePanel = .superTalk
    }

    func showMore() {
        activePanel = .more
    }

    func closePanel() {
        activePanel = nil
    }

    func toggleSymbolKeyboard() {
        clear()
        isSymbolKeyboard.toggle()
    }

    // MARK: - Private

    private func refreshCandidates() {
        candidates = pinyinBuffer.isEmpty
            ? []
            : engine.getCandidates(for: pinyinBuffer)
    }
}
