# BrewNet 用户特征完整文档

> **版本**: 1.0  
> **更新日期**: 2024-11-21  
> **维护者**: BrewNet Team Heady

---

## 目录

1. [概述](#概述)
2. [核心身份特征 (Core Identity)](#1-核心身份特征-core-identity)
3. [职业背景特征 (Professional Background)](#2-职业背景特征-professional-background)
4. [社交意图特征 (Networking Intention)](#3-社交意图特征-networking-intention)
5. [社交偏好特征 (Networking Preferences)](#4-社交偏好特征-networking-preferences)
6. [个性与社交特征 (Personality & Social)](#5-个性与社交特征-personality--social)
7. [隐私与信任特征 (Privacy & Trust)](#6-隐私与信任特征-privacy--trust)
8. [行为量化指标 (Behavioral Metrics)](#7-行为量化指标-behavioral-metrics)
9. [推荐系统特征 (Two-Tower Features)](#8-推荐系统特征-two-tower-features)
10. [特征使用场景总结](#特征使用场景总结)

---

## 概述

BrewNet 用户特征系统分为三个层次：
1. **原始特征**: 用户直接输入的基础信息
2. **派生特征**: 从原始特征计算或聚合得到的特征
3. **行为特征**: 基于用户行为动态更新的指标

### 数据存储结构

| 数据库表 | 用途 | 主要特征 |
|---------|------|---------|
| `users` | 用户基本信息 | ID, email, Pro状态, tokens |
| `profiles` | 用户详细资料 | 所有原始特征（JSONB格式） |
| `user_features` | 推荐系统特征 | 结构化特征 + 行为指标 |
| `invitations` | 社交邀请记录 | 邀请状态、时间 |
| `matches` | 匹配关系 | 匹配用户、活跃状态 |
| `messages` | 消息记录 | 消息内容、时间、已读状态 |

---

## 1. 核心身份特征 (Core Identity)

### 数据结构
**源代码**: `ProfileModels.swift` 第49-112行  
**数据库字段**: `profiles.core_identity` (JSONB)

### 特征列表

| 特征名 | 类型 | 必填 | 说明 | 使用场景 |
|--------|------|------|------|---------|
| `name` | String | ✅ | 用户姓名 | 展示、搜索、推荐 |
| `email` | String | ✅ | 电子邮件 | 登录、通知、验证 |
| `phoneNumber` | String? | ❌ | 电话号码 | 联系方式、验证 |
| `profileImage` | String? | ❌ | 头像URL | 展示、识别 |
| `bio` | String? | ❌ | 个人简介 | 文本搜索、推荐 |
| `pronouns` | String? | ❌ | 代词（he/she/they） | 尊重个人身份 |
| `location` | String? | ❌ | 位置（城市） | 地理筛选、推荐 |
| `personalWebsite` | String? | ❌ | 个人网站 | 了解用户背景 |
| `githubUrl` | String? | ❌ | GitHub链接 | 技术背景验证 |
| `linkedinUrl` | String? | ❌ | LinkedIn链接 | 职业背景验证 |
| `timeZone` | String | ✅ | 时区 | 时间匹配、会议安排 |

### 使用场景

#### 1.1 Headhunting 文本搜索
```swift
// ExploreView.swift aggregatedSearchableText()
parts.append(contentsOf: [
    profile.coreIdentity.name,
    profile.coreIdentity.bio ?? "",
    profile.coreIdentity.location ?? ""
])
```
**影响**：姓名、简介、位置都会被索引用于关键词匹配（+1.0分/关键词）

#### 1.2 推荐系统过滤
- **位置匹配**: 相同城市的用户优先推荐
- **时区兼容**: 确保会议时间合理

#### 1.3 资料完整度计算
```swift
// 每个非空字段贡献到 profile_completion 分数
profileCompletion = (填写字段数 / 总字段数)
```

---

## 2. 职业背景特征 (Professional Background)

### 数据结构
**源代码**: `ProfileModels.swift` 第114-143行  
**数据库字段**: `profiles.professional_background` (JSONB)

### 特征列表

| 特征名 | 类型 | 必填 | 说明 | 使用场景 |
|--------|------|------|------|---------|
| `currentCompany` | String? | ❌ | 当前公司 | 文本搜索、推荐 |
| `jobTitle` | String? | ❌ | 职位 | 文本搜索、推荐 |
| `industry` | String? | ❌ | 行业 | 分类推荐、筛选 |
| `experienceLevel` | Enum | ✅ | 经验等级 | 资历匹配 |
| `education` | String? | ❌ | 教育背景（旧） | 向后兼容 |
| `educations` | [Education]? | ❌ | **详细教育列表** | **校友匹配** |
| `yearsOfExperience` | Double? | ❌ | 工作年限 | 年限匹配、资历计算 |
| `careerStage` | Enum | ✅ | 职业阶段 | Founder匹配 |
| `skills` | [String] | ✅ | 技能列表 | 技能匹配、推荐 |
| `certifications` | [String] | ✅ | 证书列表 | 专业验证 |
| `languagesSpoken` | [String] | ✅ | 语言列表 | 语言匹配 |
| `workExperiences` | [WorkExperience] | ✅ | 工作经历 | 背景验证、推荐 |

### 重点：Education 详细结构

```swift
struct Education {
    let id: String
    let schoolName: String          // 学校名称
    let degree: Degree              // 学位
    let fieldOfStudy: String?       // 专业
    let startYear: Int
    let endYear: Int
}
```

### 使用场景

#### 2.1 校友匹配（Headhunting）
**代码位置**: `ExploreView.swift` 第362-392行

```swift
// 查询包含 "alumni" 时触发
if tokenSet.contains(where: { $0.contains("alum") }) {
    // 基础分: 有教育经历 +1.0
    
    // 校友加分: 同一学校 +5.0
    if currentUserSchools.contains(targetSchool) {
        score += 5.0
    }
}
```

**影响**：同校校友在搜索时排名显著提升

#### 2.2 工作年限匹配
**代码位置**: `ExploreView.swift` 第346-352行

```swift
if let years = profile.professionalBackground.yearsOfExperience {
    for target in numbers {
        if abs(years - target) <= 1.0 {
            score += 2.0  // 年限相差≤1年，加分
        }
    }
}
```

#### 2.3 Founder/Startup 匹配
**代码位置**: `ExploreView.swift` 第394-399行

```swift
if tokenSet.contains("founder") || tokenSet.contains("startup") {
    if profile.professionalBackground.careerStage == .founder {
        score += 1.0
    }
}
```

#### 2.4 Mentor Score 计算
**影响因素**: `yearsOfExperience` → `seniorityLevel` (20%权重)

```swift
// UserTowerFeatures.swift 第217-219行
let expYears = min(Double(yearsOfExperience ?? 0), 20.0)
let seniorityLevel = expYears / 20.0  // 归一化到 [0,1]
```

---

## 3. 社交意图特征 (Networking Intention)

### 数据结构
**源代码**: `ProfileModels.swift` 第145-200行  
**数据库字段**: `profiles.networking_intention` (JSONB)

### 主要意图类型 (NetworkingIntentionType)

| 意图 | 值 | 说明 | Headhunting关键词 |
|-----|-------|------|------------------|
| Learn & Grow | `learnGrow` | 学习成长 | mentor, mentoring |
| Connect & Share | `connectShare` | 连接分享 | network, connect |
| Build & Collaborate | `buildCollaborate` | 建立合作 | founder, startup |
| Unwind & Chat | `unwindChat` | 放松聊天 | casual, relax |

### 子意图类型 (SubIntentionType)

| 子意图 | 值 | 父意图 | 用途 |
|-------|-----|-------|------|
| Career Direction | `careerDirection` | Learn & Grow | 职业方向指导 |
| Skill Development | `skillDevelopment` | Learn & Grow | 技能发展 |
| Industry Transition | `industryTransition` | Learn & Grow | 行业转型 |
| Professional Advice | `professionalAdvice` | Connect & Share | 专业建议 |
| Emotional Support | `emotionalSupport` | Unwind & Chat | 情感支持 |

### 详细意图数据结构

#### 3.1 Career Direction (职业方向)
```swift
struct CareerDirectionData {
    let functions: [FunctionSelection]
}

struct FunctionSelection {
    let functionName: String    // 职能名称
    let learnIn: [String]       // 想要学习的子领域
    let guideIn: [String]       // 可以指导的子领域
}
```

**示例**：
```json
{
  "functions": [
    {
      "function_name": "Product Management",
      "learn_in": ["Product Strategy", "User Research"],
      "guide_in": ["Roadmap Planning"]
    }
  ]
}
```

#### 3.2 Skill Development (技能发展)
```swift
struct SkillDevelopmentData {
    let skills: [SkillSelection]
}

struct SkillSelection {
    let skillName: String
    let learnIn: Bool          // 想要学习
    let guideIn: Bool          // 可以指导
}
```

**示例**：
```json
{
  "skills": [
    {
      "skill_name": "Python",
      "learn_in": false,
      "guide_in": true
    },
    {
      "skill_name": "Machine Learning",
      "learn_in": true,
      "guide_in": false
    }
  ]
}
```

### 使用场景

#### 3.1 Mentor/Mentoring 匹配
**代码位置**: `ExploreView.swift` 第354-360行

```swift
if tokenSet.contains(where: { $0.contains("mentor") || $0.contains("mentoring") }) {
    if profile.networkingIntention.selectedIntention == .learnGrow ||
        profile.networkingIntention.selectedSubIntentions.contains(.skillDevelopment) ||
        profile.networkingIntention.selectedSubIntentions.contains(.careerDirection) {
        score += 1.5
    }
}
```

**影响**：有学习意图的用户在搜索"mentor"时排名提升

#### 3.2 技能匹配推荐
**代码位置**: `UserTowerFeatures.swift` 第521-563行

```swift
// 提取 learn_in 技能 → skillsToLearn
// 提取 guide_in 技能 → skillsToTeach
```

**用途**：推荐系统匹配"想学X的人"和"能教X的人"

#### 3.3 Mentor Score 计算
虽然不直接使用，但 `learn_in` / `guide_in` 数据会影响 `pastMentorshipCount` 的累积

---

## 4. 社交偏好特征 (Networking Preferences)

### 数据结构
**源代码**: `ProfileModels.swift` 第202-235行  
**数据库字段**: `profiles.networking_preferences` (JSONB)

### 特征列表

| 特征名 | 类型 | 必填 | 说明 | 使用场景 |
|--------|------|------|------|---------|
| `preferredChatFormat` | Enum | ✅ | 偏好形式 | 会议安排 |
| `availableTimeslot` | Object | ✅ | 可用时间段 | 时间匹配 |
| `preferredChatDuration` | String? | ❌ | 偏好时长 | 会议安排 |
| `timeslotTimezone` | String? | ❌ | 时间段时区 | 时区转换 |

### Chat Format 选项

| 值 | 说明 |
|----|------|
| `inPerson` | 线下见面 |
| `videocall` | 视频通话 |
| `phonecall` | 电话通话 |
| `textChat` | 文字聊天 |
| `flexible` | 灵活安排 |

### Available Timeslot 结构
```swift
struct AvailableTimeslot {
    let weekdayMorning: Bool    // 工作日上午
    let weekdayAfternoon: Bool  // 工作日下午
    let weekdayEvening: Bool    // 工作日晚上
    let weekendMorning: Bool    // 周末上午
    let weekendAfternoon: Bool  // 周末下午
    let weekendEvening: Bool    // 周末晚上
}
```

### 使用场景

#### 4.1 Coffee Chat 安排
**用途**: 匹配双方都可用的时间段
**流程**: 
1. 获取双方 `availableTimeslot`
2. 计算交集
3. 建议可行的会面时间

#### 4.2 推荐系统时间匹配
**用途**: 优先推荐时间兼容的用户

---

## 5. 个性与社交特征 (Personality & Social)

### 数据结构
**源代码**: `ProfileModels.swift` 第260-329行  
**数据库字段**: `profiles.personality_social` (JSONB)

### 特征列表

| 特征名 | 类型 | 必填 | 说明 | 使用场景 |
|--------|------|------|------|---------|
| `icebreakerPrompts` | [IcebreakerPrompt] | ✅ | 破冰问题 | 对话启动 |
| `valuesTags` | [String] | ✅ | 价值观标签 | 价值观匹配 |
| `hobbies` | [String] | ✅ | 爱好列表 | 兴趣匹配 |
| `preferredMeetingVibe` | Enum | ✅ | 偏好氛围 | 氛围匹配 |
| `preferredMeetingVibes` | [Enum] | ✅ | 多个氛围 | 灵活匹配 |
| `selfIntroduction` | String? | ❌ | 自我介绍 | 文本搜索 |

### Meeting Vibe 选项

| 值 | 说明 |
|----|------|
| `casualFriendly` | 轻松友好 |
| `professionalFocused` | 专业专注 |
| `inspirationalMotivating` | 鼓舞激励 |
| `deepMeaningful` | 深入有意义 |

### Icebreaker Prompt 结构
```swift
struct IcebreakerPrompt {
    let question: String    // 问题
    let answer: String      // 回答
}
```

### 使用场景

#### 5.1 Headhunting 文本搜索
```swift
// ExploreView.swift aggregatedSearchableText()
parts.append(contentsOf: profile.personalitySocial.valuesTags)
parts.append(contentsOf: profile.personalitySocial.hobbies)
parts.append(profile.personalitySocial.selfIntroduction ?? "")
```

#### 5.2 推荐系统匹配
- **价值观匹配**: 相同价值观标签增加推荐分数
- **兴趣匹配**: 共同爱好提升匹配度

#### 5.3 对话启动
**用途**: 展示破冰问题，帮助用户开始对话

---

## 6. 隐私与信任特征 (Privacy & Trust)

### 数据结构
**源代码**: `ProfileModels.swift` 第362-402行  
**数据库字段**: `profiles.privacy_trust` (JSONB)

### 特征列表

| 特征名 | 类型 | 必填 | 说明 | 使用场景 |
|--------|------|------|------|---------|
| `visibilitySettings` | Object | ✅ | 可见性设置 | 隐私控制 |
| `verifiedStatus` | Enum | ✅ | 验证状态 | 信任度、Mentor Score |
| `dataSharingConsent` | Bool | ✅ | 数据分享同意 | 合规性 |
| `reportPreferences` | Object | ✅ | 举报偏好 | 安全保障 |

### Visibility Settings 详细

```swift
struct VisibilitySettings {
    let company: VisibilityLevel
    let email: VisibilityLevel
    let phoneNumber: VisibilityLevel
    let location: VisibilityLevel
    let skills: VisibilityLevel
    let interests: VisibilityLevel
    let timeslot: VisibilityLevel
}
```

**可见性等级**:
- `public`: 所有人可见
- `connections`: 仅连接可见
- `private`: 仅自己可见

### Verified Status

| 值 | 说明 | 影响 |
|----|------|------|
| `notVerified` | 未验证 | Mentor Score 无加成 |
| `emailVerified` | 邮箱验证 | 基础信任 |
| `phoneVerified` | 电话验证 | 中等信任 |
| `verifiedProfessional` | 专业认证 | Mentor Score +25% |

### 使用场景

#### 6.1 Profile Publicness Score 计算
**代码位置**: `UserTowerFeatures.swift` 第241-280行

```swift
// 计算资料公开度（用于 Connect Score）
let visibilityScores = [
    settings.company,    // 0.0 (private) - 1.0 (public)
    settings.email,
    settings.phoneNumber,
    settings.location,
    settings.skills,
    settings.interests,
    settings.timeslot
]

profilePublicnessScore = average(visibilityScores)
```

**影响**：资料越公开，Connect Score 越高（25%权重）

#### 6.2 Mentor Score 验证加成
**代码位置**: `UserTowerFeatures.swift` 第110行

```swift
let verifiedBonus = isVerified ? 1.0 : 0.0
// 贡献到 Mentor Score: 0.25 × verifiedBonus (25%权重)
```

**影响**：已验证用户 Mentor Score 直接 +2.5分

---

## 7. 行为量化指标 (Behavioral Metrics)

### 数据结构
**源代码**: `UserTowerFeatures.swift` 第6-46行  
**数据库表**: `user_features` 表  
**数据库字段**: `behavioral_metrics` (JSONB) + 独立列

### 核心评分指标

| 指标 | 类型 | 范围 | 说明 | 计算逻辑 |
|-----|------|------|------|---------|
| `activityScore` | Int | 0-10 | 活跃度分数 | [详见 7.1](#71-activity-score-活跃度分数) |
| `connectScore` | Int | 0-10 | 连接意愿分数 | [详见 7.2](#72-connect-score-连接意愿分数) |
| `mentorScore` | Int | 0-10 | 导师潜力分数 | [详见 7.3](#73-mentor-score-导师潜力分数) |

### 原始行为数据

| 字段 | 类型 | 说明 | 更新频率 |
|-----|------|------|---------|
| `sessions7d` | Int | 7天内会话数 | 每次登录 |
| `messagesSent7d` | Int | 7天内发送消息数 | 每次发消息 |
| `matches7d` | Int | 7天内匹配数 | 每次匹配 |
| `lastActiveDays` | Int | 最后活跃距今天数 | 实时计算 |
| `responseRate30d` | Double | 30天回复率 | 每日更新 |
| `passRate` | Double | 通过推荐比率 | 每日更新 |
| `avgResponseTimeHours` | Double | 平均回复时间(小时) | 每日更新 |
| `profilePublicnessScore` | Double | 资料公开度分数 | 隐私设置变更时 |
| `pastMentorshipCount` | Int | 历史导师次数 | 手动更新 |
| `isVerified` | Bool | 是否已验证 | 验证时 |
| `isProUser` | Bool | 是否Pro用户 | 订阅变更时 |
| `seniorityLevel` | Double | 资历水平 (0-1) | 基于工作年限 |

---

### 7.1 Activity Score (活跃度分数)

**计算公式**:
```
activity_score = round(activity_raw × 10)

activity_raw = 
    30% × normalize(sessions_7d, 0→20) +
    30% × normalize(messages_sent_7d, 0→50) +
    20% × normalize(matches_7d, 0→10) +
    20% × normalize(1 / (1 + last_active_days))
```

**代码位置**: `UserTowerFeatures.swift` 第54-75行

#### 计算逻辑详解

| 组成部分 | 权重 | 归一化范围 | 说明 |
|---------|------|-----------|------|
| 7天会话数 | 30% | 0次=0.0, 20次+=1.0 | 登录频率 |
| 7天消息数 | 30% | 0条=0.0, 50条+=1.0 | 互动频率 |
| 7天匹配数 | 20% | 0个=0.0, 10个+=1.0 | 社交积极性 |
| 最后活跃 | 20% | 今天=1.0, 越久越低 | 近期活跃度 |

#### 计算示例

**高活跃用户**:
```
sessions_7d = 15
messages_sent_7d = 40
matches_7d = 8
last_active_days = 0 (今天)

activity_raw = 
    0.3 × (15/20) +      // 0.225
    0.3 × (40/50) +      // 0.240
    0.2 × (8/10) +       // 0.160
    0.2 × 1.0            // 0.200
    = 0.825

activity_score = round(0.825 × 10) = 8分
```

**低活跃用户**:
```
sessions_7d = 2
messages_sent_7d = 5
matches_7d = 0
last_active_days = 10

activity_raw = 
    0.3 × (2/20) +       // 0.030
    0.3 × (5/50) +       // 0.030
    0.2 × (0/10) +       // 0.000
    0.2 × (1/11)         // 0.018
    = 0.078

activity_score = round(0.078 × 10) = 1分
```

#### 使用场景

1. **推荐系统**: 活跃用户更可能回复
2. **Mentor Score**: 贡献15%权重
3. **用户筛选**: 过滤不活跃用户

---

### 7.2 Connect Score (连接意愿分数)

**计算公式**:
```
connect_score = round(connect_raw × 10)

connect_raw = 
    25% × profile_publicness_score +
    35% × response_rate_30d +
    15% × normalize(1 / (1 + avg_response_time_hours)) +
    15% × pass_rate +
    10% × (is_pro_user ? 1.0 : 0.0)
```

**代码位置**: `UserTowerFeatures.swift` 第77-100行

#### 计算逻辑详解

| 组成部分 | 权重 | 说明 |
|---------|------|------|
| 资料公开度 | 25% | 资料越公开，连接意愿越高 |
| 30天回复率 | 35% | 回复率越高，响应性越好 |
| 平均回复时间 | 15% | 回复越快，响应性越好 |
| 通过率 | 15% | 接受邀请的比率 |
| Pro用户加成 | 10% | Pro用户承诺更高参与度 |

#### 计算示例

**高连接意愿用户**:
```
profile_publicness_score = 0.8  (资料80%公开)
response_rate_30d = 0.9         (90%回复率)
avg_response_time_hours = 2     (2小时内回复)
pass_rate = 0.7                 (70%接受率)
is_pro_user = true

connect_raw = 
    0.25 × 0.8 +                // 0.200
    0.35 × 0.9 +                // 0.315
    0.15 × (1/(1+2)) +          // 0.050
    0.15 × 0.7 +                // 0.105
    0.10 × 1.0                  // 0.100
    = 0.770

connect_score = round(0.770 × 10) = 8分
```

**低连接意愿用户**:
```
profile_publicness_score = 0.3  (资料30%公开)
response_rate_30d = 0.3         (30%回复率)
avg_response_time_hours = 48    (48小时回复)
pass_rate = 0.2                 (20%接受率)
is_pro_user = false

connect_raw = 
    0.25 × 0.3 +                // 0.075
    0.35 × 0.3 +                // 0.105
    0.15 × (1/(1+48)) +         // 0.003
    0.15 × 0.2 +                // 0.030
    0.10 × 0.0                  // 0.000
    = 0.213

connect_score = round(0.213 × 10) = 2分
```

#### 使用场景

1. **推荐筛选**: 过滤低连接意愿用户
2. **Headhunting**: 优先推荐高连接意愿用户
3. **匹配质量**: 提高成功连接概率

---

### 7.3 Mentor Score (导师潜力分数)

**计算公式**:
```
mentor_score = round(mentor_raw × 10)

mentor_raw = 
    30% × normalize(past_mentorship_count, 0→20) +
    25% × (is_verified ? 1.0 : 0.0) +
    20% × seniority_level +
    15% × (activity_score / 10) +
    10% × 0.5  (会话评分，待扩展)
```

**代码位置**: `UserTowerFeatures.swift` 第102-122行

#### 计算逻辑详解

| 组成部分 | 权重 | 归一化范围 | 说明 |
|---------|------|-----------|------|
| 历史导师经历 | 30% | 0次=0.0, 20次+=1.0 | 过往指导经验 |
| 验证状态 | 25% | 未验证=0.0, 已验证=1.0 | 可信度加成 |
| 资历水平 | 20% | 0年=0.0, 20年+=1.0 | 工作经验 |
| 活跃度分数 | 15% | 0分=0.0, 10分=1.0 | 可获得性 |
| 会话评分 | 10% | 固定0.5 | 沟通质量（待扩展） |

#### 资历水平 (Seniority Level) 计算
```swift
// UserTowerFeatures.swift 第217-219行
let expYears = min(Double(yearsOfExperience ?? 0), 20.0)
let seniorityLevel = expYears / 20.0
```

**示例**:
- 5年经验: `seniorityLevel = 0.25`
- 10年经验: `seniorityLevel = 0.50`
- 20年+经验: `seniorityLevel = 1.00`

#### 计算示例

**资深导师型用户**:
```
past_mentorship_count = 12      (12次导师经历)
is_verified = true              (已验证)
years_of_experience = 15        (15年经验)
activity_score = 8              (活跃度8分)

seniority_level = 15/20 = 0.75

mentor_raw = 
    0.30 × (12/20) +            // 0.180
    0.25 × 1.0 +                // 0.250
    0.20 × 0.75 +               // 0.150
    0.15 × (8/10) +             // 0.120
    0.10 × 0.5                  // 0.050
    = 0.750

mentor_score = round(0.750 × 10) = 8分 ⭐⭐⭐⭐⭐⭐⭐⭐
```

**新手用户**:
```
past_mentorship_count = 0       (无导师经历)
is_verified = false             (未验证)
years_of_experience = 2         (2年经验)
activity_score = 5              (活跃度5分)

seniority_level = 2/20 = 0.10

mentor_raw = 
    0.30 × (0/20) +             // 0.000
    0.25 × 0.0 +                // 0.000
    0.20 × 0.10 +               // 0.020
    0.15 × (5/10) +             // 0.075
    0.10 × 0.5                  // 0.050
    = 0.145

mentor_score = round(0.145 × 10) = 1分 ⭐
```

#### 使用场景

1. **Headhunting Mentor匹配**: 
```swift
// 可在 ExploreView.swift 中添加
if tokenSet.contains("mentor") {
    if let mentorScore = profile.features?.behavioralMetrics?.mentorScore {
        score += Double(mentorScore) * 0.5  // 0-5分额外加分
    }
}
```

2. **推荐系统**: 筛选高质量导师
3. **用户标记**: 显示"Mentor"徽章

#### 权重设计思想

| 因素 | 权重 | 理由 |
|-----|------|------|
| 历史导师经历 | 30% | **最重要** - 直接反映指导能力 |
| 验证状态 | 25% | **可信度** - 验证用户更可靠 |
| 资历水平 | 20% | **经验积累** - 丰富经验是基础 |
| 活跃度 | 15% | **可获得性** - 活跃用户更响应 |
| 会话评分 | 10% | **质量指标** - 沟通能力体现 |

---

### 7.4 行为指标更新机制

#### 更新触发点
**代码位置**: `SupabaseService.swift` 第5564-5603行

| 活动类型 | 触发函数 | 更新字段 |
|---------|---------|---------|
| 登录 | `recordUserActivityAndUpdateMetrics` | `last_active_at` |
| 发送消息 | `sendMessage` | `messages_sent_7d` |
| 接受邀请 | `acceptInvitation` | `last_active_at` |
| 匹配成功 | `createMatch` | `matches_7d` |

#### 更新流程
```swift
// 1. 更新最后活跃时间
try await client
    .from("user_features")
    .update(["last_active_at": Date().ISO8601Format()])
    .eq("user_id", value: userId)
    .execute()

// 2. 异步重新计算行为指标（可选）
// 注：目前通过定时任务批量计算
```

---

## 8. 推荐系统特征 (Two-Tower Features)

### 数据结构
**源代码**: `UserTowerFeatures.swift` 第306-640行  
**数据库表**: `user_features` 表

### 特征分类

#### 8.1 稀疏特征 (Categorical)

| 特征 | 类型 | 来源 | 编码方式 |
|-----|------|------|---------|
| `location` | String? | `coreIdentity.location` | One-hot / Embedding |
| `timeZone` | String? | `coreIdentity.timeZone` | One-hot |
| `industry` | String? | `professionalBackground.industry` | One-hot / Embedding |
| `experienceLevel` | String? | `professionalBackground.experienceLevel` | Ordinal |
| `careerStage` | String? | `professionalBackground.careerStage` | One-hot |
| `mainIntention` | String? | `networkingIntention.selectedIntention` | One-hot |

#### 8.2 多值特征 (Multi-valued)

| 特征 | 类型 | 来源 | 编码方式 |
|-----|------|------|---------|
| `skills` | [String] | `professionalBackground.skills` | Multi-hot |
| `hobbies` | [String] | `personalitySocial.hobbies` | Multi-hot |
| `values` | [String] | `personalitySocial.valuesTags` | Multi-hot |
| `languages` | [String] | `professionalBackground.languagesSpoken` | Multi-hot |
| `subIntentions` | [String] | `networkingIntention.selectedSubIntentions` | Multi-hot |

#### 8.3 配对特征 (Matching)

| 特征 | 类型 | 来源 | 用途 |
|-----|------|------|------|
| `skillsToLearn` | [String] | `skillDevelopment.learnIn` | 学习需求匹配 |
| `skillsToTeach` | [String] | `skillDevelopment.guideIn` | 教学能力匹配 |

**提取逻辑**:
```swift
// UserTowerFeatures.swift 第521-563行
guard let skills = profile.networkingIntention.skillDevelopment?.skills else {
    return ([], [])
}

var skillsToLearn: [String] = []
var skillsToTeach: [String] = []

for skill in skills {
    if skill.learnIn {
        skillsToLearn.append(skill.skillName)
    }
    if skill.guideIn {
        skillsToTeach.append(skill.skillName)
    }
}
```

#### 8.4 数值特征 (Numerical)

| 特征 | 类型 | 范围 | 来源 |
|-----|------|------|------|
| `yearsOfExperience` | Double | 0-∞ | `professionalBackground.yearsOfExperience` |
| `profileCompletion` | Double | 0.0-1.0 | 计算得出 |
| `isVerified` | Int | 0/1 | `privacyTrust.verifiedStatus` |

**Profile Completion 计算**:
```swift
// 统计所有非空字段占比
let filledFields = countNonEmptyFields(profile)
let totalFields = countTotalFields()
profileCompletion = Double(filledFields) / Double(totalFields)
```

---

### 8.5 Two-Tower 推荐系统架构

**代码位置**: `SimpleTwoTowerEncoder.swift`

#### User Tower (用户塔)
```
输入: UserTowerFeatures
  ↓
稀疏特征 Embedding (location, industry, etc.)
  ↓
多值特征 Mean Pooling (skills, hobbies, etc.)
  ↓
数值特征标准化
  ↓
全连接层 [128] → ReLU
  ↓
输出: 64维用户向量
```

#### Candidate Tower (候选塔)
```
输入: UserTowerFeatures (候选用户)
  ↓
同样的编码过程
  ↓
输出: 64维候选向量
```

#### 相似度计算
```swift
// SimpleTwoTowerEncoder.swift 第223-233行
func similarity(user: Vector, candidate: Vector) -> Double {
    // 1. 余弦相似度
    let dotProduct = zip(user, candidate).map(*).reduce(0, +)
    let userNorm = sqrt(user.map { $0 * $0 }.reduce(0, +))
    let candidateNorm = sqrt(candidate.map { $0 * $0 }.reduce(0, +))
    let cosineSim = dotProduct / (userNorm * candidateNorm)
    
    // 2. 行为指标加成
    let activityBonus = (userActivityScore + candidateActivityScore) / 20.0
    let connectBonus = (userConnectScore + candidateConnectScore) / 20.0
    
    return cosineSim * 0.7 + activityBonus * 0.15 + connectBonus * 0.15
}
```

---

## 特征使用场景总结

### Headhunting 搜索

| 查询关键词 | 匹配特征 | 加分规则 | 代码位置 |
|-----------|---------|---------|---------|
| 通用关键词 | 所有文本字段 | +1.0/词 | ExploreView.swift:339-344 |
| 数字（工作年限） | `yearsOfExperience` | +2.0 | ExploreView.swift:346-352 |
| "alumni" | `educations.schoolName` | +1.0基础 +5.0同校 | ExploreView.swift:362-392 |
| "mentor" | `networkingIntention` | +1.5 | ExploreView.swift:354-360 |
| "founder" | `careerStage` | +1.0 | ExploreView.swift:394-399 |

### 推荐系统

| 场景 | 使用特征 | 权重/影响 |
|-----|---------|----------|
| 基础推荐 | Two-Tower Features | 余弦相似度 70% |
| 行为加成 | Activity + Connect Score | 15% + 15% |
| 技能匹配 | skillsToLearn ↔ skillsToTeach | 高优先级 |
| 地理筛选 | location | 硬过滤 |
| 时间匹配 | availableTimeslot | 硬过滤 |

### 用户筛选

| 筛选条件 | 特征 | 阈值 |
|---------|------|------|
| 活跃用户 | `activityScore` | ≥ 3 |
| 愿意连接 | `connectScore` | ≥ 3 |
| 导师资格 | `mentorScore` | ≥ 5 |
| 验证用户 | `isVerified` | = 1 |
| Pro用户 | `isProUser` | = true |

### 展示排序

| 场景 | 排序依据 | 公式 |
|-----|---------|------|
| Matches列表 | 最近匹配时间 | `ORDER BY created_at DESC` |
| Headhunting | 混合分数 | `0.3×推荐分 + 1.0×文本分` |
| Requests | 最近请求时间 | `ORDER BY created_at DESC` |

---

## API 获取方式

### 获取完整 Profile
```swift
// SupabaseService.swift
let profile = try await supabaseService.getProfile(userId: userId)

// 访问各部分特征
let name = profile.coreIdentity.name
let skills = profile.professionalBackground.skills
let intention = profile.networkingIntention.selectedIntention
```

### 获取行为指标
```swift
// SupabaseService.swift 第5505行
let (activity, connect, mentor) = try await supabaseService.getUserBehavioralMetrics(userId: userId)
```

### 获取推荐特征
```swift
// 从 user_features 表查询
let features = try await getUserTowerFeatures(userId: userId)
```

---

## 数据库Schema

### profiles 表
```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY,
    user_id UUID UNIQUE REFERENCES users(id),
    core_identity JSONB NOT NULL,
    professional_background JSONB NOT NULL,
    networking_intention JSONB NOT NULL,
    networking_preferences JSONB NOT NULL,
    personality_social JSONB NOT NULL,
    work_photos JSONB,
    lifestyle_photos JSONB,
    privacy_trust JSONB NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

### user_features 表
```sql
CREATE TABLE user_features (
    id UUID PRIMARY KEY,
    user_id UUID UNIQUE REFERENCES users(id),
    
    -- 稀疏特征
    location TEXT,
    time_zone TEXT,
    industry TEXT,
    experience_level TEXT,
    career_stage TEXT,
    main_intention TEXT,
    
    -- 多值特征 (JSONB数组)
    skills JSONB DEFAULT '[]',
    hobbies JSONB DEFAULT '[]',
    values JSONB DEFAULT '[]',
    languages JSONB DEFAULT '[]',
    sub_intentions JSONB DEFAULT '[]',
    skills_to_learn JSONB DEFAULT '[]',
    skills_to_teach JSONB DEFAULT '[]',
    
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
    last_active_at TIMESTAMP,
    
    -- 行为指标详情 (JSONB)
    behavioral_metrics JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

---

## 维护与更新

### 新增特征流程

1. **定义数据模型**
   - 在 `ProfileModels.swift` 或 `UserTowerFeatures.swift` 中添加新字段
   - 更新 `CodingKeys` 枚举

2. **更新数据库Schema**
   - 修改 `profiles` 表的JSONB字段
   - 或在 `user_features` 表添加新列

3. **更新计算逻辑**
   - 如果是计算型特征，在相应计算函数中添加逻辑
   - 更新权重配置

4. **更新使用场景**
   - 在 Headhunting、推荐系统等模块中集成新特征
   - 测试性能影响

5. **更新文档**
   - 在本文档中添加新特征说明
   - 更新计算逻辑和使用场景

### 特征优化建议

1. **行为指标**
   - 实现会话评分系统（目前固定0.5）
   - 添加更细粒度的活跃度追踪
   - 考虑时间衰减因子

2. **推荐系统**
   - A/B测试不同权重配置
   - 添加负反馈机制（拒绝/举报）
   - 实现在线学习更新

3. **Headhunting**
   - 添加更多语义理解
   - 支持自然语言查询
   - 实现查询扩展（同义词）

---

## 联系与反馈

如有疑问或建议，请联系：
- **技术负责人**: BrewNet Dev Team Heady
- **文档维护**: 本文档随代码更新而更新

---

**文档版本**: 1.0  
**最后更新**: 2024-11-21  
**适用代码版本**: nlp branch

