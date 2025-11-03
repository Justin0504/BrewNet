import Foundation
import SwiftUI

// MARK: - Gemini AI Service
class GeminiAIService: ObservableObject {
    static let shared = GeminiAIService()
    
    // Note: In a real application, you need to get the API key from a secure place
    private var apiKey: String {
        // 首先尝试从环境变量读取
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            return key
        }
        // 其次尝试从 Info.plist 读取
        if let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String {
            return key
        }
        // 返回占位符（如果没有配置，将使用模拟模式）
        return "YOUR_GEMINI_API_KEY"
    }
    // 使用 Gemini 2.0 Flash 模型（稳定版）
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    private let useRealAPI: Bool // 是否使用真实 API
    
    private init() {
        // 检查是否有有效的 API Key
        self.useRealAPI = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] != nil || 
                         (Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String) != nil
        
        if useRealAPI {
            print("✅ Gemini API Key 已配置，将使用真实 AI 响应")
        } else {
            print("ℹ️ Gemini API Key 未配置，将使用模拟响应")
        }
    }
    
    // MARK: - Generate Ice Breaker Topics
    func generateIceBreakerTopics(for user: ChatUser, context: String = "") async -> [AISuggestion] {
        let prompt = createIceBreakerPrompt(for: user, context: context)
        return await generateSuggestions(prompt: prompt, category: .iceBreaker)
    }
    
    // MARK: - Generate Follow-up Questions
    func generateFollowUpQuestions(for user: ChatUser, lastMessage: String) async -> [AISuggestion] {
        let prompt = createFollowUpPrompt(for: user, lastMessage: lastMessage)
        return await generateSuggestions(prompt: prompt, category: .followUp)
    }
    
    // MARK: - Generate Compliments
    func generateCompliments(for user: ChatUser) async -> [AISuggestion] {
        let prompt = createComplimentPrompt(for: user)
        return await generateSuggestions(prompt: prompt, category: .compliment)
    }
    
    // MARK: - Generate Shared Interest Topics
    func generateSharedInterestTopics(for user: ChatUser, userInterests: [String]) async -> [AISuggestion] {
        let prompt = createSharedInterestPrompt(for: user, userInterests: userInterests)
        return await generateSuggestions(prompt: prompt, category: .sharedInterest)
    }
    
    // MARK: - Generate General Questions
    func generateQuestions(for user: ChatUser) async -> [AISuggestion] {
        let prompt = createQuestionPrompt(for: user)
        return await generateSuggestions(prompt: prompt, category: .question)
    }
    
    // MARK: - Private Methods
    private func createIceBreakerPrompt(for user: ChatUser, context: String) -> String {
        return """
        As a professional AI ice breaker assistant, please generate 5 interesting, natural, and non-awkward ice breaker topics for the following user.
        
        User Information:
        - Name: \(user.name)
        - Profession: \(user.bio)
        - Interests: \(user.interests.joined(separator: ", "))
        
        Context: \(context.isEmpty ? "First time chatting" : context)
        
        Requirements:
        1. Topics should be natural, interesting, and easy to respond to
        2. Avoid overly personal or sensitive topics
        3. Can combine user's profession and interests
        4. Language should be friendly and relaxed
        5. Each topic should be expressed in English, 20-50 words long
        
        Please return 5 topics directly, one per line, without numbering or other formatting.
        """
    }
    
    private func createFollowUpPrompt(for user: ChatUser, lastMessage: String) -> String {
        return """
        Based on the following conversation content, generate 3 natural follow-up questions to continue chatting:
        
        User Information:
        - Name: \(user.name)
        - Profession: \(user.bio)
        - Interests: \(user.interests.joined(separator: ", "))
        
        Last message: \(lastMessage)
        
        Requirements:
        1. Questions should be natural and relevant
        2. Show genuine interest in the other person's topic
        3. Can delve deeper or transition to related topics
        4. Language should be friendly and curious
        5. Each question should be expressed in English, 15-40 words long
        
        Please return 3 questions directly, one per line.
        """
    }
    
    private func createComplimentPrompt(for user: ChatUser) -> String {
        return """
        Generate 3 sincere and specific compliment topics for the following user:
        
        User Information:
        - Name: \(user.name)
        - Profession: \(user.bio)
        - Interests: \(user.interests.joined(separator: ", "))
        
        Requirements:
        1. Compliments should be sincere and specific, not generic
        2. Can praise professional achievements, hobbies, or personal traits
        3. Avoid being overly exaggerated or fake
        4. Language should be natural and friendly
        5. Each compliment should be expressed in English, 20-50 words long
        
        Please return 3 compliment topics directly, one per line.
        """
    }
    
    private func createSharedInterestPrompt(for user: ChatUser, userInterests: [String]) -> String {
        return """
        Based on both parties' interests and hobbies, generate 4 common topics:
        
        Other Party Information:
        - Name: \(user.name)
        - Interests: \(user.interests.joined(separator: ", "))
        
        My Interests: \(userInterests.joined(separator: ", "))
        
        Requirements:
        1. Find topics that both parties are interested in
        2. Topics should be specific and discussable
        3. Can share experiences, opinions, or advice
        4. Language should be natural and friendly
        5. Each topic should be expressed in English, 20-50 words long
        
        Please return 4 common topics directly, one per line.
        """
    }
    
    private func createQuestionPrompt(for user: ChatUser) -> String {
        return """
        为以下用户生成5个有趣、开放性的问题：
        
        用户信息：
        - 姓名：\(user.name)
        - 职业：\(user.bio)
        - 兴趣：\(user.interests.joined(separator: ", "))
        
        要求：
        1. 问题要有趣、有深度
        2. 可以涉及职业、兴趣、生活经历等
        3. 避免过于私人或敏感的问题
        4. 问题要容易回答，不会让人尴尬
        5. 每个问题用中文表达，长度在15-40字之间
        
        请直接返回5个问题，每行一个。
        """
    }
    
    private func generateSuggestions(prompt: String, category: SuggestionCategory) async -> [AISuggestion] {
        // 如果配置了真实的 API Key，使用真实 API；否则使用模拟响应
        if useRealAPI && apiKey != "YOUR_GEMINI_API_KEY" {
            do {
                let response = try await callGeminiAPI(prompt: prompt)
                return parseAIResponse(response: response, category: category)
            } catch {
                print("⚠️ Gemini API 调用失败: \(error.localizedDescription)")
                print("⚠️ 回退到模拟模式")
                return await simulateAIResponse(prompt: prompt, category: category)
            }
        } else {
            print("ℹ️ 使用模拟 AI 响应（未配置 API Key）")
            return await simulateAIResponse(prompt: prompt, category: category)
        }
    }
    
    private func simulateAIResponse(prompt: String, category: SuggestionCategory) async -> [AISuggestion] {
        // 模拟网络延迟
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 根据类别返回模拟的AI建议
        let suggestions: [String]
        
        switch category {
        case .iceBreaker:
            suggestions = [
                "I noticed you also like \(["coffee", "travel", "music", "photography"].randomElement() ?? "tech")! Would you like to share your experience?",
                "As a \(["product manager", "designer", "engineer"].randomElement() ?? "professional"), what do you think is most challenging?",
                "Have any new \(["tech", "design", "music", "travel"].randomElement() ?? "projects") excited you recently?",
                "If you could learn any new skill, what would you choose?",
                "What do you usually like to do on weekends to relax?"
            ]
        case .followUp:
            suggestions = [
                "That sounds interesting! Could you elaborate?",
                "How did you become interested in this field?",
                "What did you learn from this process?",
                "What do you think is most important?",
                "Any advice you'd like to share?"
            ]
        case .compliment:
            suggestions = [
                "Your \(["work", "ideas", "experience"].randomElement() ?? "sharing") is really great!",
                "I really appreciate your \(["professionalism", "creativity", "passion"].randomElement() ?? "attitude")!",
                "The \(["perspective", "experience", "ideas"].randomElement() ?? "content") you mentioned is very inspiring!",
                "Your \(["career", "interests", "background"].randomElement() ?? "background") is very impressive!",
                "I really like your \(["sharing", "perspective", "experience"].randomElement() ?? "content")!"
            ]
        case .sharedInterest:
            suggestions = [
                "I also really like \(["coffee", "travel", "music", "photography"].randomElement() ?? "this topic")!",
                "We have many common interests!",
                "I'm very interested in this topic too!",
                "We have a lot to talk about in this area!",
                "Great to find someone with common hobbies!"
            ]
        case .question:
            suggestions = [
                "How do you usually maintain work-life balance?",
                "In your field, what skills do you think are most important?",
                "Any books or resources you'd recommend?",
                "What's the most challenging project you've worked on?",
                "Any advice for beginners?"
            ]
        }
        
        return suggestions.map { content in
            AISuggestion(content: content, category: category)
        }
    }
    
    // MARK: - Real API Call (需要配置API密钥)
    private func callGeminiAPI(prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw AIError.invalidURL
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 1024
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 调试：打印请求 URL（隐藏 API Key）
        let debugURL = url.absoluteString.replacingOccurrences(of: "key=\(apiKey)", with: "key=***")
        print("🚀 调用 Gemini API: \(debugURL)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 调试：打印原始响应
        if let httpResponse = response as? HTTPURLResponse {
            print("🔍 Gemini API 响应状态码: \(httpResponse.statusCode)")
        }
        
        // 调试：打印响应数据
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 Gemini API 原始响应: \(responseString.prefix(500))...")
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 调试：检查是否有错误
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ Gemini API 错误: \(message)")
                throw AIError.networkError
            }
            
            if let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                print("✅ Gemini API 成功返回: \(text.prefix(100))...")
                return text
            }
        }
        
        throw AIError.invalidResponse
    }
    
    // MARK: - Parse AI Response
    
    /// 解析 Gemini API 返回的文本，提取建议内容
    private func parseAIResponse(response: String, category: SuggestionCategory) -> [AISuggestion] {
        // 首先尝试按双换行符分割（Gemini 常用格式）
        var lines = response.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // 如果双换行分割失败，尝试单换行
        if lines.count <= 1 {
            lines = response.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        
        print("🔍 解析到 \(lines.count) 条建议")
        
        // 过滤掉编号、列表符号等
        let cleanedLines = lines.map { line in
            // 移除常见的编号格式（如 "1. ", "2. ", "- ", "* ", "• " 等）
            var cleaned = line
            if let match = cleaned.range(of: #"^[\d+\-\*\•]+\s*"#, options: .regularExpression) {
                cleaned.removeSubrange(match)
                cleaned = cleaned.trimmingCharacters(in: .whitespaces)
            }
            return cleaned
        }
        .filter { !$0.isEmpty }
        
        // 转换为 AISuggestion 数组
        let suggestions = cleanedLines.prefix(5) // 最多取5条
            .map { content in
                AISuggestion(content: content, category: category)
            }
        
        print("✅ 成功解析 \(suggestions.count) 条建议")
        
        // 如果没有有效建议，回退到模拟模式
        if suggestions.isEmpty {
            print("⚠️ AI 响应解析失败，使用默认建议")
            return category.defaultSuggestions
        }
        
        return Array(suggestions)
    }
}

// MARK: - AI Error
enum AIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response"
        case .networkError:
            return "Network error occurred"
        }
    }
}
