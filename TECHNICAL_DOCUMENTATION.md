# BrewNet 技术文档

**版本**: 1.0.0  
**最后更新**: 2025-11-20  
**维护者**: Justin

---

## 📑 目录

1. [项目概述](#项目概述)
2. [技术栈](#技术栈)
3. [系统架构](#系统架构)
4. [核心功能模块](#核心功能模块)
5. [推荐系统详解](#推荐系统详解)
6. [数据库设计](#数据库设计)
7. [API 接口文档](#api-接口文档)
8. [权限和隐私](#权限和隐私)
9. [支付和订阅](#支付和订阅)
10. [部署和配置](#部署和配置)
11. [性能优化](#性能优化)
12. [测试策略](#测试策略)
13. [常见问题](#常见问题)
14. [未来规划](#未来规划)

---

## 1. 项目概述

### 1.1 项目简介
BrewNet 是一款专为专业人士设计的社交网络应用，通过 AI 驱动的推荐算法帮助用户找到职业伙伴、导师或学徒，并通过"咖啡聊天"功能促进线下见面。

### 1.2 核心价值
- **智能匹配**: 基于双塔神经网络的推荐算法
- **真实社交**: 鼓励线下咖啡约会
- **隐私优先**: 用户完全控制个人信息可见性
- **专业社区**: 高质量的职业人脉平台

### 1.3 目标用户
- 职场新人寻找导师
- 专业人士扩展人脉
- 创业者寻找合作伙伴
- 行业专家分享知识

### 1.4 项目统计
```
代码行数: ~30,000+ lines
文件数量: 50+ Swift files
支持平台: iOS 17.0+
开发语言: Swift 5.9+
后端服务: Supabase
```

---

## 2. 技术栈

### 2.1 前端技术

#### 核心框架
- **SwiftUI**: UI 框架
- **Swift**: 编程语言 (5.9+)
- **Combine**: 响应式编程

#### UI 组件
- **AsyncImage**: 异步图片加载
- **PhotosPicker**: 照片选择器
- **TabView**: 页面导航
- **Custom Views**: 自定义卡片、气泡等

#### 状态管理
- **@State**: 本地状态
- **@EnvironmentObject**: 全局状态
- **@Published**: 可观察对象
- **UserDefaults**: 本地持久化

### 2.2 后端技术

#### BaaS 平台
- **Supabase**: 后端即服务
  - PostgreSQL 数据库
  - 实时订阅
  - 认证服务
  - 对象存储
  - Edge Functions

#### API 集成
- **Supabase Swift SDK**: 官方 SDK
- **StoreKit 2**: 应用内购买
- **CoreLocation**: 定位服务

### 2.3 AI/ML 技术

#### 推荐算法
- **Two-Tower Encoder**: 双塔神经网络
- **Multi-hot Encoding**: 多热编码
- **Cosine Similarity**: 余弦相似度
- **Jaccard Similarity**: 杰卡德相似度

#### 特征工程
- **Feature Extraction**: 特征提取
- **Normalization**: 归一化
- **Embedding**: 特征嵌入

### 2.4 开发工具

```
IDE: Xcode 15.0+
版本控制: Git/GitHub
项目管理: Xcode Project
依赖管理: Swift Package Manager
```

---

## 3. 系统架构

### 3.1 整体架构图

```
┌─────────────────────────────────────────────────────┐
│                    BrewNet iOS App                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │  UI Layer    │  │ View Models  │  │ Services │ │
│  │  (SwiftUI)   │→→│  (@Published)│→→│  Layer   │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│                                           ↓         │
│                                    ┌──────────────┐ │
│                                    │ Data Manager │ │
│                                    └──────────────┘ │
│                                           ↓         │
└───────────────────────────────────────────┼─────────┘
                                            ↓
                              ┌──────────────────────┐
                              │   Supabase Cloud    │
                              ├──────────────────────┤
                              │ • PostgreSQL DB      │
                              │ • Authentication     │
                              │ • Storage (Photos)   │
                              │ • Realtime Updates   │
                              │ • Edge Functions     │
                              └──────────────────────┘
```

### 3.2 应用架构模式

采用 **MVVM (Model-View-ViewModel)** 架构:

```
View (SwiftUI)
    ↓
ViewModel (@ObservableObject)
    ↓
Service Layer
    ↓
Data Layer (Supabase)
```

### 3.3 核心服务模块

```swift
// 服务层架构
BrewNetApp
├── AuthManager              // 认证管理
├── SupabaseService          // 数据库操作
├── DatabaseManager          // Core Data + Supabase 协调
├── RecommendationService    // 推荐服务
└── SimpleTwoTowerEncoder    // AI 推荐算法
```

### 3.4 数据流

```
用户操作
    ↓
View 触发事件
    ↓
ViewModel 处理逻辑
    ↓
Service 调用 API
    ↓
Supabase 数据操作
    ↓
返回结果 / 错误处理
    ↓
更新 UI (@Published)
```

---

## 4. 核心功能模块

### 4.1 用户认证模块

#### 4.1.1 认证流程
```swift
// AuthManager.swift
class AuthManager: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isAuthenticated: Bool = false
    
    // 核心功能
    func signUp(email: String, password: String, name: String)
    func signIn(email: String, password: String)
    func signOut()
    func resetPassword(email: String)
}
```

#### 4.1.2 会话管理
- 使用 Supabase Auth 管理会话
- 自动刷新 token
- 本地持久化会话状态

#### 4.1.3 安全措施
- 密码加密存储
- Token 过期自动处理
- 防暴力破解（后端限流）

### 4.2 用户资料模块

#### 4.2.1 资料结构
```swift
// ProfileModels.swift
struct BrewNetProfile: Codable, Identifiable {
    let userId: String
    var coreIdentity: CoreIdentity          // 基本信息
    var professionalBackground: ProfessionalBackground  // 职业背景
    var personalitySocial: PersonalitySocial           // 个性与社交
    var networkingIntention: NetworkingIntention       // 社交意图
    var networkingPreferences: NetworkingPreferences   // 社交偏好
    var privacyTrust: PrivacyTrust                     // 隐私设置
}
```

#### 4.2.2 资料完整度计算
```swift
func calculateProfileCompletion(_ profile: BrewNetProfile) -> Double {
    // 权重配置
    - Core Identity: 25%
    - Professional Background: 25%
    - Personality Social: 20%
    - Networking Intention: 15%
    - Networking Preferences: 10%
    - Privacy Trust: 5%
}
```

#### 4.2.3 照片管理
- 支持多张照片（工作照、生活照）
- Supabase Storage 存储
- 压缩和优化
- 图片 CDN 加速

### 4.3 推荐匹配模块

#### 4.3.1 推荐流程
```
1. 获取用户特征向量
2. 查询候选用户池
3. 计算相似度得分
4. 行为指标重排序
5. 过滤器应用（距离、Pro 状态等）
6. 返回排序后的推荐列表
```

#### 4.3.2 匹配算法
详见 [第 5 节：推荐系统详解](#5-推荐系统详解)

#### 4.3.3 推荐策略
- **冷启动**: 新用户基于资料完整度推荐
- **热启动**: 基于行为数据个性化推荐
- **多样性**: 保证推荐结果的多样性
- **实时更新**: 用户资料更新后刷新推荐

### 4.4 聊天模块

#### 4.4.1 聊天架构
```swift
// ChatInterfaceView.swift
struct ChatSession {
    let id: String
    let senderId: String
    let receiverId: String
    var messages: [Message]
    var lastMessage: Message?
    var lastMessageTime: Date?
}
```

#### 4.4.2 消息类型
- 文本消息
- 咖啡邀请卡片
- 系统消息（匹配通知等）

#### 4.4.3 实时功能
- 使用 Supabase Realtime
- 消息即时送达
- 已读状态同步
- 在线状态显示

### 4.5 咖啡聊天模块

#### 4.5.1 邀请流程
```
1. 用户 A 发送咖啡邀请
   ↓
2. 填写时间、地点、备注
   ↓
3. 创建邀请记录（status: pending）
   ↓
4. 用户 B 收到邀请消息
   ↓
5. 用户 B 接受/拒绝
   ↓
6. 状态更新（accepted/declined）
   ↓
7. 约会添加到日程
```

#### 4.5.2 数据模型
```swift
struct CoffeeChatInvitation {
    let id: String
    let senderId: String
    let receiverId: String
    var status: InvitationStatus  // pending, accepted, declined
    var scheduledDate: Date?
    var location: String?
    var notes: String?
}
```

### 4.6 筛选器模块

#### 4.6.1 筛选条件
```swift
struct MatchFilter {
    var industries: Set<Industry>           // 行业
    var experienceLevels: Set<ExperienceLevel>  // 经验级别
    var intentions: Set<MainIntention>      // 社交意图
    var minYearsOfExperience: Int?          // 最小工作年限
    var maxYearsOfExperience: Int?          // 最大工作年限
    var maxDistance: Double?                // 最大距离 (km)
    var showProOnly: Bool                   // 仅显示 Pro 用户
}
```

#### 4.6.2 应用逻辑
- 在推荐算法后端应用
- 客户端本地过滤
- 实时更新推荐结果

### 4.7 订阅模块 (BrewNet Pro)

#### 4.7.1 订阅权益
```swift
Pro 会员功能:
- 无限点赞次数（非 Pro: 10/天）
- 超级推荐位展示
- 查看谁赞了你
- 高级筛选功能
- 优先客服支持
- 专属 Pro 徽章
```

#### 4.7.2 实现方式
- StoreKit 2 集成
- 订阅状态同步到 Supabase
- 本地缓存订阅状态
- 自动续订和恢复购买

---

## 5. 推荐系统详解

### 5.1 双塔神经网络架构

#### 5.1.1 概念
双塔模型（Two-Tower Model）将用户和候选者分别编码为特征向量，然后计算相似度。

```
User Tower                 Candidate Tower
    ↓                           ↓
User Features             Candidate Features
    ↓                           ↓
Encoding Layer            Encoding Layer
    ↓                           ↓
User Embedding            Candidate Embedding
    ↓                           ↓
    └────────→ Similarity ←─────┘
              (Cosine/Dot Product)
```

#### 5.1.2 实现
```swift
// SimpleTwoTowerEncoder.swift
class SimpleTwoTowerEncoder {
    // 用户塔
    static func encodeUser(_ features: UserTowerFeatures) -> [Double] {
        var embedding: [Double] = []
        
        // 1. 稀疏特征编码
        embedding += encodeIndustry(features.industry)
        embedding += encodeExperienceLevel(features.experienceLevel)
        embedding += encodeMainIntention(features.mainIntention)
        
        // 2. 多热编码
        embedding += multiHotEncode(features.skills, vocab: FeatureVocabularies.allSkills)
        embedding += multiHotEncode(features.subIntentions, vocab: FeatureVocabularies.allSubIntentions)
        
        // 3. 数值特征归一化
        embedding.append(normalize(features.yearsOfExperience, min: 0, max: 50))
        embedding.append(features.profileCompletion)
        
        // 4. 行为指标
        if let metrics = features.behavioralMetrics {
            embedding.append(normalize(Double(metrics.activityScore), min: 0, max: 10))
            embedding.append(normalize(Double(metrics.connectScore), min: 0, max: 10))
            embedding.append(normalize(Double(metrics.mentorScore), min: 0, max: 10))
        }
        
        return embedding
    }
    
    // 候选者塔（结构相同）
    static func encodeCandidate(_ features: UserTowerFeatures) -> [Double] {
        return encodeUser(features)  // 共享编码逻辑
    }
}
```

### 5.2 相似度计算

#### 5.2.1 多维度相似度
```swift
static func calculateSimilarity(
    user: UserTowerFeatures,
    candidate: UserTowerFeatures,
    weights: RecommendationWeights
) -> Double {
    var totalScore = 0.0
    
    // 1. 技能互补性
    let skillComplement = calculateSkillComplement(user, candidate)
    totalScore += skillComplement * weights.skillComplementWeight
    
    // 2. 意图匹配
    let intentionMatch = calculateIntentionMatch(user, candidate)
    totalScore += intentionMatch * weights.intentionWeight
    
    // 3. 子意图相似度（Jaccard）
    let subIntentionSim = calculateSubIntentionSimilarity(user, candidate)
    totalScore += subIntentionSim * weights.subIntentionWeight
    
    // 4. 行业匹配
    let industryMatch = user.industry == candidate.industry ? 1.0 : 0.0
    totalScore += industryMatch * weights.industryWeight
    
    // 5. 经验级别互补
    let expComplement = calculateExperienceComplement(user, candidate)
    totalScore += expComplement * weights.experienceLevelWeight
    
    // 6. 技能相似度
    let skillSim = calculateJaccardSimilarity(user.skills, candidate.skills)
    totalScore += skillSim * weights.skillSimilarityWeight
    
    // 7. 价值观相似度
    let valuesSim = calculateJaccardSimilarity(user.values, candidate.values)
    totalScore += valuesSim * weights.valuesWeight
    
    // 8. 兴趣爱好相似度
    let hobbiesSim = calculateJaccardSimilarity(user.hobbies, candidate.hobbies)
    totalScore += hobbiesSim * weights.hobbiesWeight
    
    // 9. 资料完整度
    totalScore += candidate.profileCompletion * weights.profileCompletionWeight
    
    // 10. 认证状态
    let verifiedScore = candidate.isVerified == 1 ? 1.0 : 0.0
    totalScore += verifiedScore * weights.verifiedWeight
    
    // 11. 行为指标（如果存在）
    if let metrics = candidate.behavioralMetrics {
        totalScore += normalize(Double(metrics.activityScore), min: 0, max: 10) 
                      * weights.activityScoreWeight
        totalScore += normalize(Double(metrics.connectScore), min: 0, max: 10) 
                      * weights.connectScoreWeight
        totalScore += normalize(Double(metrics.mentorScore), min: 0, max: 10) 
                      * weights.mentorScoreWeight
    }
    
    return min(totalScore, 1.0)
}
```

#### 5.2.2 权重配置
```swift
struct RecommendationWeights {
    let skillComplementWeight: Double = 0.12
    let intentionWeight: Double = 0.24
    let subIntentionWeight: Double = 0.18
    let industryWeight: Double = 0.20
    let experienceLevelWeight: Double = 0.12
    let skillSimilarityWeight: Double = 0.035
    let valuesWeight: Double = 0.028
    let hobbiesWeight: Double = 0.02
    let careerStageWeight: Double = 0.02
    let profileCompletionWeight: Double = 0.015
    let verifiedWeight: Double = 0.015
    
    // 行为指标权重
    let activityScoreWeight: Double = 0.08
    let connectScoreWeight: Double = 0.06
    let mentorScoreWeight: Double = 0.04
    let combinedBehaviorWeight: Double = 0.12
}
```

### 5.3 特殊算法

#### 5.3.1 技能互补性
```swift
// 学习技能 ∩ 教授技能
static func calculateSkillComplement(
    _ user: UserTowerFeatures,
    _ candidate: UserTowerFeatures
) -> Double {
    let userWantsToLearn = Set(user.skillsToLearn)
    let candidateCanTeach = Set(candidate.skillsToTeach)
    let intersection = userWantsToLearn.intersection(candidateCanTeach)
    
    if userWantsToLearn.isEmpty { return 0.0 }
    return Double(intersection.count) / Double(userWantsToLearn.count)
}
```

#### 5.3.2 Jaccard 相似度
```swift
static func calculateJaccardSimilarity(_ set1: [String], _ set2: [String]) -> Double {
    let s1 = Set(set1)
    let s2 = Set(set2)
    
    let intersection = s1.intersection(s2).count
    let union = s1.union(s2).count
    
    return union > 0 ? Double(intersection) / Double(union) : 0.0
}
```

#### 5.3.3 意图匹配
```swift
static func calculateIntentionMatch(
    _ user: UserTowerFeatures,
    _ candidate: UserTowerFeatures
) -> Double {
    // 寻找导师 <-> 愿意指导
    if user.mainIntention == "find_mentor" && candidate.mainIntention == "offer_mentorship" {
        return 1.0
    }
    // 寻找学徒 <-> 寻找导师
    if user.mainIntention == "offer_mentorship" && candidate.mainIntention == "find_mentor" {
        return 1.0
    }
    // 相同意图（合作、社交等）
    if user.mainIntention == candidate.mainIntention {
        return 0.8
    }
    return 0.3
}
```

### 5.4 行为指标重排序

#### 5.4.1 概念
在基础推荐的基础上，根据用户的活跃度、连接意愿等行为指标进行二次排序。

```swift
static func applyBehavioralReRanking(
    recommendations: [RecommendationResult],
    userBehavior: UserBehavioralMetrics?
) -> [RecommendationResult] {
    return recommendations.sorted { candidate1, candidate2 in
        let score1 = calculateFinalScore(candidate1, userBehavior)
        let score2 = calculateFinalScore(candidate2, userBehavior)
        return score1 > score2
    }
}

private static func calculateFinalScore(
    _ candidate: RecommendationResult,
    _ userBehavior: UserBehavioralMetrics?
) -> Double {
    var score = candidate.score
    
    // 根据候选者的行为指标调整
    if let metrics = candidate.behavioralMetrics {
        score *= (1.0 + Double(metrics.connectScore) / 20.0)  // 最多提升 50%
    }
    
    return score
}
```

### 5.5 冷启动策略

#### 5.5.1 新用户推荐
```swift
static func getColdStartRecommendations(
    for user: UserTowerFeatures,
    from candidates: [UserTowerFeatures]
) -> [RecommendationResult] {
    // 优先推荐：
    // 1. 资料完整度高的用户
    // 2. 认证用户
    // 3. 活跃用户（高 activityScore）
    // 4. Pro 用户
    
    return candidates
        .filter { $0.profileCompletion > 0.7 }
        .sorted { c1, c2 in
            let score1 = c1.profileCompletion + (c1.isVerified == 1 ? 0.2 : 0.0)
            let score2 = c2.profileCompletion + (c2.isVerified == 1 ? 0.2 : 0.0)
            return score1 > score2
        }
}
```

---

## 6. 数据库设计

### 6.1 数据库架构

使用 **Supabase (PostgreSQL)** 作为主数据库。

#### 6.1.1 核心表

```sql
-- 1. users 表 (Supabase Auth 管理)
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_pro BOOLEAN DEFAULT FALSE,
    pro_expires_at TIMESTAMP WITH TIME ZONE
);

-- 2. profiles 表 (用户资料)
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    -- JSONB 字段存储结构化数据
    core_identity JSONB,              -- 基本信息
    professional_background JSONB,    -- 职业背景
    personality_social JSONB,         -- 个性社交
    networking_intention JSONB,       -- 社交意图
    networking_preferences JSONB,     -- 社交偏好
    privacy_trust JSONB,              -- 隐私设置
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. user_features 表 (推荐系统特征)
CREATE TABLE user_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    -- 稀疏特征
    location TEXT,
    time_zone TEXT,
    industry TEXT,
    experience_level TEXT,
    career_stage TEXT,
    main_intention TEXT,
    
    -- 多值特征 (JSONB 数组)
    skills JSONB DEFAULT '[]'::jsonb,
    hobbies JSONB DEFAULT '[]'::jsonb,
    values JSONB DEFAULT '[]'::jsonb,
    languages JSONB DEFAULT '[]'::jsonb,
    sub_intentions JSONB DEFAULT '[]'::jsonb,
    skills_to_learn JSONB DEFAULT '[]'::jsonb,
    skills_to_teach JSONB DEFAULT '[]'::jsonb,
    
    -- 数值特征
    years_of_experience DOUBLE PRECISION DEFAULT 0.0,
    profile_completion DOUBLE PRECISION DEFAULT 0.5,
    is_verified INTEGER DEFAULT 0,
    
    -- 行为量化指标
    activity_score SMALLINT DEFAULT 5,
    connect_score SMALLINT DEFAULT 5,
    mentor_score SMALLINT DEFAULT 5,
    
    -- 原始行为数据
    sessions_7d INTEGER DEFAULT 0,
    messages_sent_7d INTEGER DEFAULT 0,
    matches_7d INTEGER DEFAULT 0,
    last_active_at TIMESTAMP WITH TIME ZONE,
    
    -- 行为指标详情 (JSONB)
    behavioral_metrics JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. invitations 表 (点赞/邀请)
CREATE TABLE invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL,  -- pending, accepted, rejected
    reason_for_interest TEXT,
    sender_profile JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(sender_id, receiver_id)
);

-- 5. messages 表 (聊天消息)
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. coffee_chat_invitations 表 (咖啡邀请)
CREATE TABLE coffee_chat_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_name TEXT NOT NULL,
    receiver_name TEXT NOT NULL,
    status TEXT NOT NULL,  -- pending, accepted, declined
    scheduled_date TIMESTAMP WITH TIME ZONE,
    location TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. coffee_chat_schedules 表 (约会日程)
CREATE TABLE coffee_chat_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invitation_id UUID REFERENCES coffee_chat_invitations(id) ON DELETE CASCADE,
    user1_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user2_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
    location TEXT NOT NULL,
    notes TEXT,
    has_met BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. photos 表 (用户照片)
CREATE TABLE photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    photo_type TEXT NOT NULL,  -- work, lifestyle
    photo_url TEXT NOT NULL,
    caption TEXT,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 6.2 索引优化

```sql
-- 高频查询字段索引
CREATE INDEX idx_user_features_industry ON user_features(industry);
CREATE INDEX idx_user_features_experience_level ON user_features(experience_level);
CREATE INDEX idx_user_features_main_intention ON user_features(main_intention);
CREATE INDEX idx_user_features_activity_score ON user_features(activity_score);
CREATE INDEX idx_user_features_connect_score ON user_features(connect_score);

-- 复合索引
CREATE INDEX idx_invitations_sender_receiver ON invitations(sender_id, receiver_id);
CREATE INDEX idx_messages_sender_receiver ON messages(sender_id, receiver_id, created_at DESC);

-- JSONB 索引（GIN）
CREATE INDEX idx_user_features_skills ON user_features USING GIN(skills);
CREATE INDEX idx_user_features_sub_intentions ON user_features USING GIN(sub_intentions);
```

### 6.3 数据同步触发器

#### 6.3.1 profiles → user_features 同步
```sql
CREATE OR REPLACE FUNCTION sync_user_features()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_features (
        user_id,
        location,
        industry,
        experience_level,
        main_intention,
        skills,
        sub_intentions,
        -- ... 其他字段
    ) VALUES (
        NEW.user_id,
        NEW.core_identity->>'location',
        NEW.professional_background->>'industry',
        NEW.professional_background->>'experience_level',
        NEW.networking_intention->>'selected_intention',
        NEW.professional_background->'skills',
        NEW.networking_intention->'selected_sub_intentions',
        -- ... 其他字段
    )
    ON CONFLICT (user_id) DO UPDATE SET
        location = EXCLUDED.location,
        industry = EXCLUDED.industry,
        -- ... 更新所有字段
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_sync_user_features
AFTER INSERT OR UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION sync_user_features();
```

### 6.4 RLS (Row Level Security) 策略

```sql
-- 启用 RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- 用户只能查看自己的资料或公开资料
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view public profiles" ON profiles
    FOR SELECT USING (
        (privacy_trust->'visibility_settings'->>'profile' = 'public')
    );

-- 用户只能发送/接收自己的消息
CREATE POLICY "Users can view own messages" ON messages
    FOR SELECT USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
    );

CREATE POLICY "Users can insert own messages" ON messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);
```

---

## 7. API 接口文档

### 7.1 认证接口

#### 7.1.1 注册
```swift
// AuthManager.swift
func signUp(email: String, password: String, name: String) async throws -> AppUser
```

**请求参数:**
- `email`: String - 用户邮箱
- `password`: String - 密码（最少 6 位）
- `name`: String - 用户姓名

**返回:**
- `AppUser` - 用户信息

**错误:**
- `AuthError.emailAlreadyExists` - 邮箱已注册
- `AuthError.weakPassword` - 密码强度不足

---

#### 7.1.2 登录
```swift
func signIn(email: String, password: String) async throws -> AppUser
```

---

### 7.2 用户资料接口

#### 7.2.1 获取资料
```swift
// SupabaseService.swift
func fetchUserProfile(userId: String) async throws -> BrewNetProfile
```

---

#### 7.2.2 更新资料
```swift
func updateProfile(
    userId: String,
    profile: BrewNetProfile
) async throws
```

---

#### 7.2.3 上传照片
```swift
func uploadPhoto(
    userId: String,
    imageData: Data,
    photoType: String,  // "work" or "lifestyle"
    caption: String?
) async throws -> String  // Returns photo URL
```

**实现细节:**
- 上传到 Supabase Storage
- 路径: `photos/{userId}/{photoType}/{uuid}.jpg`
- 自动压缩图片
- 返回公开 URL

---

### 7.3 推荐接口

#### 7.3.1 获取推荐
```swift
// RecommendationService.swift
func getRecommendations(
    for userId: String,
    limit: Int = 20,
    filters: MatchFilter? = nil,
    maxDistance: Double? = nil,
    userLocation: String? = nil
) async throws -> [BrewNetProfile]
```

**参数:**
- `userId`: 当前用户 ID
- `limit`: 返回数量
- `filters`: 筛选条件
- `maxDistance`: 最大距离 (km)
- `userLocation`: 用户位置

**返回:**
- 排序后的推荐用户列表

---

### 7.4 匹配接口

#### 7.4.1 发送点赞
```swift
func sendInvitation(
    senderId: String,
    receiverId: String,
    reasonForInterest: String?
) async throws -> String  // Returns invitation ID
```

---

#### 7.4.2 检查匹配
```swift
func checkMutualMatch(
    userId1: String,
    userId2: String
) async throws -> Bool
```

**逻辑:**
- 双方都点赞才算匹配
- 匹配后自动创建聊天会话

---

### 7.5 聊天接口

#### 7.5.1 获取聊天列表
```swift
func fetchChatSessions(
    for userId: String
) async throws -> [ChatSession]
```

---

#### 7.5.2 发送消息
```swift
func sendMessage(
    senderId: String,
    receiverId: String,
    content: String
) async throws -> Message
```

---

#### 7.5.3 实时订阅
```swift
func subscribeToMessages(
    userId: String,
    onMessage: @escaping (Message) -> Void
) async throws -> RealtimeChannel
```

**实现:**
使用 Supabase Realtime 订阅 `messages` 表变化

---

### 7.6 咖啡邀请接口

#### 7.6.1 创建邀请
```swift
func createCoffeeChatInvitation(
    senderId: String,
    receiverId: String,
    senderName: String,
    receiverName: String,
    scheduledDate: Date? = nil,
    location: String? = nil,
    notes: String? = nil
) async throws -> String  // Returns invitation ID
```

---

#### 7.6.2 接受邀请
```swift
func acceptCoffeeChatInvitation(
    invitationId: String,
    scheduledDate: Date,
    location: String,
    notes: String?
) async throws
```

**操作:**
1. 更新邀请状态为 `accepted`
2. 创建 `coffee_chat_schedules` 记录
3. 发送系统消息通知双方

---

#### 7.6.3 获取日程
```swift
func fetchCoffeeChatSchedules(
    for userId: String
) async throws -> [CoffeeChatSchedule]
```

---

### 7.7 订阅接口

#### 7.7.1 购买订阅
```swift
// 使用 StoreKit 2
func purchasePro(
    product: Product
) async throws -> Transaction
```

---

#### 7.7.2 同步订阅状态
```swift
func syncProSubscription(
    userId: String,
    isActive: Bool,
    expiresAt: Date?
) async throws
```

---

### 7.8 行为指标接口

#### 7.8.1 获取行为指标
```swift
func getUserBehavioralMetrics(
    userId: String
) async throws -> (activity: Int, connect: Int, mentor: Int)
```

---

#### 7.8.2 更新行为指标
```swift
func updateUserBehavioralMetrics(
    userId: String,
    activityScore: Int,
    connectScore: Int,
    mentorScore: Int,
    lastActiveAt: Date
) async throws
```

---

#### 7.8.3 记录用户活动
```swift
func recordUserActivityAndUpdateMetrics(
    userId: String,
    activityType: String,
    profile: BrewNetProfile? = nil
) async throws
```

**活动类型:**
- `"login"` - 登录
- `"message_sent"` - 发送消息
- `"profile_view"` - 查看资料
- `"match"` - 匹配成功

---

## 8. 权限和隐私

### 8.1 系统权限

#### 8.1.1 位置权限
```xml
<!-- Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>BrewNet uses your location to recommend nearby professionals and suggest convenient coffee chat locations.</string>
```

**使用场景:**
- 推荐附近用户
- 咖啡约会地点建议
- 距离筛选

**实现:**
```swift
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
}
```

---

#### 8.1.2 照片库权限
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>BrewNet needs access to your photo library to upload profile pictures.</string>
```

**使用场景:**
- 上传头像
- 上传工作照/生活照

---

#### 8.1.3 推送通知权限 (待实现)
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>BrewNet sends you notifications about new matches, messages, and coffee chat invitations.</string>
```

---

### 8.2 隐私设置

#### 8.2.1 可见性控制
```swift
struct VisibilitySettings: Codable {
    var profile: VisibilityLevel       // 资料可见性
    var company: VisibilityLevel       // 公司信息
    var skills: VisibilityLevel        // 技能
    var interests: VisibilityLevel     // 兴趣
    var location: VisibilityLevel      // 位置
    var timeslot: VisibilityLevel      // 可用时间
    var email: VisibilityLevel         // 邮箱
    var phoneNumber: VisibilityLevel   // 电话
}

enum VisibilityLevel: String, Codable {
    case everyone = "everyone"           // 所有人可见
    case connections = "connections"     // 仅匹配用户可见
    case privateLevel = "private"        // 私有
}
```

---

#### 8.2.2 数据访问控制
```swift
// UserProfileCardView.swift
private var shouldShowCompany: Bool {
    privacySettings.company.isVisible(isConnection: isConnection)
}

private var shouldShowSkills: Bool {
    privacySettings.skills.isVisible(isConnection: isConnection)
}

// 根据当前用户与资料所有者的关系判断
```

---

### 8.3 数据保护

#### 8.3.1 加密
- 所有网络传输使用 HTTPS/TLS
- Supabase 数据库加密存储
- 本地敏感数据使用 Keychain 存储

#### 8.3.2 数据最小化
- 只收集必要的用户信息
- 用户可以选择不填写非必需字段
- 支持匿名浏览（查看推荐）

#### 8.3.3 数据删除
```swift
// SupabaseService.swift
func deleteUserAccount(userId: String) async throws {
    // 1. 删除所有照片
    try await deleteAllUserPhotos(userId: userId)
    
    // 2. 删除相关记录（级联删除）
    // - profiles
    // - user_features
    // - invitations
    // - messages
    // - coffee_chat_invitations
    
    // 3. 删除 auth.users 记录
    try await supabase.auth.admin.deleteUser(id: userId)
}
```

**用户体验:**
- 设置页面提供"删除账户"按钮
- 二次确认
- 30 天内可恢复（软删除）

---

## 9. 支付和订阅

### 9.1 StoreKit 2 集成

#### 9.1.1 产品配置
```swift
// App Store Connect 中配置
Product ID: com.brewnet.pro.monthly
Type: Auto-Renewable Subscription
Price: $9.99/月

Product ID: com.brewnet.pro.yearly
Type: Auto-Renewable Subscription
Price: $79.99/年
```

---

#### 9.1.2 购买流程
```swift
import StoreKit

class SubscriptionManager: ObservableObject {
    @Published var isProActive = false
    
    func loadProducts() async throws -> [Product] {
        let productIds = [
            "com.brewnet.pro.monthly",
            "com.brewnet.pro.yearly"
        ]
        return try await Product.products(for: productIds)
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateProStatus(transaction: transaction)
            await transaction.finish()
            
        case .userCancelled, .pending:
            break
            
        @unknown default:
            break
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
```

---

#### 9.1.3 订阅验证
```swift
func updateProStatus(transaction: Transaction) async {
    // 1. 检查交易类型
    guard transaction.productType == .autoRenewable else { return }
    
    // 2. 检查过期时间
    if let expirationDate = transaction.expirationDate,
       expirationDate > Date() {
        isProActive = true
        
        // 3. 同步到 Supabase
        try? await supabaseService.syncProSubscription(
            userId: currentUserId,
            isActive: true,
            expiresAt: expirationDate
        )
    }
}
```

---

#### 9.1.4 恢复购买
```swift
func restorePurchases() async throws {
    for await result in Transaction.currentEntitlements {
        let transaction = try checkVerified(result)
        await updateProStatus(transaction: transaction)
    }
}
```

---

### 9.2 Pro 功能实现

#### 9.2.1 无限点赞
```swift
// 非 Pro 用户每天限制 10 次
func canLike(userId: String) async throws -> Bool {
    guard !isProActive else { return true }
    
    let today = Calendar.current.startOfDay(for: Date())
    let likesCount = try await supabaseService.countLikesToday(
        userId: userId,
        since: today
    )
    
    return likesCount < 10
}
```

---

#### 9.2.2 查看谁赞了你
```swift
// 只有 Pro 用户可见
func fetchWhoLikedMe() async throws -> [BrewNetProfile] {
    guard isProActive else {
        throw SubscriptionError.proRequired
    }
    
    return try await supabaseService.fetchPendingInvitations(
        receiverId: currentUserId
    )
}
```

---

#### 9.2.3 超级推荐
```swift
// Pro 用户的资料会优先展示
func applyProBoost(candidates: [UserTowerFeatures]) -> [UserTowerFeatures] {
    candidates.sorted { c1, c2 in
        // Pro 用户优先
        if c1.isPro && !c2.isPro {
            return true
        }
        if !c1.isPro && c2.isPro {
            return false
        }
        // 相同 Pro 状态，按分数排序
        return c1.score > c2.score
    }
}
```

---

## 10. 部署和配置

### 10.1 环境配置

#### 10.1.1 开发环境
```swift
// SupabaseService.swift
#if DEBUG
let supabaseURL = "https://your-project.supabase.co"
let supabaseKey = "your-anon-key"
#else
let supabaseURL = "https://your-production-project.supabase.co"
let supabaseKey = "your-production-anon-key"
#endif
```

---

#### 10.1.2 配置文件 (推荐)
```swift
// Config.plist
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>https://your-project.supabase.co</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>your-anon-key</string>
</dict>
</plist>

// 读取配置
extension Bundle {
    func supabaseURL() -> String {
        return infoDictionary?["SUPABASE_URL"] as? String ?? ""
    }
    
    func supabaseKey() -> String {
        return infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }
}
```

---

### 10.2 Xcode 构建配置

#### 10.2.1 Schemes
- **BrewNet (Debug)**: 开发环境
- **BrewNet (Release)**: 生产环境
- **BrewNet (Staging)**: 测试环境 (可选)

---

#### 10.2.2 Build Settings
```
// Release 配置
Swift Compiler - Code Generation
- Optimization Level: -O (Optimize for Speed)

Swift Compiler - Custom Flags
- Other Swift Flags: -DRELEASE

Deployment
- iOS Deployment Target: 17.0
```

---

### 10.3 Supabase 部署

#### 10.3.1 数据库迁移
```bash
# 1. 创建 user_features 表
supabase db push add_behavioral_metrics_to_user_features.sql

# 2. 设置 RLS 策略
supabase db push setup_rls_policies.sql

# 3. 创建触发器
supabase db push setup_triggers.sql
```

---

#### 10.3.2 Storage 配置
```sql
-- 创建 photos bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('photos', 'photos', true);

-- 设置访问策略
CREATE POLICY "Anyone can view photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'photos');

CREATE POLICY "Users can upload own photos"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
);
```

---

### 10.4 CI/CD (推荐)

#### 10.4.1 GitHub Actions
```yaml
name: iOS Build and Test

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.0'
      
      - name: Build
        run: |
          xcodebuild build \
            -scheme BrewNet \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
      
      - name: Run Tests
        run: |
          xcodebuild test \
            -scheme BrewNet \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## 11. 性能优化

### 11.1 推荐算法优化

#### 11.1.1 缓存策略
```swift
class RecommendationCache {
    private var cache: [String: [BrewNetProfile]] = [:]
    private let cacheExpiration: TimeInterval = 3600  // 1 小时
    
    func get(for userId: String) -> [BrewNetProfile]? {
        return cache[userId]
    }
    
    func set(_ profiles: [BrewNetProfile], for userId: String) {
        cache[userId] = profiles
    }
    
    func invalidate(for userId: String) {
        cache.removeValue(forKey: userId)
    }
}
```

---

#### 11.1.2 分页加载
```swift
func getRecommendations(
    for userId: String,
    offset: Int = 0,
    limit: Int = 20
) async throws -> [BrewNetProfile] {
    // 只获取需要的数量，避免一次性加载所有
}
```

---

### 11.2 图片优化

#### 11.2.1 上传前压缩
```swift
func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
    var compression: CGFloat = 1.0
    var imageData = image.jpegData(compressionQuality: compression)
    
    while let data = imageData,
          data.count > maxSizeKB * 1024,
          compression > 0.1 {
        compression -= 0.1
        imageData = image.jpegData(compressionQuality: compression)
    }
    
    return imageData
}
```

---

#### 11.2.2 图片缓存
```swift
// 使用 AsyncImage 自动缓存
// 或使用第三方库如 Kingfisher
AsyncImage(url: URL(string: imageUrl)) { image in
    image.resizable()
} placeholder: {
    ProgressView()
}
```

---

### 11.3 数据库查询优化

#### 11.3.1 使用索引
```sql
-- 已在第 6.2 节创建
CREATE INDEX idx_user_features_industry ON user_features(industry);
```

---

#### 11.3.2 限制返回字段
```swift
// 只获取需要的字段
let query = client
    .from("profiles")
    .select("id, user_id, core_identity, professional_background")
    .limit(20)
```

---

#### 11.3.3 批量操作
```swift
// 批量插入
func batchInsertPhotos(_ photos: [Photo]) async throws {
    let batchSize = 10
    for batch in photos.chunked(into: batchSize) {
        try await client
            .from("photos")
            .insert(batch)
            .execute()
    }
}
```

---

### 11.4 内存优化

#### 11.4.1 及时释放大对象
```swift
func processLargeData() {
    autoreleasepool {
        let largeArray = // ... large data
        // process data
    }  // 自动释放
}
```

---

#### 11.4.2 懒加载
```swift
lazy var heavyComputation: [Double] = {
    // 只在首次访问时计算
    return computeExpensiveValue()
}()
```

---

## 12. 测试策略

### 12.1 单元测试

#### 12.1.1 推荐算法测试
```swift
// BrewNetTests/SimpleTwoTowerEncoderTests.swift
class SimpleTwoTowerEncoderTests: XCTestCase {
    func testUserEncoding() {
        let features = UserTowerFeatures(/* ... */)
        let embedding = SimpleTwoTowerEncoder.encodeUser(features)
        
        XCTAssertGreaterThan(embedding.count, 0)
        XCTAssertTrue(embedding.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
    
    func testSimilarityCalculation() {
        let user1 = UserTowerFeatures(/* ... */)
        let user2 = UserTowerFeatures(/* ... */)
        
        let similarity = SimpleTwoTowerEncoder.calculateSimilarity(
            user: user1,
            candidate: user2,
            weights: .default
        )
        
        XCTAssertGreaterThanOrEqual(similarity, 0.0)
        XCTAssertLessThanOrEqual(similarity, 1.0)
    }
}
```

---

#### 12.1.2 数据模型测试
```swift
class ProfileModelsTests: XCTestCase {
    func testProfileDecoding() throws {
        let json = """
        {
            "user_id": "123",
            "core_identity": { "name": "Test" },
            ...
        }
        """
        
        let data = json.data(using: .utf8)!
        let profile = try JSONDecoder().decode(BrewNetProfile.self, from: data)
        
        XCTAssertEqual(profile.userId, "123")
        XCTAssertEqual(profile.coreIdentity.name, "Test")
    }
}
```

---

### 12.2 集成测试

#### 12.2.1 API 测试
```swift
class SupabaseServiceTests: XCTestCase {
    var supabaseService: SupabaseService!
    
    override func setUp() {
        super.setUp()
        supabaseService = SupabaseService(/* test config */)
    }
    
    func testFetchUserProfile() async throws {
        let profile = try await supabaseService.fetchUserProfile(
            userId: "test-user-id"
        )
        
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile.userId, "test-user-id")
    }
}
```

---

### 12.3 UI 测试

#### 12.3.1 登录流程测试
```swift
class LoginUITests: XCTestCase {
    func testLogin() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 点击登录按钮
        app.buttons["Sign In"].tap()
        
        // 输入邮箱和密码
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText("test@example.com")
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("password123")
        
        // 提交
        app.buttons["Submit"].tap()
        
        // 验证跳转到主页
        XCTAssertTrue(app.tabBars.buttons["Matches"].exists)
    }
}
```

---

### 12.4 性能测试

#### 12.4.1 推荐性能测试
```swift
func testRecommendationPerformance() {
    measure {
        let recommendations = RecommendationService.getRecommendations(
            for: "user-id",
            limit: 100
        )
    }
    // 期望: < 1 秒
}
```

---

## 13. 常见问题

### 13.1 开发常见问题

#### Q1: Supabase 连接失败
**A**: 检查以下几点:
1. `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 是否正确
2. 网络连接是否正常
3. Supabase 项目是否暂停（免费计划长时间不用会暂停）

---

#### Q2: 推荐结果为空
**A**: 可能原因:
1. 用户资料不完整（`profile_completion < 0.5`）
2. `user_features` 表未同步
3. 候选用户池太小
4. 筛选条件过于严格

**调试方法:**
```sql
-- 检查 user_features 是否同步
SELECT COUNT(*) FROM user_features;

-- 检查用户特征
SELECT * FROM user_features WHERE user_id = 'xxx';
```

---

#### Q3: 照片上传失败
**A**: 检查:
1. 图片大小（建议压缩到 < 1MB）
2. Supabase Storage bucket 是否创建
3. RLS 策略是否正确配置
4. 网络权限

---

#### Q4: 行为指标未更新
**A**: 
- `BehavioralMetricsService` 已被移除，需要手动触发或使用 SQL 函数计算
- 运行 SQL: `SELECT calculate_behavioral_metrics(...)`

---

### 13.2 部署常见问题

#### Q1: Archive 失败
**A**: 
1. 检查证书和描述文件
2. 确保 Bundle ID 唯一
3. 清理 Derived Data: `Xcode → Product → Clean Build Folder`

---

#### Q2: App Store 审核被拒
**A**: 常见原因:
1. 缺少隐私政策 URL
2. 测试账号不可用
3. 元数据与实际功能不符
4. 缺少账户删除功能

**解决方案:** 参考 `APP_STORE_LAUNCH_CHECKLIST.md`

---

#### Q3: Pro 订阅无法购买
**A**:
1. 检查 App Store Connect 产品是否已审核通过
2. 确保 Sandbox 测试账号可用
3. 检查 StoreKit Configuration 文件

---

## 14. 未来规划

### 14.1 短期规划 (1-3 个月)

#### 功能增强
- [ ] **推送通知系统**
  - 新匹配通知
  - 消息通知
  - 咖啡邀请提醒
  
- [ ] **用户反馈系统**
  - 举报功能完善
  - 评分系统
  - 用户满意度调查

- [ ] **高级筛选**
  - 保存筛选条件
  - 多条件组合
  - 自定义筛选器

- [ ] **社交功能增强**
  - 语音消息
  - 视频通话预约
  - 群组咖啡聊天

---

### 14.2 中期规划 (3-6 个月)

#### 技术优化
- [ ] **离线模式**
  - 本地缓存推荐
  - 离线消息队列
  - 同步机制

- [ ] **性能提升**
  - 推荐算法优化
  - 图片 CDN 加速
  - 数据库查询优化

- [ ] **AI 增强**
  - GPT 聊天助手
  - 智能约会建议
  - 个性化推荐优化

---

### 14.3 长期规划 (6-12 个月)

#### 平台扩展
- [ ] **Android 版本**
  - React Native 或 Flutter
  - 代码共享策略
  
- [ ] **Web 版本**
  - 响应式设计
  - PWA 支持

#### 生态建设
- [ ] **企业版**
  - 团队账户
  - 内部人脉管理
  - 活动组织工具

- [ ] **社区功能**
  - 行业小组
  - 线下活动
  - 知识分享

---

## 附录

### A. 术语表

| 术语 | 说明 |
|------|------|
| Two-Tower Model | 双塔神经网络模型，用于推荐系统 |
| Multi-hot Encoding | 多热编码，表示多个类别同时激活 |
| Jaccard Similarity | 杰卡德相似度，衡量集合相似度 |
| RLS | Row Level Security，行级安全策略 |
| BaaS | Backend as a Service，后端即服务 |
| StoreKit 2 | Apple 应用内购买框架第二版 |
| MVVM | Model-View-ViewModel 架构模式 |

---

### B. 参考资料

1. **Apple 官方文档**
   - SwiftUI: https://developer.apple.com/documentation/swiftui
   - StoreKit 2: https://developer.apple.com/documentation/storekit
   - CoreLocation: https://developer.apple.com/documentation/corelocation

2. **Supabase 文档**
   - 官方文档: https://supabase.com/docs
   - Swift SDK: https://github.com/supabase-community/supabase-swift

3. **推荐系统理论**
   - Two-Tower Models: Google Research
   - Collaborative Filtering: Netflix Prize

---

### C. 版本历史

| 版本 | 日期 | 更新内容 |
|------|------|---------|
| 1.0.0 | 2025-11-20 | 初始版本，包含完整技术文档 |

---

### D. 贡献者

- **Justin** - 项目负责人、主要开发者
- **AI Assistant** - 技术文档编写

---

**文档维护**: 此文档应随着项目迭代持续更新。每次重大功能更新或架构调整时，请更新相应章节。

**联系方式**: 如有技术问题，请联系 [您的邮箱]

---

*最后更新: 2025-11-20*


