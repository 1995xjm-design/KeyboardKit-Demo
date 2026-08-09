import Foundation

// MARK: - DeepSeek 配置
enum DeepSeekConfig {

    /// API Key：从共享存储读取（App 内配置，键盘共享）
    static var apiKey: String {
        APIKeyStore.shared.readPasteboardFallbackIfNeeded()
        return APIKeyStore.shared.apiKey
    }

    static var baseURL: String { APIKeyStore.shared.baseURL }
    static var model: String { APIKeyStore.shared.model }
    static let timeout: TimeInterval = 60
}

// MARK: - 聊天消息
struct ChatMessage: Codable {
    let role: String
    let content: String

    static func system(_ content: String) -> ChatMessage { ChatMessage(role: "system", content: content) }
    static func user(_ content: String) -> ChatMessage { ChatMessage(role: "user", content: content) }
}

// MARK: - API 服务
class APIService {

    static let shared = APIService()
    private init() {}

    // MARK: - 连接测试

    /// Sends a minimal chat request to verify the configured
    /// API connection. Returns the model's reply on success.
    func testConnection() async throws -> String {
        let reply = try await chat(
            [.system("You are a connectivity test. Reply with exactly: OK"), .user("ping")],
            temperature: 0,
            maxTokens: 8,
            useJSONMode: false
        )
        return reply
    }

    // MARK: - 帮你回 - 生成回复
    func generateHelpReply(
        content: String,
        role: ChatRole,
        count: Int = 5
    ) async throws -> [String] {
        let promptLines = role.prompts.map { "\($0.key)：\($0.value)" }.joined(separator: "\n")
        let system = """
        你是一位擅长写聊天回复的中文助手。请根据人设设定，针对用户发来的聊天内容，生成 \(count) 条自然、得体、有感情的中文回复。
        人设名称：\(role.name)
        人设描述：\(role.description)
        \(promptLines.isEmpty ? "" : "人设要求：\n\(promptLines)")
        要求：只输出一个 JSON 数组，格式如 ["回复1","回复2","回复3"]，不要输出任何其他内容或解释。
        """
        let raw = try await chat([.system(system), .user(content)])
        return Self.parseStringArray(raw)
    }

    func generateHelpReply(
        content: String,
        roleId: String,
        count: Int = 5
    ) async throws -> [String] {
        if let role = PresetRoles.allRoles.first(where: { $0.id == roleId }) {
            return try await generateHelpReply(content: content, role: role, count: count)
        }
        let fallback = ChatRole(
            id: "fallback", name: "贴心助手",
            description: "温柔体贴、善解人意的聊天助手",
            avatarName: "", category: .warm, tags: [],
            useCount: 0, isVip: false, isNew: false, isHot: false,
            roleType: .helpReply, isAddedToKeyboard: true, prompts: [:]
        )
        return try await generateHelpReply(content: content, role: fallback, count: count)
    }

    // MARK: - 超会说 - 生成润色回复
    func generateSuperTalk(
        content: String,
        identity: IdentityType,
        count: Int = 4
    ) async throws -> [PolishResult] {
        let system = """
        你是一位擅长写聊天回复的中文文案高手。请以“\(identity.displayName)”的身份，把用户想表达的意思润色成 \(count) 种不同风格的聊天回复，方便用户直接发送。
        要求：只输出一个 JSON 数组，格式如 [{"style":"撒娇","text":"回复内容"},{"style":"温柔","text":"回复内容"}]，style 用 2-4 个字概括风格，不要输出任何其他内容或解释。
        """
        let raw = try await chat([.system(system), .user(content)])
        return Self.parsePolishResults(raw, count: count)
    }

    /// Builds the chat completions endpoint from the configured
    /// base URL, tolerating trailing slashes and full endpoints.
    private static var chatEndpointURL: URL? {
        var base = DeepSeekConfig.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        let path = base.hasSuffix("/chat/completions") ? base : base + "/chat/completions"
        return URL(string: path)
    }

