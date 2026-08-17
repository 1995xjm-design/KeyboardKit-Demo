import Foundation

/// 一次知识问答记录（本视图会话内存态，不落盘）。
struct HomeKnowledgeQA: Identifiable, Hashable {
    let id: UUID
    let question: String
    let answer: String
    /// 关联的网关文件路径；通用提问为 nil。
    let sourcePath: String?

    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        sourcePath: String? = nil
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.sourcePath = sourcePath
    }
}

/// 知识问答统一入口：包装 HomeAgentPromptClient（会话基底 key = knowledge）。
@MainActor
enum HomeKnowledgeAskSupport {

    /// 通用提问（不带文件上下文）。
    static func ask(appModel: NodeAppModel, question: String) async throws -> String {
        try await HomeAgentPromptClient.prompt(
            appModel: appModel,
            prompt: question,
            sessionBaseKey: "knowledge")
    }

    /// 基于网关文件内容提问：把文件内容作为上下文发给 Agent。
    /// 内容过长时截断（避免刷爆上下文），截断后如实告知 Agent。
    static func ask(
        appModel: NodeAppModel,
        question: String,
        fileName: String,
        fileContent: String,
        maxContextCharacters: Int = 8000
    ) async throws -> String {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let context: String
        let truncationNote: String
        if fileContent.count > maxContextCharacters {
            context = String(fileContent.prefix(maxContextCharacters))
            truncationNote = "\n（文件内容过长，已截断到前 \(maxContextCharacters) 个字符）"
        } else {
            context = fileContent
            truncationNote = ""
        }
        let prompt = """
        请基于下面这份文件（名称：\(fileName)）的内容回答用户的问题。若内容与问题无关或信息不足，请直接说明。\(truncationNote)

        文件内容：
        ```
        \(context)
        ```

        问题：\(trimmedQuestion)
        """
        return try await HomeAgentPromptClient.prompt(
            appModel: appModel,
            prompt: prompt,
            sessionBaseKey: "knowledge")
    }

    /// 生成文件中文摘要：把文件内容发给 Agent，输出中文摘要。
    /// 内容过长时截断（与带文件上下文提问一致），截断后如实告知 Agent。
    static func summarize(
        appModel: NodeAppModel,
        fileName: String,
        fileContent: String,
        maxContextCharacters: Int = 8000
    ) async throws -> String {
        let context: String
        let truncationNote: String
        if fileContent.count > maxContextCharacters {
            context = String(fileContent.prefix(maxContextCharacters))
            truncationNote = "\n（文件内容过长，已截断到前 \(maxContextCharacters) 个字符）"
        } else {
            context = fileContent
            truncationNote = ""
        }
        let prompt = """
        请阅读下面这份文件（名称：\(fileName)），用中文写一份简洁摘要，概括文件的主要内容和关键信息。\(truncationNote)

        文件内容：
        ```
        \(context)
        ```
        """
        return try await HomeAgentPromptClient.prompt(
            appModel: appModel,
            prompt: prompt,
            sessionBaseKey: "knowledge")
    }

}
