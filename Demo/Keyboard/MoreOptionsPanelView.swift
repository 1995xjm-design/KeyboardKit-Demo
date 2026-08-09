//
//  MoreOptionsPanelView.swift
//  Keyboard
//
//  "More" options panel with keyboard type options and
//  utility entries, ported from LoveKeyboard.
//

import SwiftUI

/// Options panel with keyboard type selection and utility
/// entries. Keyboard types that are not implemented yet are
/// shown as disabled.
struct MoreOptionsPanelView: View {

    let onClose: () -> Void
    let onToggleSymbolKeyboard: () -> Void
    let onPasteFromClipboard: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            header

            // Keyboard type options
            Text(LKString("键盘类型", "Keyboard Type"))
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)

            HStack(spacing: 8) {
                optionButton(title: LKString("26键", "QWERTY"), subtitle: LKString("当前", "Current"), isEnabled: false)
                optionButton(title: LKString("九宫格", "T9"), subtitle: LKString("开发中", "Soon"), isEnabled: false)
                optionButton(title: LKString("手写", "Handwriting"), subtitle: LKString("开发中", "Soon"), isEnabled: false)
            }
            .padding(.horizontal, 12)

            // Utility entries
            Text(LKString("功能", "Utilities"))
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Button {
                    onToggleSymbolKeyboard()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "character.cursor.ibeam")
                            .font(.title3)
                        Text(LKString("符号键盘", "Symbols"))
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    onPasteFromClipboard()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.title3)
                        Text(LKString("剪贴板", "Clipboard"))
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .background(Color(.systemBackground))
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

            Text(LKString("更多", "More"))
                .font(.headline)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 8)
    }

    private func optionButton(title: String, subtitle: String, isEnabled: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.body)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isEnabled ? 1 : 0.6)
        .overlay(
            Group {
                if !isEnabled {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                }
            }
        )
    }
}