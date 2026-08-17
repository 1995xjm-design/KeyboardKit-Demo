import OpenClawChatUI
import OpenClawKit
import OpenClawProtocol
import SwiftUI

/// AI 分身聊天（G-memory）：
/// 对话走 OpenClaw 网关 Agent（OpenClawChatViewModel + OpenClawChatView，参考 Sources/Chat 对外接口），
/// 专属会话 key 与主聊天隔离；进入后自动注入一次人设消息，让 Agent 全程保持人设。
/// 人设编辑后 revision 递增 → 聊天视图重建并重注入更新后的人设。
/// 网关未连接 → 输入框禁用并诚实提示，不造假回复。
@MainActor
struct CloneTalkChatView: View {
    @Environment(NodeAppModel.self) private var appModel

    @State private var personaStore = CloneTalkPersonaStore()
    @State private var viewModel: OpenClawChatViewModel?
    @State private var personaInjectionTask: Task<Void, Never>?
    @State private var showsPersonaEditor = false

    private static let dedicatedSessionKey = "clone-talk"
    private static let personaInjectionKey = "openclaw_home_clone_talk_persona_injected_v1"

    var body: some View {
        Group {
            if let viewModel {
                OpenClawChatView(
                    viewModel: viewModel,
                    drawsBackground: true,
                    showsSessionSwitcher: false,
                    userAccent: OpenClawBrand.carapaceCoral,
                    showsAssistantTrace: false,
                    assistantName: personaStore.persona.name,
                    assistantAvatarText: avatarText,
                    assistantAvatarTint: OpenClawBrand.carapaceCoral,
                    showsAssistantAvatars: false,
                    composerChrome: .clean,
                    isComposerEnabled: appModel.isOperatorGatewayConnected,
                    isAttachmentInputEnabled: false,
                    messagePlaceholder: String(localized: "Message your AI clone…"),
                    emptyAssistantIntro: String(
                        localized: "You are chatting with \(personaStore.persona.name). The clone answers through the OpenClaw gateway.")
                )
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(String(localized: "Preparing clone chat…"))
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(personaStore.persona.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsPersonaEditor = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.gearshape")
                }
                .accessibilityLabel(String(localized: "Edit Persona"))
            }
        }
        .task {
            await setupChat()
        }
        .onDisappear {
            personaInjectionTask?.cancel()
        }
        .onChange(of: appModel.isOperatorGatewayConnected) { _, connected in
            if connected, let viewModel {
                startPersonaInjectionIfNeeded(viewModel: viewModel)
            }
        }
        .onChange(of: personaStore.revision) { _, _ in
            if let viewModel {
                startPersonaInjectionIfNeeded(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showsPersonaEditor) {
            CloneTalkPersonaEditorView(store: personaStore)
        }
    }

    private var avatarText: String {
        personaStore.persona.avatarEmoji.isEmpty ? "🤖" : String(personaStore.persona.avatarEmoji.prefix(2))
    }

    // MARK: - 组装

    @MainActor
    private func setupChat() async {
        guard viewModel == nil else { return }

        let offlineStore = appModel.makeChatOfflineStore()
        let transport = appModel.makeChatTransport(outboxGatewayID: offlineStore?.gatewayID)
        var sessionKey = Self.dedicatedSessionKey

        // 网关在线时确保专属会话存在（幂等：已存在会被网关忽略/返回已有 key）。
        if appModel.isOperatorGatewayConnected {
            if let created = try? await transport.createSession(
                key: Self.dedicatedSessionKey,
                label: String(localized: "AI Clone Chat"),
                agentID: nil,
                parentSessionKey: nil,
                worktree: nil,
                worktreeBaseRef: nil)
            {
                let resolved = created.key.trimmingCharacters(in: .whitespacesAndNewlines)
                if !resolved.isEmpty {
                    sessionKey = resolved
                }
            }
        }

        let viewModel = OpenClawChatViewModel(
            sessionKey: sessionKey,
            transport: transport,
            activeAgentId: appModel.chatDeliveryAgentId,
            sessionRoutingContract: nil,
            attachmentOwnerIsActive: { false },
            transcriptCache: offlineStore,
            outbox: offlineStore,
            onSessionChanged: nil,
            onToolActivity: nil,
            diagnosticsLog: { message in
                GatewayDiagnostics.log("clone-talk: \(message)")
            })
        self.viewModel = viewModel
        viewModel.load()
        startPersonaInjectionIfNeeded(viewModel: viewModel)
    }

    // MARK: - 人设注入

    /// 每个 persona revision 只注入一次（UserDefaults 记录已注入的 revision）。
    /// 注入时机：网关在线 + 会话历史为空（避免重复注入到已有对话）。
    private func startPersonaInjectionIfNeeded(viewModel: OpenClawChatViewModel) {
        let revision = personaStore.revision
        guard appModel.isOperatorGatewayConnected,
              !Self.hasInjectedPersona(revision: revision)
        else { return }

        personaInjectionTask?.cancel()
        // 视图是 struct，直接强捕获（Task 在 onDisappear 取消）；@State 存储为引用语义，读取实时值。
        personaInjectionTask = Task {
            // 等 bootstrap（历史请求）完成再判断是否为空会话，避免误判。
            let deadline = Date().addingTimeInterval(8)
            while viewModel.isLoading, Date() < deadline {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            guard appModel.isOperatorGatewayConnected else { return }
            // 首次（空会话）发人设设定；已有会话发人设更新覆盖消息。
            viewModel.input = viewModel.messages.isEmpty
                ? personaStore.persona.setupMessage
                : personaStore.persona.updateMessage
            viewModel.send()
            Self.markPersonaInjected(revision: revision)
        }
    }

    private static func hasInjectedPersona(revision: Int) -> Bool {
        UserDefaults.standard.integer(forKey: personaInjectionKey) >= revision
    }

    private static func markPersonaInjected(revision: Int) {
        UserDefaults.standard.set(revision, forKey: personaInjectionKey)
    }
}