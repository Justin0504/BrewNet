//
//  OnboardingManager.swift
//  BrewNet
//
//  Created for managing user onboarding state
//

import Foundation
import SwiftUI

/// 管理新用户引导的状态
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    // MARK: - Published Properties
    
    /// 是否已看过欢迎引导
    @Published var hasSeenWelcomeOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenWelcomeOnboarding, forKey: Keys.hasSeenWelcomeOnboarding)
        }
    }
    
    /// 是否已看过 Matches 滑动提示
    @Published var hasSeenMatchesSwipeTip: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenMatchesSwipeTip, forKey: Keys.hasSeenMatchesSwipeTip)
        }
    }
    
    /// 是否已看过 Requests 临时聊天提示
    @Published var hasSeenRequestsTip: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenRequestsTip, forKey: Keys.hasSeenRequestsTip)
        }
    }
    
    /// 是否已看过 Chat AI 建议提示
    @Published var hasSeenChatTip: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenChatTip, forKey: Keys.hasSeenChatTip)
        }
    }
    
    /// 是否已看过 Talent Scout 提示
    @Published var hasSeenTalentScoutTip: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenTalentScoutTip, forKey: Keys.hasSeenTalentScoutTip)
        }
    }
    
    // MARK: - Keys
    
    private enum Keys {
        static let hasSeenWelcomeOnboarding = "hasSeenWelcomeOnboarding"
        static let hasSeenMatchesSwipeTip = "hasSeenMatchesSwipeTip"
        static let hasSeenRequestsTip = "hasSeenRequestsTip"
        static let hasSeenChatTip = "hasSeenChatTip"
        static let hasSeenTalentScoutTip = "hasSeenTalentScoutTip"
    }
    
    // MARK: - Initialization
    
    private init() {
        self.hasSeenWelcomeOnboarding = UserDefaults.standard.bool(forKey: Keys.hasSeenWelcomeOnboarding)
        self.hasSeenMatchesSwipeTip = UserDefaults.standard.bool(forKey: Keys.hasSeenMatchesSwipeTip)
        self.hasSeenRequestsTip = UserDefaults.standard.bool(forKey: Keys.hasSeenRequestsTip)
        self.hasSeenChatTip = UserDefaults.standard.bool(forKey: Keys.hasSeenChatTip)
        self.hasSeenTalentScoutTip = UserDefaults.standard.bool(forKey: Keys.hasSeenTalentScoutTip)
        
        print("🔍 [OnboardingManager Init] hasSeenWelcomeOnboarding: \(self.hasSeenWelcomeOnboarding)")
        print("🔍 [OnboardingManager Init] hasSeenMatchesSwipeTip: \(self.hasSeenMatchesSwipeTip)")
        print("🔍 [OnboardingManager Init] hasSeenRequestsTip: \(self.hasSeenRequestsTip)")
        print("🔍 [OnboardingManager Init] hasSeenChatTip: \(self.hasSeenChatTip)")
        print("🔍 [OnboardingManager Init] hasSeenTalentScoutTip: \(self.hasSeenTalentScoutTip)")
    }
    
    // MARK: - Public Methods
    
    /// 标记欢迎引导为已看过
    func markWelcomeOnboardingAsSeen() {
        hasSeenWelcomeOnboarding = true
        print("✅ [Onboarding] Welcome onboarding marked as seen")
    }
    
    /// 标记 Matches 滑动提示为已看过
    func markMatchesSwipeTipAsSeen() {
        hasSeenMatchesSwipeTip = true
        print("✅ [Onboarding] Matches swipe tip marked as seen")
    }
    
    /// 标记 Requests 提示为已看过
    func markRequestsTipAsSeen() {
        hasSeenRequestsTip = true
        print("✅ [Onboarding] Requests tip marked as seen")
    }
    
    /// 标记 Chat 提示为已看过
    func markChatTipAsSeen() {
        hasSeenChatTip = true
        print("✅ [Onboarding] Chat tip marked as seen")
    }
    
    /// 标记 Talent Scout 提示为已看过
    func markTalentScoutTipAsSeen() {
        hasSeenTalentScoutTip = true
        print("✅ [Onboarding] Talent Scout tip marked as seen")
    }
    
    /// 重置所有引导状态（用于开发/测试）
    func resetAllOnboarding() {
        hasSeenWelcomeOnboarding = false
        hasSeenMatchesSwipeTip = false
        hasSeenRequestsTip = false
        hasSeenChatTip = false
        hasSeenTalentScoutTip = false
        print("🔄 [Onboarding] All onboarding states reset")
    }
    
    /// 检查是否需要显示任何引导
    func needsOnboarding() -> Bool {
        return !hasSeenWelcomeOnboarding
    }
}

