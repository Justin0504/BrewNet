import Foundation
import SwiftUI

// MARK: - Gemini AI Service
class GeminiAIService: ObservableObject {
    static let shared = GeminiAIService()
    
    // Note: In a real application, you need to get the API key from a secure place
    private let apiKey = "YOUR_GEMINI_API_KEY" // Replace with your actual API key
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
    
    private init() {}
    
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
        // 模拟AI响应（在实际应用中，这里会调用Gemini API）
        return await simulateAIResponse(prompt: prompt, category: category)
    }
    
    private func simulateAIResponse(prompt: String, category: SuggestionCategory) async -> [AISuggestion] {
        // 模拟网络延迟
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 根据类别返回模拟的AI建议
        let suggestions: [String]
        
        switch category {
        case .iceBreaker:
            suggestions = [
                "我注意到你也喜欢\(["咖啡", "旅行", "音乐", "摄影"].randomElement() ?? "技术")！能分享一下你的经历吗？",
                "作为\(["产品经理", "设计师", "工程师"].randomElement() ?? "专业人士")，你觉得最有挑战性的是什么？",
                "最近有什么新的\(["技术", "设计", "音乐", "旅行"].randomElement() ?? "项目")让你兴奋吗？",
                "如果你可以学习任何新技能，你会选择什么？",
                "周末你通常喜欢做什么来放松？"
            ]
        case .followUp:
            suggestions = [
                "这听起来很有趣！能详细说说吗？",
                "你是怎么开始对这个领域感兴趣的？",
                "在这个过程中，你学到了什么？",
                "你觉得最重要的是什么？",
                "有什么建议可以分享吗？"
            ]
        case .compliment:
            suggestions = [
                "你的\(["工作", "想法", "经历"].randomElement() ?? "分享")真的很棒！",
                "我很欣赏你的\(["专业", "创意", "热情"].randomElement() ?? "态度")！",
                "你提到的\(["观点", "经验", "想法"].randomElement() ?? "内容")很有启发性！",
                "你的\(["职业", "兴趣", "经历"].randomElement() ?? "背景")很令人印象深刻！",
                "我很喜欢你的\(["分享", "观点", "经历"].randomElement() ?? "内容")！"
            ]
        case .sharedInterest:
            suggestions = [
                "我也很喜欢\(["咖啡", "旅行", "音乐", "摄影"].randomElement() ?? "这个话题")！",
                "我们有很多共同兴趣呢！",
                "这个话题我也很感兴趣！",
                "我们在这方面有很多可以聊的！",
                "很高兴找到有共同爱好的人！"
            ]
        case .question:
            suggestions = [
                "你平时是怎么保持工作与生活的平衡的？",
                "在你的领域，你觉得最重要的技能是什么？",
                "有什么书籍或资源可以推荐吗？",
                "你遇到过最有挑战性的项目是什么？",
                "对于新手，你有什么建议？"
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
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            return text
        }
        
        throw AIError.invalidResponse
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
