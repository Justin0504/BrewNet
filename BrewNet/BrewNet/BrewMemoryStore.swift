import Foundation

// MARK: - Brew Memory Store(Stage 2)
//
// Brew 的持久记忆:常驻任务(mission)+ 学到的用户偏好 + 行为记录。
// 本地优先(UserDefaults,按 userId 隔离)——零后端迁移即可上线;
// 云同步表见 create_brew_missions.sql(Stage 3 主动推送需要服务端跑 mission 时启用)。

struct BrewMission: Codable {
    var goal: String            // 用户目标原文("senior founder to talk AI startups")
    var createdAt: Date
    var lastRunAt: Date         // 上次替用户跑这个 mission 的时间
    var timesRun: Int
}

struct BrewMemory: Codable {
    var activeMission: BrewMission?
    var preferences: [String] = []       // 学到的偏好/反馈("嫌太 junior","偏好技术型 founder")
    var sentInviteNames: [String] = []   // 已代发邀请的对象(避免重复推)
    var declinedNames: [String] = []     // 用户明确说"不"的对象
    var surveyedNames: [String]? = nil   // 已做过 worth-it 回访的对象(optional:兼容旧数据解码)
    var announcedMatchNames: [String]? = nil  // 已报喜过的接受者(避免重复庆祝)
    var prepOfferedNames: [String]? = nil     // 已提供过见面简报的对象
}

final class BrewMemoryStore {

    static let shared = BrewMemoryStore()
    private init() {}

    private let maxPreferences = 10
    private let maxNames = 30

    private func key(for userId: String) -> String { "brew_memory_\(userId)" }

    // MARK: - Load / Save

    func load(userId: String) -> BrewMemory {
        guard let data = UserDefaults.standard.data(forKey: key(for: userId)),
              let memory = try? JSONDecoder().decode(BrewMemory.self, from: data) else {
            return BrewMemory()
        }
        return memory
    }

    private func save(_ memory: BrewMemory, userId: String) {
        if let data = try? JSONEncoder().encode(memory) {
            UserDefaults.standard.set(data, forKey: key(for: userId))
        }
    }

    // MARK: - Mission

    /// 每次成功搜索后调用:目标持久化为常驻任务
    func recordSearch(goal: String, userId: String) {
        var memory = load(userId: userId)
        if var mission = memory.activeMission, mission.goal == goal {
            mission.lastRunAt = Date()
            mission.timesRun += 1
            memory.activeMission = mission
        } else {
            memory.activeMission = BrewMission(goal: goal, createdAt: Date(), lastRunAt: Date(), timesRun: 1)
        }
        save(memory, userId: userId)
        print("🧠 [BrewMemory] mission saved: \"\(goal.prefix(60))\"")
    }

    /// onboarding 播种:把"想认识谁"存为 mission,lastRunAt 置远古 → 首次打开 Brew 即自动执行(wow moment)
    func seedMission(goal: String, userId: String) {
        var memory = load(userId: userId)
        memory.activeMission = BrewMission(goal: goal, createdAt: Date(), lastRunAt: .distantPast, timesRun: 0)
        save(memory, userId: userId)
        print("🌱 [BrewMemory] mission seeded from onboarding: \"\(goal.prefix(60))\"")
    }

    func clearMission(userId: String) {
        var memory = load(userId: userId)
        memory.activeMission = nil
        save(memory, userId: userId)
    }

    /// 该不该主动替用户再跑一次 mission(距上次 >20h)
    func missionDueForProactiveRun(userId: String) -> BrewMission? {
        guard let mission = load(userId: userId).activeMission else { return nil }
        return Date().timeIntervalSince(mission.lastRunAt) > 20 * 3600 ? mission : nil
    }

    // MARK: - Learning

    func addPreference(_ note: String, userId: String) {
        var memory = load(userId: userId)
        let trimmed = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        guard !trimmed.isEmpty, !memory.preferences.contains(trimmed) else { return }
        memory.preferences.append(trimmed)
        if memory.preferences.count > maxPreferences {
            memory.preferences.removeFirst(memory.preferences.count - maxPreferences)
        }
        save(memory, userId: userId)
        print("🧠 [BrewMemory] learned: \(trimmed)")
    }

    func recordInviteSent(to name: String, userId: String) {
        var memory = load(userId: userId)
        if !memory.sentInviteNames.contains(name) { memory.sentInviteNames.append(name) }
        if memory.sentInviteNames.count > maxNames {
            memory.sentInviteNames.removeFirst(memory.sentInviteNames.count - maxNames)
        }
        save(memory, userId: userId)
    }

    func recordDeclined(name: String, userId: String) {
        var memory = load(userId: userId)
        if !memory.declinedNames.contains(name) { memory.declinedNames.append(name) }
        if memory.declinedNames.count > maxNames {
            memory.declinedNames.removeFirst(memory.declinedNames.count - maxNames)
        }
        save(memory, userId: userId)
    }

    /// 🎉 已向用户报喜过某人接受邀请(防重复庆祝)
    func recordAnnouncedMatch(name: String, userId: String) {
        var memory = load(userId: userId)
        var announced = memory.announcedMatchNames ?? []
        if !announced.contains(name) { announced.append(name) }
        memory.announcedMatchNames = Array(announced.suffix(maxNames))
        save(memory, userId: userId)
    }

    /// ☕ 已对某人提供过见面简报(防重复)
    func recordPrepOffered(name: String, userId: String) {
        var memory = load(userId: userId)
        var offered = memory.prepOfferedNames ?? []
        if !offered.contains(name) { offered.append(name) }
        memory.prepOfferedNames = Array(offered.suffix(maxNames))
        save(memory, userId: userId)
    }

    /// 📊 worth-it 回访结果:北极星指标数据点 + 偏好养料
    func recordWorthIt(name: String, worthIt: Bool, userId: String) {
        var memory = load(userId: userId)
        var surveyed = memory.surveyedNames ?? []
        if !surveyed.contains(name) { surveyed.append(name) }
        memory.surveyedNames = Array(surveyed.suffix(maxNames))
        memory.preferences.append("Coffee chat with \(name): \(worthIt ? "worth it 👍" : "not worth it 👎")")
        if memory.preferences.count > maxPreferences {
            memory.preferences.removeFirst(memory.preferences.count - maxPreferences)
        }
        save(memory, userId: userId)
        // 北极星埋点(先落日志,后接分析后端)
        print("📊 [WorthIt] user=\(userId.prefix(8)) chat_with=\(name) worth_it=\(worthIt)")
    }

    // MARK: - Context for LLM

    /// 注入 agent 系统 prompt 的记忆摘要;空记忆返回 nil
    func contextSummary(userId: String) -> String? {
        let memory = load(userId: userId)
        var lines: [String] = []
        if let mission = memory.activeMission {
            lines.append("Standing mission: \"\(mission.goal)\" (searched \(mission.timesRun)x)")
        }
        if !memory.preferences.isEmpty {
            lines.append("Learned preferences: \(memory.preferences.joined(separator: "; "))")
        }
        if !memory.sentInviteNames.isEmpty {
            lines.append("Already invited (do not re-suggest): \(memory.sentInviteNames.suffix(10).joined(separator: ", "))")
        }
        if !memory.declinedNames.isEmpty {
            lines.append("User declined before (avoid similar unless asked): \(memory.declinedNames.suffix(10).joined(separator: ", "))")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
