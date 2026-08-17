import SwiftUI

/// AI 分身人设编辑（G-memory）：名字 / 头像 / 性格 / 口吻，本地存储。
/// 保存后通过 CloneTalkPersonaStore.revision 通知聊天页重注入人设。
@MainActor
struct CloneTalkPersonaEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let store: CloneTalkPersonaStore

    @State private var name: String
    @State private var personality: String
    @State private var tone: CloneTalkTone
    @State private var avatarEmoji: String

    private static let avatarOptions = ["🤖", "🐱", "🐶", "🦊", "🐼", "🐯", "🧙", "🦄", "👻", "🌟"]

    init(store: CloneTalkPersonaStore) {
        self.store = store
        _name = State(initialValue: store.persona.name)
        _personality = State(initialValue: store.persona.personality)
        _tone = State(initialValue: store.persona.tone)
        _avatarEmoji = State(initialValue: store.persona.avatarEmoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Text(avatarEmoji.isEmpty ? "🤖" : avatarEmoji)
                            .font(.system(size: 34))
                            .frame(width: 52, height: 52)
                            .background(OpenClawBrand.carapaceCoral.opacity(0.16), in: Circle())
                        TextField(String(localized: "Name"), text: $name)
                            .font(OpenClawType.body)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.avatarOptions, id: \.self) { option in
                                Button {
                                    avatarEmoji = option
                                } label: {
                                    Text(option)
                                        .font(.system(size: 26))
                                        .frame(width: 42, height: 42)
                                        .background(
                                            avatarEmoji == option
                                                ? OpenClawBrand.carapaceCoral.opacity(0.22)
                                                : Color.primary.opacity(0.05),
                                            in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(String(localized: "Identity"))
                } footer: {
                    Text(String(localized: "The clone introduces itself with this name and avatar in chat."))
                }

                Section {
                    TextEditor(text: $personality)
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                } header: {
                    Text(String(localized: "Personality"))
                } footer: {
                    Text(String(localized: "Describe the clone's character, e.g. warm, humorous, loves travel."))
                }

                Section {
                    Picker(String(localized: "Tone"), selection: $tone) {
                        ForEach(CloneTalkTone.allCases) { tone in
                            Text(tone.label).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(String(localized: "Tone"))
                } footer: {
                    Text(tone.instruction)
                }
            }
            .navigationTitle(String(localized: "Edit Persona"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .font(OpenClawType.body)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        save()
                    }
                    .font(OpenClawType.body)
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let resolvedName = trimmedName.isEmpty ? CloneTalkPersona.defaultName : trimmedName
        store.save(CloneTalkPersona(
            name: resolvedName,
            personality: personality,
            tone: tone,
            avatarEmoji: avatarEmoji.isEmpty ? "🤖" : avatarEmoji))
        dismiss()
    }
}