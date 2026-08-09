//
//  HelpReplyPanelView.swift
//  Keyboard
//
//  "Help Reply" quick-reply panel, ported from LoveKeyboard.
//

import SwiftUI

/// Quick reply panel with paste support and preset replies.
/// Tap a reply to insert it into the current text field.
struct HelpReplyPanelView: View {

    let onClose: () -> Void
    let onPaste: () -> String?
    let onSelect: (String) -> Void

    /// Preset quick replies (from LoveKeyboard).
    private let quickReplies = [
        "好的", "谢谢", "没问题", "稍等",
        "收到", "明白", "好的呢", "马上"
    ]

    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 12) {
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

                Text(LKString("帮你回", "Help Reply"))
                    .font(.headline)

                Spacer()

                Button {
                    if let pasted = onPaste() {
                        inputText = pasted
                    }
                } label: {
                    Text(LKString("粘贴", "Paste"))
                        .font(.body)
                        .frame(width: 48, height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            // Input display
            Text(inputText.isEmpty ? LKString("粘贴要回复的内容", "Paste text to reply") : inputText)
                .font(.subheadline)
                .foregroundStyle(inputText.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)

            // Quick replies
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { column in
                            let index = row * 4 + column
                            if index < quickReplies.count {
                                Button {
                                    onSelect(quickReplies[index])
                                } label: {
                                    Text(quickReplies[index])
                                        .font(.body)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
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

            Spacer()
        }
        .padding(.top, 4)
        .background(Color(.systemBackground))
    }
}
