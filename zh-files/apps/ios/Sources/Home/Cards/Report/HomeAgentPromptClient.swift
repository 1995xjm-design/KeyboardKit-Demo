import Foundation
import OpenClawChatUI
import OpenClawProtocol

/// 统一的 OpenClaw Agent 提问客户端（报告 / 知识两卡共用）。
///
/// 调用链路（走 Sources/Chat 对外传输接口）：
/// 1. `NodeAppModel.makeChatTransport()` 取当前网关传输（含演示/截图 fixture 传输）；
/// 2. 按 Agent 会话 key 约定建会话（已存在则忽略失败）；
/// 3. `sendMessage` 发送 prompt → 得到 runId；
/// 4. `waitForRunCompletion` 服务端阻塞等待运行结束（不支持的传输自动降级）；
/// 5. `requestHistory` 拉取会话历史，取最后一条 assistant 文本作为结果。
///
/// 诚实原则：网关未连接/生成失败/超时均如实报错，不返回假数据。
@MainActor
enum HomeAgentPromptClient {

    enum HomeAgentPromptError: LocalizedError {
        case emptyPrompt
        case gatewayNotConnected
        case sendFailed(String)
        case agentFailed(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .emptyPrompt:
                String(localized: "Please enter a prompt first.")
            case .gatewayNotConnected:
                String(localized: "OpenClaw gateway is not connected. Connect it first, then try again.")
            case .sendFailed(let reason):
                String.localizedStringWithFormat(
                    String(localized: "Failed to reach the agent: %@"), reason)
            case .agentFailed(let reason):
                String.localizedStringWithFormat(
                    String(localized: "The agent failed to finish: %@"), reason)
            case .timedOut:
                String(localized: "The agent did not reply in time. Try again later.")
            }
        }
    }

    /// 发送 prompt 并等待 Agent 回复，返回回复正文（可能含 Markdown）。
    /// - Parameters:
    ///   - appModel: 应用模型，提供网关传输与当前 Agent。
    ///   - prompt: 发给 Agent 的完整提示词。
    ///   - sessionBaseKey: 会话基底 key（如 report / knowledge），隔离不同卡片会话。
    ///   - timeoutSeconds: 总等待上限（含 wait + 轮询兜底）。
    static func prompt(
        appModel: NodeAppModel,
        prompt: String,
        sessionBaseKey: String,
        timeoutSeconds: Int = 120
    ) async throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HomeAgentPromptError.emptyPrompt }
        guard appModel.isLocalGatewayFixtureEnabled || appModel.isOperatorGatewayConnected else {
            throw HomeAgentPromptError.gatewayNotConnected
        }

        let transport = appModel.makeChatTransport()
        let agentID = appModel.chatDeliveryAgentId
        let sessionKey = SessionKey.makeAgentSessionKey(
            agentId: agentID ?? "main",
            baseKey: sessionBaseKey)

        // 会话可能已存在；创建失败不阻断发送（网关侧按 key 幂等）。
        _ = try? await transport.createSession(
            key: sessionKey,
            label: nil,
            agentID: agentID,
            parentSessionKey: nil,
            worktree: nil,
            worktreeBaseRef: nil)

        let sendResponse: OpenClawChatSendResponse
        do {
            sendResponse = try await transport.sendMessage(
                sessionKey: sessionKey,
                message: trimmed,
                thinking: "",
                idempotencyKey: UUID().uuidString,
                attachments: [])
        } catch {
            throw HomeAgentPromptError.sendFailed(error.localizedDescription)
        }

        let runId = sendResponse.runId.trimmingCharacters(in: .whitespacesAndNewlines)
        let deadline = Date().addingTimeInterval(Double(timeoutSeconds))

        // 优先服务端等待：agent.wait 会阻塞到运行结束；不支持的传输返回 unavailable，走轮询兜底。
        if !runId.isEmpty {
            let observation = await transport.waitForRunCompletion(
                runId: runId,
                timeoutMs: timeoutSeconds * 1000)
            switch observation {
            case .terminal(.completed):
                break
            case .terminal(.failed(let message)):
                throw HomeAgentPromptError.agentFailed(message)
            case .checkAgain, .unavailable:
                break
            }
        }

        // 轮询兜底：读会话历史直到出现 assistant 正文或超时。
        var lastSendError: Error?
        while Date() < deadline {
            try Task.checkCancellation()
            do {
                let payload = try await transport.requestHistory(sessionKey: sessionKey)
                lastSendError = nil
                if let text = Self.latestAssistantText(in: Self.decodeMessages(payload.messages ?? [])) {
                    return text
                }
            } catch {
                lastSendError = error
            }
            try await Task.sleep(for: .seconds(1.5))
        }
        if let lastSendError {
            throw HomeAgentPromptError.sendFailed(lastSendError.localizedDescription)
        }
        throw HomeAgentPromptError.timedOut
    }

    // MARK: - 历史解析

    private static func decodeMessages(_ raw: [AnyCodable]) -> [OpenClawChatMessage] {
        raw.compactMap { item in
            guard let data = try? JSONEncoder().encode(item),
                  let message = try? JSONDecoder().decode(OpenClawChatMessage.self, from: data)
            else {
                return nil
            }
            return message
        }
    }

    /// 取最近一条非空 assistant 正文（与聊天可见文本同规则，去掉 tool 痕迹与 thinking）。
    private static func latestAssistantText(in messages: [OpenClawChatMessage]) -> String? {
        for message in messages.reversed() {
            let role = message.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard role == "assistant" else { continue }
            let text = ChatMessageVisibleText.visibleText(in: message)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }
        return nil
    }
}
