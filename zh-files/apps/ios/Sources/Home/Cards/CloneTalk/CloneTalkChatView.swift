import AVFAudio
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
    @State private var showsAssistantTrace = false
    @State private var transcriptShareItem: TranscriptShareItem?
    @State private var showsTranscriptExportError = false
    @State private var speech: OpenClawChatSpeechController?

    private struct TranscriptShareItem: Identifiable {
        let id = UUID()
        let fileURL: URL
    }

    private static let dedicatedSessionKey = "clone-talk"
    private static let personaInjectionKey = "openclaw_home_clone_talk_persona_injected_v1"

    var body: some View {
        Group {
            if let viewModel {
                OpenClawChatView(
                    viewModel: viewModel,
                    drawsBackground: true,
                    showsSessionSwitcher: false,
                    userAccent: OpenClawBrand.accent,
                    showsAssistantTrace: showsAssistantTrace,
                    assistantName: personaStore.persona.name,
                    assistantAvatarText: avatarText,
                    assistantAvatarTint: OpenClawBrand.carapaceCoral,
                    showsAssistantAvatars: true,
                    composerChrome: .clean,
                    isComposerEnabled: appModel.isOperatorGatewayConnected,
                    isAttachmentInputEnabled: appModel.isOperatorGatewayConnected,
                    messagePlaceholder: String(localized: "Message your AI clone…"),
                    emptyAssistantIntro: String(
                        localized: "You are chatting with \(personaStore.persona.name). The clone answers through the OpenClaw gateway."),
                    talkControl: Self.shouldExposeCaptureControl(
                        isAttachmentOwnerPinned: viewModel.isAttachmentOwnerPinned,
                        isCaptureInFlight: appModel.talkMode.isEnabled) ? talkControl : nil,
                    dictationControl: Self.shouldExposeCaptureControl(
                        isAttachmentOwnerPinned: viewModel.isAttachmentOwnerPinned,
                        isCaptureInFlight: appModel.isChatDictationPending || appModel.isChatDictationActive)
                        ? dictationControl
                        : nil,
                    voiceNoteControl: voiceNoteControl,
                    speech: speech,
                    mediaPlaybackAllowed: {
                        !appModel.talkMode.isEnabled &&
                            !appModel.talkMode.hasActivePushToTalkSession &&
                            !appModel.voiceNoteRecorder.ownsPendingChatAttachment
                    })
                    .environment(\.openClawAssistantBubblesInCleanChrome, true)
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
                Menu {
                    Button {
                        showsPersonaEditor = true
                    } label: {
                        Label(String(localized: "Edit Persona"), systemImage: "person.crop.circle.badge.gearshape")
                            .font(OpenClawType.body)
                    }

                    Button {
                        resetPersona()
                    } label: {
                        Label(String(localized: "Reset Persona"), systemImage: "arrow.counterclockwise")
                            .font(OpenClawType.body)
                    }
                    .disabled(viewModel == nil || !appModel.isOperatorGatewayConnected)

                    Divider()

                    Button {
                        Task { await startNewChat() }
                    } label: {
                        Label(String(localized: "New Chat"), systemImage: "plus.bubble")
                            .font(OpenClawType.body)
                    }
                    .disabled(viewModel == nil || !appModel.isOperatorGatewayConnected)

                    Button {
                        clearConversation()
                    } label: {
                        Label(String(localized: "Clear Conversation"), systemImage: "trash")
                            .font(OpenClawType.body)
                    }
                    .disabled(viewModel == nil || !appModel.isOperatorGatewayConnected)

                    Divider()

                    Button {
                        exportTranscript()
                    } label: {
                        Label(String(localized: "Export Conversation"), systemImage: "square.and.arrow.up")
                            .font(OpenClawType.body)
                    }
                    .disabled(viewModel == nil)

                    Toggle(isOn: $showsAssistantTrace) {
                        Label(String(localized: "Show reasoning & tool activity"), systemImage: "brain.head.profile")
                            .font(OpenClawType.body)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(String(localized: "Clone chat actions"))
            }
        }
        .task {
            await setupChat()
            if speech == nil {
                let gateway = appModel.operatorSession
                speech = OpenClawChatSpeechController { text in
                    try await ChatMessageSpeechClient.synthesize(text: text, gateway: gateway)
                }
            }
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
        .sheet(item: $transcriptShareItem) { item in
            ChatTranscriptShareSheet(fileURL: item.fileURL)
        }
        .alert(
            String(localized: "Unable to Export Transcript"),
            isPresented: $showsTranscriptExportError)
        {
            Button(role: .cancel) {} label: {
                Text(String(localized: "OK"))
                    .font(OpenClawType.body)
            }
        } message: {
            Text(String(localized: "OpenClaw could not prepare the Markdown file."))
                .font(OpenClawType.body)
        }
    }

    private var avatarText: String {
        personaStore.persona.avatarEmoji.isEmpty ? "🤖" : String(personaStore.persona.avatarEmoji.prefix(2))
    }

    nonisolated private static func shouldExposeCaptureControl(
        isAttachmentOwnerPinned: Bool,
        isCaptureInFlight: Bool) -> Bool
    {
        !isAttachmentOwnerPinned || isCaptureInFlight
    }

    private var talkControl: OpenClawChatTalkControl {
        OpenClawChatTalkControl(
            isEnabled: appModel.talkMode.isEnabled,
            isListening: appModel.talkMode.isListening,
            isSpeaking: appModel.talkMode.isSpeaking,
            isGatewayConnected: appModel.talkMode.isGatewayConnected,
            statusText: appModel.talkMode.statusText,
            providerLabel: appModel.talkMode.gatewayTalkProviderLabel,
            level: talkLevel,
            inputDevices: talkInputDevices,
            selectedInputDeviceID: selectedTalkInputDeviceID,
            selectInputDevice: { deviceID in appModel.talkMode.selectInputDevice(deviceID) },
            cameraFacing: appModel.preferredCameraFacing == .front ? .front : .back,
            flipCamera: { appModel.flipPreferredCameraFacing() },
            toggle: { _ in appModel.setTalkEnabled(!appModel.talkMode.isEnabled) })
    }

    private var talkInputDevices: [OpenClawChatAudioInputDevice] {
        (AVAudioSession.sharedInstance().availableInputs ?? []).map { input in
            OpenClawChatAudioInputDevice(id: input.uid, name: input.portName)
        }
    }

    private var selectedTalkInputDeviceID: String? {
        guard let preferredID = appModel.talkMode.preferredInputDeviceID,
              talkInputDevices.contains(where: { $0.id == preferredID }) else { return nil }
        return preferredID
    }

    private var talkLevel: Double {
        if appModel.talkMode.isSpeaking { return appModel.talkMode.playbackLevel ?? 0 }
        if appModel.talkMode.isListening { return appModel.talkMode.micLevel }
        return 0
    }

    private var dictationControl: OpenClawChatDictationControl {
        OpenClawChatDictationControl(
            isActive: appModel.isChatDictationActive,
            isAvailable: !appModel.isTalkCaptureActive || appModel.isChatDictationActive,
            start: { try await appModel.transcribeChatDraft() },
            finish: { appModel.finishChatDictation() },
            cancel: { appModel.cancelChatDictation() })
    }

    private var voiceNoteControl: OpenClawChatVoiceNoteControl {
        OpenClawChatVoiceNoteControl(
            recorder: appModel.voiceNoteRecorder,
            isTalkActive: appModel.isTalkCaptureActive)
    }

    // MARK: - 场景菜单动作

    /// 重置人设：清除「已注入」标记后复用注入流程，向当前会话重发人设消息。
    private func resetPersona() {
        guard let viewModel else { return }
        Self.clearPersonaInjectionMarker()
        startPersonaInjectionIfNeeded(viewModel: viewModel)
    }

    /// 新对话：网关建新会话后清掉注入标记，让新会话重新注入人设。
    private func startNewChat() async {
        guard let viewModel else { return }
        await viewModel.startNewSession()
        Self.clearPersonaInjectionMarker()
        startPersonaInjectionIfNeeded(viewModel: viewModel)
    }

    /// 清除对话：网关没有公开的「仅清空消息」API，用 sessions.reset（保留专属 key、清空会话后重引导），
    /// 再重注入人设，让分身继续按人设对话。
    private func clearConversation() {
        guard let viewModel else { return }
        viewModel.requestSessionReset()
        Self.clearPersonaInjectionMarker()
        startPersonaInjectionIfNeeded(viewModel: viewModel)
    }

    /// 导出对话：复用 ChatTranscriptShareSheet 做文本分享。
    private func exportTranscript() {
        guard let viewModel else { return }
        let title = viewModel.sessions.first { $0.key == viewModel.sessionKey }?.displayName
        let filename = ChatTranscriptExporter.filename(
            sessionTitle: title,
            sessionKey: viewModel.sessionKey)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenClawTranscripts", isDirectory: true)
        let fileURL = directory.appendingPathComponent(filename, isDirectory: false)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try viewModel.exportTranscriptMarkdown().write(to: fileURL, atomically: true, encoding: .utf8)
            transcriptShareItem = TranscriptShareItem(fileURL: fileURL)
        } catch {
            showsTranscriptExportError = true
        }
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
            attachmentOwnerIsActive: { appModel.voiceNoteRecorder.ownsPendingChatAttachment },
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

    /// 清除「已注入」标记：让 startPersonaInjectionIfNeeded 重新注入人设。
    private static func clearPersonaInjectionMarker() {
        UserDefaults.standard.removeObject(forKey: personaInjectionKey)
    }
}