    // MARK: - DeepSeek 聊天接口
    private func chat(
        _ messages: [ChatMessage],
        temperature: Double = 1.0,
        maxTokens: Int = 1024,
        useJSONMode: Bool = true
    ) async throws -> String {
        let key = DeepSeekConfig.apiKey
        guard !key.isEmpty else { throw APIError.missingAPIKey }

        guard let url = Self.chatEndpointURL else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = DeepSeekConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model": DeepSeekConfig.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        if useJSONMode {
            body["response_format"] = ["type": "json_object"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        guard 200...299 ~= httpResponse.statusCode else {
            let message = Self.parseServerError(data)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        struct ChatCompletionResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        do {
            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                throw APIError.noData
            }
            return content
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingError
        }
    }

    // MARK: - AI 恋爱键盘

    /// Generates quick replies for a pasted conversation with
    /// the given persona and intimacy level.
    func generateReply(
        content: String,
        role: ChatRole,
        intimacy: IntimacyLevel,
        count: Int = 5
    ) async throws -> [String] {
        let promptLines = role.prompts.map { "\($0.key)：\($0.value)" }.joined(separator: "\n")
        let system = """
        你是一位擅长写中文聊天回复的恋爱助手。请根据人设与亲密度，针对用户发来的聊天内容，生成 \(count) 条自然、得体、有感情的中文回复。
        人设名称：\(role.name)
        人设描述：\(role.description)
        亲密度：\(intimacy.rawValue)（\(intimacy.description)）
        \(promptLines.isEmpty ? "" : "人设要求：\n\(promptLines)")
        要求：只输出一个 JSON 数组，格式如 ["回复1","回复2","回复3"]，不要输出任何其他内容或解释。
        """
        let raw = try await chat([.system(system), .user(content)])
        return Self.parseStringArray(raw)
    }

    /// Generates icebreaker openers for a given scene.
    func generateIcebreaker(
        scene: String,
        count: Int = 4
    ) async throws -> [String] {
        let system = """
        你是一位恋爱聊天开场白专家。请针对场景“\(scene)”生成 \(count) 条自然、有趣、不油腻的中文开场白，适合直接发给喜欢的人，帮助破冰。
        要求：只输出一个 JSON 数组，格式如 ["开场白1","开场白2","开场白3"]，不要输出任何其他内容或解释。
        """
        let raw = try await chat([.system(system), .user("场景：\(scene)")])
        return Self.parseStringArray(raw)
    }

    /// Generates love messages / polished sweet replies.
    func generateLoveMessage(
        content: String,
        style: ReplyStyle,
        intimacy: IntimacyLevel,
        count: Int = 4
    ) async throws -> [String] {
        let system = """
        你是一位擅长写中文情话和甜蜜回复的文案高手。请\(style.promptPrefix)，结合亲密度（\(intimacy.rawValue)：\(intimacy.description)），把用户想表达的意思润色成 \(count) 种不同的聊天回复。
        要求：只输出一个 JSON 数组，格式如 ["回复1","回复2","回复3"]，不要输出任何其他内容或解释。
        """
        let raw = try await chat([.system(system), .user(content)])
        return Self.parseStringArray(raw)
    }

    // MARK: - 解析工具

    /// 解析模型返回的字符串数组（兼容 ```json 代码块包裹）
    private static func parseStringArray(_ raw: String) -> [String] {
        let trimmed = stripCodeFence(raw)
        guard let data = trimmed.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    /// 解析模型返回的润色结果数组
    private static func parsePolishResults(_ raw: String, count: Int) -> [PolishResult] {
        struct DTO: Decodable {
            let style: String
            let text: String
        }
        let trimmed = stripCodeFence(raw)
        guard let data = trimmed.data(using: .utf8),
              let items = try? JSONDecoder().decode([DTO].self, from: data) else {
            return []
        }
        return Array(items.prefix(count)).map { PolishResult(styleName: $0.style, text: $0.text) }
    }

    private static func stripCodeFence(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func parseServerError(_ data: Data) -> String? {
        struct ErrorResponse: Decodable {
            struct Err: Decodable { let message: String? }
            let error: Err?
        }
        guard let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data) else { return nil }
        return decoded.error?.message
    }
}

// MARK: - API 错误类型
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError(statusCode: Int, message: String? = nil)
    case decodingError
    case noData
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .networkError:
            return "网络连接失败，请检查网络设置"
        case .serverError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "服务器错误 (\(statusCode))：\(message)"
            }
            return "服务器错误 (\(statusCode))"
        case .decodingError:
            return "数据解析失败"
        case .noData:
            return "没有返回数据"
        case .missingAPIKey:
            return "未配置 DeepSeek API Key"
        }
    }
}