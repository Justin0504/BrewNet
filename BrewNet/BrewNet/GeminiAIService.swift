import Foundation
import SwiftUI

// MARK: - Gemini AI Service
class GeminiAIService: ObservableObject {
    static let shared = GeminiAIService()
    
    // MARK: - 配置选项
    /// 是否使用 Supabase Edge Function（推荐用于生产环境）
    /// 设置为 true 时，API Key 将存储在后端，更安全
    /// 设置为 false 时，使用客户端 API Key（仅用于开发测试）
    /// 
    /// ⚠️ 注意：如果 Edge Function 未部署，会回退到模拟模式
    /// 部署函数后，将这里改为 true
    private let useSupabaseEdgeFunction = true // 临时改为 false，等函数部署后改为 true
    
    // Note: In a real application, you need to get the API key from a secure place
    private var apiKey: String {
        // 只从 Info.plist 读取（不从环境变量读取）
        // 首先尝试从 Info.plist 读取
        if let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String, !key.isEmpty, key != "YOUR_GEMINI_API_KEY" {
            return key
        }
        // 尝试从 Info.plist 的根字典读取（备用方法）
        if let infoDict = Bundle.main.infoDictionary,
           let key = infoDict["GEMINI_API_KEY"] as? String, !key.isEmpty, key != "YOUR_GEMINI_API_KEY" {
            return key
        }
        // 返回占位符（如果没有配置，将使用模拟模式）
        return "YOUR_GEMINI_API_KEY"
    }
    
    // 使用 Gemini 2.0 Flash 模型（稳定版）
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    private let useRealAPI: Bool // 是否使用真实 API
    
    // Supabase Edge Function URL（计算属性，在所有存储属性初始化后使用）
    private var edgeFunctionURL: String {
        let supabaseURL = SupabaseConfig.shared.url
        return "\(supabaseURL)/functions/v1/gemini-ai"
    }
    
    private init() {
        // 先初始化所有存储属性
        if useSupabaseEdgeFunction {
            // 使用 Supabase Edge Function（推荐用于生产环境）
            self.useRealAPI = true // Edge Function 总是可用的
        } else {
            // 使用客户端 API Key（仅用于开发测试）
            let plistKey1 = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
            let plistKey2 = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String
            
            // 检查是否有任何有效的 Key（只检查 Info.plist）
            let hasValidKey = (plistKey1 != nil && !plistKey1!.isEmpty && plistKey1 != "YOUR_GEMINI_API_KEY") ||
                             (plistKey2 != nil && !plistKey2!.isEmpty && plistKey2 != "YOUR_GEMINI_API_KEY")
            
            self.useRealAPI = hasValidKey
        }
        
        // 在所有存储属性初始化后，打印日志
        if useSupabaseEdgeFunction {
            // 使用 Supabase Edge Function（推荐用于生产环境）
            print("✅ 使用 Supabase Edge Function 模式（API Key 存储在后端）")
            print("🌐 Edge Function URL: \(edgeFunctionURL)")
        } else {
            // 使用客户端 API Key（仅用于开发测试）
            let plistKey1 = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
            let plistKey2 = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String
            
            print("⚠️ 使用客户端 API Key 模式（仅用于开发测试）")
            print("🔍 API Key 检查（仅从 Info.plist 读取）:")
            print("   - Info.plist (object): \(plistKey1 != nil ? "存在 (长度: \(plistKey1!.count), 值: \(plistKey1!.prefix(10))...)" : "不存在")")
            print("   - Info.plist (infoDictionary): \(plistKey2 != nil ? "存在 (长度: \(plistKey2!.count), 值: \(plistKey2!.prefix(10))...)" : "不存在")")
            
            // 获取实际使用的 API Key
            let actualKey = self.apiKey
            
            if useRealAPI && actualKey != "YOUR_GEMINI_API_KEY" {
                print("✅ Gemini API Key 已配置，将使用真实 AI 响应")
                print("🔑 使用的 API Key: \(actualKey.prefix(15))... (长度: \(actualKey.count))")
            } else {
                print("⚠️ Gemini API Key 未配置或无效，将使用模拟响应")
                print("   - useRealAPI: \(useRealAPI)")
                print("   - actualKey: \(actualKey == "YOUR_GEMINI_API_KEY" ? "占位符" : "\(actualKey.prefix(15))...")")
            }
        }
    }
    
