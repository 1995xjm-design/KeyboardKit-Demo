//
//  HelpReplyPanelView.swift
//  Keyboard
//
//  "Help Reply" quick-reply panel, ported from LoveKeyboard.
//  Paste text, pick a persona, and generate replies with
//  DeepSeek, or use the preset quick replies.
//

import SwiftUI

/// Quick reply panel with paste support, persona selection
/// and DeepSeek-generated replies.
struct HelpReplyPanelView: View {

    let onClose: () -> Void
    let onPaste: () -> String?
    let onSelect: (String) -> Void

    /// Preset quick replies (from LoveKeyboard).
    private let quickReplies = [
        "好的", "谢谢", "没问题", "稍等",
        "收到", "明白", "好的呢", "马上"
    ]

    /// Persona options (from LoveKeyboard's preset roles).
    private let roles = PresetRoles.getRoles(by: .helpReply)

    @State private var inputText = ""
    @State private var selectedRoleId: String?
    @State private var replies: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var selectedRole: ChatRole? {
        roles.first { $0.id == selectedRoleId } ?? roles.first
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            // Input display
            Text(inputText.isEmpty ? LKString("粘贴要回复的内容", "Paste text to reply") : inputText)
                .font(.subheadline)
                .foregroundStyle(inputText.isEmpty ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)

            // Persona selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(roles) { role in
                        Button {
                            selectedRoleId = role.id
                            replies = []
                            errorMessage = nil
                        } label: {
                            Text(role.name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedRoleId == role.id
                                        ? Color.accentColor.opacity(0.2)
                                        : Color(.tertiarySystemBackground)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(
                                        selectedRoleId == role.id ? Color.accentColor : Color.clear,
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }

            // Generate button
            Button {
                generate()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .frame(height: 20)
                    } else {
                        Text(LKString("AI 生成回复", "Generate Replies"))
                            .font(.body.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    (inputText.isEmpty || isLoading)
                        ? Color(.tertiarySystemBackground)
                        : Color.accentColor.opacity(0.85)
                )
                .foregroundStyle((inputText.isEmpty || isLoading) ? .secondary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || isLoading)
            .padding(.horizontal, 8)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
            }

            // Generated replies
            if !replies.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(replies, id: \.self) { reply in
                            Button {
                                onSelect(reply)
                                onClose()
                            } label: {
                                Text(reply)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            // Quick replies
            if replies.isEmpty {
                VStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { column in
                                let index = row * 4 + column
                                if index < quickReplies.count {
                                    Button {
                                        onSelect(quickReplies[index])
                                        onClose()
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
            }

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
    }

    // MARK: - DeepSeek generation

    private func generate() {
        guard let role = selectedRole, !inputText.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let results = try await APIService.shared.generateHelpReply(
                    content: inputText,
                    role: role,
                    count: 5
                )
                await MainActor.run {
                    replies = results
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