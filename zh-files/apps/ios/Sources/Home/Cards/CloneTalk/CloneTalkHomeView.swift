import SwiftUI

/// AI 分身主页（G-memory）：
/// - 人设概览卡（名字 / 头像 / 性格 / 口吻，本地存储）；
/// - 「开始聊天」：进入分身聊天（OpenClaw 网关 Agent，人设注入）；
/// - 「编辑人设」：修改名字 / 性格 / 语气。
/// 网关未连接时诚实提示：聊天通过 OpenClaw 网关进行，接不到不造假。
@MainActor
struct CloneTalkHomeView: View {
    @Environment(NodeAppModel.self) private var appModel
    @State private var personaStore = CloneTalkPersonaStore()
    @State private var showsPersonaEditor: Bool

    init(launchPersonaEditor: Bool = false) {
        _showsPersonaEditor = State(initialValue: launchPersonaEditor)
    }

    var body: some View {
        List {
            Section {
                personaCard
            } header: {
                Text(String(localized: "AI Clone"))
            } footer: {
                Text(String(localized: "Set a persona, then chat with your clone through the OpenClaw gateway."))
            }

            Section {
                NavigationLink {
                    CloneTalkChatView()
                } label: {
                    Label(String(localized: "Start Chat"), systemImage: "bubble.left.and.bubble.right.fill")
                        .font(OpenClawType.body)
                }
                Button {
                    showsPersonaEditor = true
                } label: {
                    Label(String(localized: "Edit Persona"), systemImage: "person.crop.circle.badge.gearshape")
                        .font(OpenClawType.body)
                        .foregroundStyle(OpenClawBrand.accent)
                }
            }

            if !appModel.isOperatorGatewayConnected {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(String(localized: "Gateway Disconnected"), systemImage: "wifi.slash")
                            .font(OpenClawType.subheadSemiBold)
                            .foregroundStyle(OpenClawBrand.statusWarning)
                        Text(String(localized: "Connect the OpenClaw gateway to chat with your clone. Your persona is saved on this device and will apply once connected."))
                            .font(OpenClawType.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "AI Clone"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsPersonaEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel(String(localized: "Edit Persona"))
            }
        }
        .sheet(isPresented: $showsPersonaEditor) {
            CloneTalkPersonaEditorView(store: personaStore)
        }
    }

    private var personaCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(personaStore.persona.avatarEmoji.isEmpty ? "🤖" : personaStore.persona.avatarEmoji)
                .font(.system(size: 40))
                .frame(width: 64, height: 64)
                .background(OpenClawBrand.carapaceCoral.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(personaStore.persona.name)
                    .font(OpenClawType.title3SemiBold)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(personaStore.persona.tone.label)
                        .font(OpenClawType.captionSemiBold)
                        .foregroundStyle(OpenClawBrand.carapaceCoral)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(OpenClawBrand.carapaceCoral.opacity(0.14), in: Capsule())
                    if personaStore.persona.isUncustomized {
                        Text(String(localized: "Default persona"))
                            .font(OpenClawType.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(personalityPreview)
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
    }

    private var personalityPreview: String {
        let trimmed = personaStore.persona.personality.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            ? String(localized: "No personality description yet. Tap Edit Persona to describe the clone's character.")
            : trimmed
    }
}