    // MARK: - Generate Ice Breaker Topics
    func generateIceBreakerTopics(for user: ChatUser, context: String = "") async -> [AISuggestion] {
        // 🧠 AI 升级(2026-08):有 userId 时拉双方真实档案做 grounding,
        // 破冰话题引用对方的公司/技能/学校与双方共同点,而非泛泛而谈
        if let grounded = await buildGroundedProfileBlock(for: user) {
            let prompt = createGroundedIceBreakerPrompt(for: user, groundedBlock: grounded, context: context)
            return await generateSuggestions(prompt: prompt, category: .iceBreaker)
        }
        let prompt = createIceBreakerPrompt(for: user, context: context)
        return await generateSuggestions(prompt: prompt, category: .iceBreaker)
    }

    // MARK: - Profile Grounding(破冰质量的关键)

    /// 从本地登录态读当前用户 id(AuthManager 存于 UserDefaults)
    private func storedCurrentUserId() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "current_user"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else { return nil }
        return id
    }

    /// 拉取对方(必要)与自己(尽力)的完整档案,产出 grounded 事实块;失败返回 nil 走旧 prompt
    private func buildGroundedProfileBlock(for user: ChatUser) async -> String? {
        guard let targetId = user.userId else { return nil }
        guard let targetSupabase = try? await SupabaseService.shared.getProfile(userId: targetId) else { return nil }
        let target = targetSupabase.toBrewNetProfile()

        var lines: [String] = []
        let pb = target.professionalBackground
        var who: [String] = []
        if let t = pb.jobTitle, !t.isEmpty { who.append(t) }
        if let c = pb.currentCompany, !c.isEmpty { who.append("at \(c)") }
        if !who.isEmpty { lines.append("They are: \(who.joined(separator: " "))") }
        if let i = pb.industry, !i.isEmpty { lines.append("Industry: \(i)") }
        if !pb.skills.isEmpty { lines.append("Skills: \(pb.skills.prefix(6).joined(separator: ", "))") }
        if let edus = pb.educations, let first = edus.first {
            lines.append("Education: \(first.schoolName)")
        } else if let edu = pb.education, !edu.isEmpty {
            lines.append("Education: \(edu)")
        }
        lines.append("They joined BrewNet to: \(target.networkingIntention.selectedIntention.rawValue)")
        if let bio = target.coreIdentity.bio, !bio.isEmpty { lines.append("Bio: \(String(bio.prefix(140)))") }

        // 双方共同点(最好的破冰素材)
        if let myId = storedCurrentUserId(),
           let mySupabase = try? await SupabaseService.shared.getProfile(userId: myId) {
            let me = mySupabase.toBrewNetProfile()
            var common: [String] = []
            if let myLoc = me.coreIdentity.location?.lowercased(), let theirLoc = target.coreIdentity.location?.lowercased(),
               !myLoc.isEmpty, !theirLoc.isEmpty, (myLoc.contains(theirLoc) || theirLoc.contains(myLoc)) {
                common.append("same city (\(target.coreIdentity.location!))")
            }
            let mySchools = Set((me.professionalBackground.educations ?? []).map { $0.schoolName.lowercased() })
            let theirSchools = Set((target.professionalBackground.educations ?? []).map { $0.schoolName.lowercased() })
            if let shared = mySchools.intersection(theirSchools).first {
                common.append("same school (\(shared.capitalized))")
            }
            let sharedSkills = Set(me.professionalBackground.skills.map { $0.lowercased() })
                .intersection(Set(target.professionalBackground.skills.map { $0.lowercased() }))
            if !sharedSkills.isEmpty {
                common.append("shared skills: \(sharedSkills.prefix(3).joined(separator: ", "))")
            }
            if !common.isEmpty { lines.append("WHAT YOU TWO HAVE IN COMMON: \(common.joined(separator: "; "))") }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func createGroundedIceBreakerPrompt(for user: ChatUser, groundedBlock: String, context: String) -> String {
        return """
        You are the networking assistant inside BrewNet. Generate 5 ice breaker messages to send to \(user.name). \
        The facts below are the ONLY ground truth — reference them specifically, never invent details.

        ABOUT \(user.name.uppercased()):
        \(groundedBlock)

        Context: \(context.isEmpty ? "First message after matching for a coffee chat" : context)

        Requirements:
        1. Each ice breaker must reference at least one SPECIFIC fact above (their company, a skill, their school, their goal, or a shared point).
        2. Anything listed under "WHAT YOU TWO HAVE IN COMMON" is gold — use it in at least 2 of the 5.
        3. Friendly, curious, professional; 15-40 words each; natural English; no emojis.
        4. Return exactly 5 lines, one ice breaker per line, no numbering or extra formatting.
        """
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
    
    // MARK: - Analyze Conversation and Generate Smart Suggestions
    /// 分析聊天内容并生成智能提示语
    /// - Parameters:
    ///   - user: 聊天对象
    ///   - messages: 聊天消息列表
    ///   - userInterests: 当前用户的兴趣列表（可选）
    /// - Returns: 基于聊天内容分析生成的提示语列表
    func analyzeConversationAndSuggest(
        for user: ChatUser,
        messages: [ChatMessage],
        userInterests: [String] = []
    ) async -> [AISuggestion] {
        let prompt = createConversationAnalysisPrompt(for: user, messages: messages, userInterests: userInterests)
        return await generateSuggestions(prompt: prompt, category: .followUp)
    }
    
    // MARK: - Generate General Questions
    func generateQuestions(for user: ChatUser) async -> [AISuggestion] {
        let prompt = createQuestionPrompt(for: user)
        return await generateSuggestions(prompt: prompt, category: .question)
    }
    
    // MARK: - Private Methods
    private func createIceBreakerPrompt(for user: ChatUser, context: String) -> String {
        return """
        As a professional AI networking assistant, generate 5 natural, engaging, and non-awkward ice breaker questions or comments for the following user in a professional networking context.

        User Information:

        - Name: \(user.name)

        - Profession: \(user.bio)

        - Interests: \(user.interests.joined(separator: ", "))

        Context: \(context.isEmpty ? "First time chatting" : context)

        Requirements:

        1. Focus on light professional conversation — topics like career paths, work culture, industry trends, recent projects, or professional growth.

        2. Avoid overly personal, casual, or sensitive topics (e.g., family, lifestyle, politics).

        3. Combine the user's profession and interests when relevant.

        4. Keep the tone friendly, curious, and conversational — like a relaxed chat at a networking event or LinkedIn message.

        5. Each ice breaker should be 1–2 short sentences (15–40 words), in natural English.

        6. Return exactly 5 topics directly, one per line, without numbering or additional formatting.

        Goal: Help two professionals start a comfortable, authentic conversation that feels relevant to their careers.
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
    
    private func createConversationAnalysisPrompt(for user: ChatUser, messages: [ChatMessage], userInterests: [String]) -> String {
        // 构建完整的聊天历史记录
        let conversationHistory = messages.map { message in
            let sender = message.isFromUser ? "Me" : user.name
            return "\(sender): \(message.content)"
        }.joined(separator: "\n")
        
        // 获取最近的对话作为上下文（最多20条，确保有足够上下文）
        let recentMessages = messages.suffix(20)
        let recentConversation = recentMessages.map { message in
            let sender = message.isFromUser ? "Me" : user.name
            return "\(sender): \(message.content)"
        }.joined(separator: "\n")
        
        // 分析对方最后的消息，确定上下文
        let otherUserMessages = messages.filter { !$0.isFromUser }
        let lastOtherMessage = otherUserMessages.last?.content ?? ""
        let conversationContext = otherUserMessages.suffix(3).map { $0.content }.joined(separator: " | ")
        
        return """
        You are an AI networking assistant helping professionals maintain engaging, career-focused conversations. 
        Analyze the conversation below and generate exactly 10 diverse and contextually relevant replies that move the dialogue forward naturally.
        
        User Information:
        
        - Name: \(user.name)
        
        - Profession: \(user.bio)
        
        - Interests: \(user.interests.joined(separator: ", "))
        
        My Interests: \(userInterests.joined(separator: ", "))
        
        Full Conversation History:
        
        \(conversationHistory.isEmpty ? "No previous messages" : conversationHistory)
        
        Recent Context (Last 3 messages from \(user.name)):
        
        \(conversationContext.isEmpty ? "No recent context" : conversationContext)
        
        Last Message from \(user.name): \(lastOtherMessage)
        
        CRITICAL REQUIREMENTS:
        
        1. Focus strictly on what the other person said — every reply must directly respond or build upon their comments or questions.  
        2. Maintain a friendly yet professional tone — suitable for workplace or networking chat (like a LinkedIn message).  
        3. Generate exactly 10 replies covering these balanced styles:
           - 2 insightful (share perspectives or add value)
           - 2 curious (ask thoughtful follow-ups)
           - 2 supportive (encouraging, validating, appreciative)
           - 2 engaging (light and conversational, build rapport)
           - 1 professional (structured, clear, career-focused)
           - 1 reflective (thoughtful and empathetic)
        4. Each reply should:
           - Fit naturally in ongoing conversation flow
           - Be specific and grounded in context (not generic)
           - Invite further discussion when appropriate
           - Sound human and conversational (15–60 words)
        5. Output format:
           Return exactly 10 lines, each line formatted as: [STYLE]: [REPLY TEXT]
           Example:
           curious: That's really interesting — what inspired you to take that approach?
           insightful: It’s fascinating how that trend reflects broader shifts in the industry.
           supportive: Sounds like you handled that challenge really well. How did it turn out in the end?
        
        Goal: Help maintain a professional, natural, and engaging conversation that strengthens networking connections.
        """
    }
    
    private func generateSuggestions(prompt: String, category: SuggestionCategory) async -> [AISuggestion] {
        // 如果使用 Supabase Edge Function
        if useSupabaseEdgeFunction {
            do {
                let response = try await callSupabaseEdgeFunction(prompt: prompt, category: category)
                return parseAIResponse(response: response, category: category)
            } catch {
                print("⚠️ Supabase Edge Function 调用失败: \(error.localizedDescription)")
                print("⚠️ 回退到模拟模式")
                return await simulateAIResponse(prompt: prompt, category: category)
            }
        }
        // 如果使用客户端 API Key（仅用于开发测试）
        else if useRealAPI && apiKey != "YOUR_GEMINI_API_KEY" {
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
            // 返回10条不同风格的回复（模拟）
            suggestions = [
                "humorous: That's hilarious! I can totally picture that happening 😄",
                "serious: Based on what you've shared, I think we should consider the long-term implications.",
                "caring: I can understand how challenging that must have been. How are you doing now?",
                "professional: From a strategic perspective, this approach makes a lot of sense.",
                "friendly: That sounds really cool! I'd love to hear more about your experience.",
                "curious: That's fascinating! What made you decide to pursue that direction?",
                "supportive: You're doing great! Keep pushing forward with your goals.",
                "playful: Sounds like quite the adventure! What's the wildest part of it?",
                "thoughtful: This makes me think about how we approach similar challenges in my field.",
                "warm: I really appreciate you sharing that with me. It means a lot."
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
        
        // 对于 followUp 类别，需要解析带风格的回复
        if category == .followUp {
            return parseAIResponse(response: suggestions.joined(separator: "\n"), category: category)
        } else {
            return suggestions.map { content in
                AISuggestion(content: content, category: category)
            }
        }
    }
    
    // MARK: - Supabase Edge Function Call (推荐用于生产环境)
    private func callSupabaseEdgeFunction(prompt: String, category: SuggestionCategory) async throws -> String {
        guard let url = URL(string: edgeFunctionURL) else {
            print("❌ 无法构建 Edge Function URL")
            throw AIError.invalidURL
        }
        
        // 获取 Supabase 认证 token
        let supabaseClient = SupabaseConfig.shared.client
        let session = try? await supabaseClient.auth.session
        guard let accessToken = session?.accessToken else {
            print("❌ 未找到 Supabase 认证 token")
            throw AIError.networkError
        }
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "category": category.rawValue,
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
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.shared.key, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🚀 调用 Supabase Edge Function: \(edgeFunctionURL)")
        print("🔑 使用认证 token: \(accessToken.prefix(20))...")
        print("🔑 使用 API Key: \(SupabaseConfig.shared.key.prefix(20))...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查响应状态
        if let httpResponse = response as? HTTPURLResponse {
            print("🔍 Edge Function 响应状态码: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 404 {
                print("❌ 函数未找到！请检查：")
                print("   1. 函数名称是否正确：'gemini-ai'（小写，带连字符）")
                print("   2. 函数是否已成功部署到 Supabase Dashboard")
                print("   3. 项目 ID 是否正确：jcxvdolcdifdghaibspy")
                print("   4. 函数 URL: \(edgeFunctionURL)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Edge Function 错误详情: \(errorString)")
                }
                throw AIError.networkError
            } else if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Edge Function 错误: \(errorString)")
                }
                throw AIError.networkError
            }
        }
        
        // 解析响应
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            print("✅ Edge Function 成功返回: \(text.prefix(100))...")
            return text
        }
        
        throw AIError.invalidResponse
    }
    
    // MARK: - Real API Call (需要配置API密钥，仅用于开发测试)
    private func callGeminiAPI(prompt: String) async throws -> String {
        // 确保 API Key 被正确 URL 编码
        let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
        
        // 检查 API Key 有效性
        if apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY" {
            print("❌ API Key 无效或未配置")
            throw AIError.networkError
        }
        
        guard let url = URL(string: "\(baseURL)?key=\(encodedKey)") else {
            print("❌ 无法构建 URL，baseURL: \(baseURL)")
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
        
        // 解析带风格的回复（格式: [STYLE]: [REPLY TEXT]）
        var suggestions: [AISuggestion] = []
        
        for line in lines {
            // 尝试解析格式: [STYLE]: [CONTENT]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 匹配格式: style: content 或 [style]: content
            if let colonRange = trimmedLine.range(of: ":") {
                let stylePart = String(trimmedLine[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
                var contentPart = String(trimmedLine[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                
                // 移除可能的方括号
                let style = stylePart.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                
                // 移除内容中的编号、列表符号等
                if let match = contentPart.range(of: #"^[\d+\-\*\•]+\s*"#, options: .regularExpression) {
                    contentPart.removeSubrange(match)
                    contentPart = contentPart.trimmingCharacters(in: .whitespaces)
                }
                
                // 移除双引号（开头和结尾）
                contentPart = contentPart.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                
                // 尝试匹配风格
                if let suggestionStyle = SuggestionStyle(rawValue: style), !contentPart.isEmpty {
                    suggestions.append(AISuggestion(
                        content: contentPart,
                        category: category,
                        style: suggestionStyle
                    ))
                    continue
                }
            }
            
            // 如果没有风格标签，尝试移除编号和列表符号后作为普通建议
            var cleaned = trimmedLine
            if let match = cleaned.range(of: #"^[\d+\-\*\•]+\s*"#, options: .regularExpression) {
                cleaned.removeSubrange(match)
                cleaned = cleaned.trimmingCharacters(in: .whitespaces)
            }
            
            // 移除双引号（开头和结尾）
            cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            
            // 如果清理后的内容不为空，添加为无风格的建议
            if !cleaned.isEmpty {
                suggestions.append(AISuggestion(content: cleaned, category: category))
            }
        }
        
        // 对于对话分析，应该返回最多10条建议
        let maxSuggestions = category == .followUp ? 10 : 5
        let finalSuggestions = Array(suggestions.prefix(maxSuggestions))
        
        print("✅ 成功解析 \(finalSuggestions.count) 条建议（带风格: \(finalSuggestions.filter { $0.style != nil }.count)）")
        
        // 如果没有有效建议，回退到模拟模式
        if finalSuggestions.isEmpty {
            print("⚠️ AI 响应解析失败，使用默认建议")
            return category.defaultSuggestions
        }
        
        return finalSuggestions
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
