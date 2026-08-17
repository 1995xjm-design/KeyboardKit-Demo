import Foundation

/// 语音助手 DeepSeek 直连通道的对话消息（OpenAI 兼容 chat/completions 的 {role, content}）。
struct DeepSeekChatMessage: Codable, Sendable {
    let role: String
    let content: String

    static func system(_ content: String) -> DeepSeekChatMessage {
        DeepSeekChatMessage(role: "system", content: content)
    }

    static func user(_ content: String) -> DeepSeekChatMessage {
        DeepSeekChatMessage(role: "user", content: content)
    }

    static func assistant(_ content: String) -> DeepSeekChatMessage {
        DeepSeekChatMessage(role: "assistant", content: content)
    }
}

/// DeepSeek API 直连客户端（OpenAI 兼容 /v1/chat/completions）。
///
/// 从 ClawTalk `Core/Agent/DeepSeekDirectClient.swift` 移植：
/// - Key 存 Keychain（account `deepseek_api_key`，service 沿用 OpenClaw talk 凭据 service）
/// - 支持一次性与流式；Key 缺失 / HTTP 错误 / 空响应均给出诚实中文报错
/// - 不依赖 ClawTalk 的 AIService / AppSettings，仅用 OpenClaw 自带的 KeychainStore
/// - @MainActor（与 OpenClaw 其余 UI 客户端一致）；纯常量用 nonisolated 声明以便设置页读取
@MainActor
final class DeepSeekDirectClient {
    /// 单例。
    static let shared = DeepSeekDirectClient()

    /// DeepSeek Key 在 Keychain 中的账号键名。
    nonisolated static let apiKeyAccount = "deepseek_api_key"
    /// DeepSeek Key 在 Keychain 中的 service（与 OpenClaw Talk 凭据共用 service）。
    nonisolated static let keychainService = "ai.openclawfoundation.app.talk"
    /// 设置页「DeepSeek 直连」开关的 UserDefaults 键。
    nonisolated static let enabledDefaultsKey = "talk.deepseek.enabled"
    /// 端点（官方 OpenAI 兼容端点；代理/自建可覆盖，仅供调试覆盖）。
    nonisolated(unsafe) static var endpoint = "https://api.deepseek.com/v1/chat/completions"
    /// 单次请求超时（秒）。
    nonisolated(unsafe) static var timeout: TimeInterval = 60
    /// 默认模型。
    nonisolated static let defaultModel = "deepseek-chat"
    /// 默认直连语气：诚实原则，不给语音通道编造记忆。
    nonisolated static let defaultSystemPrompt =
        "你是 OpenClaw 的语音助手。请用自然的中文回答，简洁口语化；信息不足时直接说明，不要编造。"

    enum DeepSeekError: LocalizedError {
        case disabled
        case missingAPIKey
        case badResponse(Int, String)
        case emptyReply
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .disabled:
                return "未开启 DeepSeek 直连：请到 设置 → 语音 打开「DeepSeek 直连」开关。"
            case .missingAPIKey:
                return "未配置 DeepSeek API Key：请到 设置 → 语音 的「DeepSeek 直连」里填写。"
            case let .badResponse(code, body):
                return "DeepSeek 请求失败（\(code)）：\(Self.friendlyHTTPText(code: code, body: body))"
            case .emptyReply:
                return "DeepSeek 没有返回内容，请重试或换个说法。"
            case .invalidResponse:
                return "DeepSeek 返回了无法解析的响应。"
            }
        }

        private static func friendlyHTTPText(code: Int, body: String) -> String {
            switch code {
            case 401: return "API Key 无效或已过期"
            case 402: return "账户余额不足"
            case 429: return "请求过于频繁，请稍后重试"
            case 500, 502, 503: return "DeepSeek 服务暂时不可用"
            default: return String(body.prefix(120))
            }
        }
    }

    private init() {}

    /// 直连开关是否打开（设置页开关，UserDefaults `talk.deepseek.enabled`）。
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
    }

    /// 当前 Key（nil = 未配置）。
    var apiKey: String? {
        KeychainStore.loadString(service: Self.keychainService, account: Self.apiKeyAccount)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 是否可用：开关打开且已配置 Key。
    var isConfigured: Bool {
        isEnabled && !(apiKey?.isEmpty ?? true)
    }

    /// 一次性调用：返回完整回复文本（内部走流式累积，失败抛 DeepSeekError）。
    func complete(
        messages: [DeepSeekChatMessage],
        system: String? = nil,
        model: String = Self.defaultModel
    ) async throws -> String {
        var all = ""
        for try await delta in stream(messages: messages, system: system, model: model) {
            all += delta
        }
        let trimmed = all.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DeepSeekError.emptyReply }
        return trimmed
    }

    /// 流式调用：逐段吐出回复文本（SSE 逐行解析，整行解码避免多字节中文被截断）。
    func stream(
        messages: [DeepSeekChatMessage],
        system: String? = nil,
        model: String = Self.defaultModel
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard isEnabled else { throw DeepSeekError.disabled }
                    guard let key = apiKey, !key.isEmpty else {
                        throw DeepSeekError.missingAPIKey
                    }

                    var chatMessages: [[String: String]] = []
                    if let system, !system.isEmpty {
                        chatMessages.append(["role": "system", "content": system])
                    }
                    chatMessages += messages.map { ["role": $0.role, "content": $0.content] }

                    let payload: [String: Any] = [
                        "model": model,
                        "messages": chatMessages,
                        "stream": true,
                    ]
                    guard let url = URL(string: Self.endpoint) else {
                        throw DeepSeekError.invalidResponse
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = Self.timeout
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        var body = ""
                        for try await byte in bytes {
                            body.append(String(decoding: [byte], as: UTF8.self))
                            if body.count > 300 { break }
                        }
                        throw DeepSeekError.badResponse(http.statusCode, body)
                    }

                    // 逐字节缓冲，按换行切 SSE 行（整行解码，避免多字节中文被截断）。
                    var rawBuffer = Data()
                    for try await byte in bytes {
                        rawBuffer.append(byte)
                        while let nl = rawBuffer.firstIndex(of: 0x0A) {
                            let lineData = rawBuffer.subdata(in: rawBuffer.startIndex..<nl)
                            rawBuffer.removeSubrange(rawBuffer.startIndex...nl)
                            let line = String(decoding: lineData, as: UTF8.self)
                                .trimmingCharacters(in: .whitespaces)
                            guard line.hasPrefix("data:") else { continue }
                            let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            guard !data.isEmpty, data != "[DONE]" else { continue }
                            guard let object = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any],
                                  let choices = object["choices"] as? [[String: Any]],
                                  let delta = choices.first?["delta"] as? [String: Any],
                                  let content = delta["content"] as? String,
                                  !content.isEmpty else { continue }
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
