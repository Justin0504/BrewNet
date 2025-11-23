# 信誉评分系统实现文档

## 📋 实施概况

已成功实现完整的信誉评分系统，包括评分计算、等级管理、UI界面和举报机制。

## ✅ 已完成的核心功能

### 1. 数据模型和评分逻辑 (`CredibilitySystem.swift`)

#### 信誉等级系统
- **9个等级**：从 Highly Trusted (4.6-5.0) 到 Banned (0-0.5)
- **动态权益**：
  - Highly Trusted: 匹配权重 +60%, PRO 7折, 每月30%用户免费PRO
  - Well Trusted: 匹配权重 +30%, PRO 8折, 每月30%用户10天免费PRO
  - Trusted: 匹配权重 +10%, PRO 9折
  - Alert: 匹配权重 -30%, 每日右划限制3人
  - Low Trust: 匹配权重 -60%, 每日右划限制1人, 需重新认证
  - Critical: 账号冻结72小时, 匹配权重 -60%

#### 评分计算公式
```
最终评分 = 0.7 × 平均星级评分 + 0.3 × 履约率得分

履约率 = (总见面次数 - 放鸽子次数) / 总见面次数 × 100%
```

#### 履约率转评分映射
- 95-100% → 5.0分
- 90-95% → 4.5分
- 85-90% → 4.0分
- 80-85% → 3.5分
- 70-80% → 3.0分
- 60-70% → 2.5分
- 以此类推...

#### 评分衰减机制
**目的**：逼用户持续线下见面，保持社区活跃

**规则**：
- 15天未见面开始衰减
- 越高分衰减越快：
  - 4.5-5.0分：每天衰减 0.08分
  - 4.0-4.5分：每天衰减 0.06分
  - 3.5-4.0分：每天衰减 0.04分
  - 3.0-3.5分：每天衰减 0.03分
  - 2.5-3.0分：每天衰减 0.02分
  - <2.5分：每天衰减 0.01分

### 2. 评分UI界面 (`MeetingRatingView.swift`)

#### 核心功能
- **星级评分滑块**：0.5-5.0分，0.5为最小单位
- **实时视觉反馈**：星星填充动画，颜色根据评分变化
- **评分参考指南**：
  - 5.0★ Excellent — 非常有价值的对话
  - 4.0★ Good — 流畅且有见地
  - 3.0★ Fair — 平均体验
  - 2.0★ Poor — 低于预期
  - 1.0★ Very Poor — 不会再见面
  - 0.5★ Unacceptable — 严重负面体验

#### 可选标签系统
**正面标签**：
- Professional and helpful
- Friendly and respectful
- On time
- Will stay in touch

**中性标签**：
- Conversation didn't fully align
- Limited information shared
- Brief meeting

**负面标签（非不当行为）**：
- Late or rescheduled last-minute
- Unfocused or disengaged
- Not respectful of the conversation flow

#### 举报入口
- 清晰的不当行为类型列表
- 警告说明：举报成功后的后果
- 一键进入举报流程

### 3. 举报系统 (`MisconductReportView.swift`)

#### 不当行为类型（按严重程度排序）
1. **Violence** (严重度5)：暴力、威胁或恐吓
2. **Sexual Harassment** (严重度5)：性骚扰或不当身体接触
3. **Stalking** (严重度4)：跟踪或侵犯隐私
4. **Fraud** (严重度3)：欺诈、冒充或强制推销
5. **Other** (严重度2)：其他严重不当行为

#### 举报流程
1. **选择不当行为类型**：显示严重度等级
2. **描述事件**（必填）：详细说明发生的情况
3. **位置信息**（可选）：见面地点
4. **上传证据**（可选）：截图、照片等
5. **是否需要跟进**：Safety Team是否联系

#### 防误报机制
- 警告框：虚假举报将导致账号封禁
- 区分普通不满（用常规评分）vs 严重不当行为（用举报系统）

#### 举报成功页面
- 绿色对勾确认
- 说明审核时间：24-48小时
- 列出后续步骤
- 紧急情况指引：联系当地警方

#### 举报验证后的处罚
- 被举报者评分重置为 0.0
- 账号永久封禁
- 从所有匹配池中移除
- 举报者不会再被匹配到

### 4. 信誉徽章显示 (`CredibilityBadgeView.swift`)

#### 紧凑模式（用于卡片）
- 等级图标 + 评分 + 徽章（VIP/Trusted/!）
- 颜色编码：绿色（高信誉）、蓝色（正常）、黄色（警告）、红色（低信誉）

#### 详细模式（用于个人主页）
- **大型评分显示**：图标 + 分数 + 等级名称
- **权益说明**：匹配加成、PRO折扣、特殊福利
- **评分构成**：
  - 平均星级（70%权重）
  - 履约率（30%权重）
  - 总见面次数
  - 放鸽子次数
- **状态警告**：
  - 账号冻结提示 + 解冻日期
  - 永久封禁提示 + 原因
  - 衰减警告（10天未见面开始提示）

#### 衰减提醒
- **10-14天**：橙色警告，"还有X天开始衰减"
- **15天以上**：红色警告，"已衰减X天，尽快见面维持评分！"

## 🔐 反作弊机制

### GPS验证（需后端支持）
1. 双方在APP内点击"WE MET"
2. GPS距离 <50m 且持续 ≥5分钟
3. 检测异常跳点（防GPS欺诈）
4. 一年内2次GPS异常 → 直接扣1分

### 互刷分检测（需后端支持）
- 检测长期互相刷分（超过5次互评满分）
- 惩罚：
  - 打断刷分连结
  - 当前分数锁定60天
  - 匹配权重 -50%

## 📊 数据模型结构

### CredibilityScore
```swift
- userId: String
- overallScore: Double (0-5)
- averageRating: Double (0-5)
- fulfillmentRate: Double (0-100)
- totalMeetings: Int
- totalNoShows: Int
- lastMeetingDate: Date?
- tier: CredibilityTier
- isFrozen: Bool
- freezeEndDate: Date?
- isBanned: Bool
- banReason: String?
- gpsAnomalyCount: Int
- mutualHighRatingCount: Int
- lastDecayDate: Date?
```

### MeetingRating
```swift
- id: UUID
- meetingId: String
- raterId: String
- ratedUserId: String
- rating: Double (0.5-5.0)
- tags: [RatingTag]
- timestamp: Date
- gpsVerified: Bool
- meetingDuration: TimeInterval
```

### MisconductReport
```swift
- id: UUID
- reporterId: String
- reportedUserId: String
- meetingId: String?
- misconductType: MisconductType
- description: String
- location: String?
- evidence: [String]?
- needsFollowUp: Bool
- timestamp: Date
- status: ReportStatus
- reviewNotes: String?
- reviewedAt: Date?
- reviewedBy: String?
```

## 🔄 需要后端支持的功能

### 1. 数据库表设计
```sql
-- 信誉评分表
CREATE TABLE credibility_scores (
    user_id UUID PRIMARY KEY,
    overall_score DECIMAL(2,1) DEFAULT 3.0,
    average_rating DECIMAL(2,1) DEFAULT 3.0,
    fulfillment_rate DECIMAL(5,2) DEFAULT 100.0,
    total_meetings INT DEFAULT 0,
    total_no_shows INT DEFAULT 0,
    last_meeting_date TIMESTAMP,
    tier VARCHAR(50) DEFAULT 'Normal',
    is_frozen BOOLEAN DEFAULT FALSE,
    freeze_end_date TIMESTAMP,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    gps_anomaly_count INT DEFAULT 0,
    mutual_high_rating_count INT DEFAULT 0,
    last_decay_date TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 评分记录表
CREATE TABLE meeting_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meeting_id UUID NOT NULL,
    rater_id UUID NOT NULL,
    rated_user_id UUID NOT NULL,
    rating DECIMAL(2,1) NOT NULL,
    tags JSONB,
    timestamp TIMESTAMP DEFAULT NOW(),
    gps_verified BOOLEAN DEFAULT FALSE,
    meeting_duration INT, -- 秒
    FOREIGN KEY (rater_id) REFERENCES users(id),
    FOREIGN KEY (rated_user_id) REFERENCES users(id)
);

-- 举报记录表
CREATE TABLE misconduct_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL,
    reported_user_id UUID NOT NULL,
    meeting_id UUID,
    misconduct_type VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    location TEXT,
    evidence JSONB,
    needs_follow_up BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'Pending Review',
    review_notes TEXT,
    reviewed_at TIMESTAMP,
    reviewed_by UUID,
    FOREIGN KEY (reporter_id) REFERENCES users(id),
    FOREIGN KEY (reported_user_id) REFERENCES users(id),
    FOREIGN KEY (reviewed_by) REFERENCES users(id)
);

-- 索引
CREATE INDEX idx_credibility_tier ON credibility_scores(tier);
CREATE INDEX idx_credibility_score ON credibility_scores(overall_score DESC);
CREATE INDEX idx_meeting_ratings_user ON meeting_ratings(rated_user_id);
CREATE INDEX idx_reports_status ON misconduct_reports(status);
```

### 2. API端点

#### 评分相关
- `POST /api/meetings/{id}/rate` - 提交评分
- `GET /api/users/{id}/credibility` - 获取用户信誉评分
- `POST /api/meetings/{id}/confirm` - 确认见面（GPS验证）

#### 举报相关
- `POST /api/reports/misconduct` - 提交举报
- `GET /api/reports/{id}` - 查看举报状态
- `POST /api/reports/{id}/review` - 审核举报（管理员）

#### 定时任务
- 每日执行评分衰减计算
- 检测互刷分行为
- 自动解冻到期账号

### 3. GPS验证逻辑（后端）
```python
def verify_meeting_gps(meeting_id, user1_location, user2_location, duration):
    # 计算距离
    distance = calculate_distance(user1_location, user2_location)
    
    # 检查距离和时长
    if distance < 50 and duration >= 300:  # 50米内，5分钟以上
        # 检查异常跳点
        if detect_gps_anomaly(user1_location, user2_location):
            increment_gps_anomaly_count(user1_id)
            increment_gps_anomaly_count(user2_id)
            return False
        return True
    return False
```

### 4. 互刷分检测（后端）
```python
def detect_mutual_rating_abuse(user1_id, user2_id):
    # 查询双方互评满分的次数
    mutual_high_ratings = count_mutual_high_ratings(user1_id, user2_id)
    
    if mutual_high_ratings > 5:
        # 打断刷分连结
        block_future_ratings(user1_id, user2_id)
        
        # 锁定分数60天
        lock_score(user1_id, days=60)
        lock_score(user2_id, days=60)
        
        # 匹配权重惩罚
        apply_matching_penalty(user1_id, -0.5)
        apply_matching_penalty(user2_id, -0.5)
```

### 5. 每日衰减任务（后端）
```python
def daily_score_decay():
    # 获取所有超过15天未见面的用户
    users = get_users_with_old_last_meeting(days=15)
    
    for user in users:
        days_since = days_between(user.last_meeting_date, today())
        new_score = CredibilityCalculator.apply_decay(
            user.overall_score, 
            days_since
        )
        
        update_user_score(user.id, new_score)
        user.last_decay_date = today()
```

## 🎯 匹配算法集成

### 修改 RecommendationService.swift
```swift
// 在 calculateSimilarity 函数中添加信誉权重
func calculateSimilarity(user: UserProfile, candidate: BrewNetProfile) -> Double {
    // ... 现有相似度计算 ...
    
    // 信誉加成
    let credibilityBoost = candidate.credibilityScore.tier.matchingWeightMultiplier
    
    return baseSimilarity * credibilityBoost
}
```

### 修改 ExploreView.swift
```swift
// 检查每日右划限制
func canSwipeRight() -> Bool {
    guard let limit = currentUser.credibilityScore.tier.dailySwipeLimit else {
        return true // 无限制
    }
    return todaySwipeCount < limit
}
```

## 📱 UI集成示例

### 在个人主页显示信誉徽章
```swift
// UserProfileView.swift
VStack {
    // ... 现有内容 ...
    
    CredibilityBadgeView(
        score: userProfile.credibilityScore,
        showDetails: true
    )
}
```

### 在卡片上显示简化徽章
```swift
// UserProfileCardView.swift
HStack {
    Text(profile.name)
    
    CredibilityBadgeView(
        score: profile.credibilityScore,
        showDetails: false
    )
}
```

### 见面后触发评分
```swift
// CoffeeChatView.swift
Button("We Met!") {
    showRatingSheet = true
}
.sheet(isPresented: $showRatingSheet) {
    MeetingRatingView(
        meetingId: meeting.id,
        otherUserId: otherUser.id,
        otherUserName: otherUser.name
    )
}
```

## 🚀 PRO会员折扣集成

### 修改 BrewNetProView.swift
```swift
// 根据信誉等级显示折扣价格
var proPrice: Double {
    let basePrice = 9.99
    let discount = currentUser.credibilityScore.tier.proDiscount
    return basePrice * discount
}

// 显示折扣信息
if discount < 1.0 {
    Text("\(Int((1-discount)*100))% OFF for \(tier.rawValue) users!")
        .foregroundColor(.green)
}
```

### 免费PRO抽奖（后端定时任务）
```python
def monthly_pro_lottery():
    # Highly Trusted: 30%用户抽取免费PRO
    highly_trusted = get_users_by_tier("Highly Trusted")
    winners_1 = random.sample(highly_trusted, k=len(highly_trusted)*0.3)
    for winner in winners_1:
        grant_pro_membership(winner.id, days=30)
    
    # Well Trusted: 30%用户抽取10天免费PRO
    well_trusted = get_users_by_tier("Well Trusted")
    winners_2 = random.sample(well_trusted, k=len(well_trusted)*0.3)
    for winner in winners_2:
        grant_pro_membership(winner.id, days=10)
```

## 📝 用户引导文案

### 首次评分引导
```
"BrewNet的信誉评分系统帮助我们维护一个专业、安全、高质量的社交环境。

你的评分将影响对方的：
✅ 匹配优先级
✅ PRO会员折扣
✅ 账号状态

请客观公正地评价你的见面体验。"
```

### 信誉等级说明页面
```
📊 信誉等级系统

你的信誉评分由两部分组成：
• 70% 对方给你的星级评分
• 30% 你的履约率（见面次数 vs 放鸽子次数）

保持高信誉的方法：
1️⃣ 准时赴约，不放鸽子
2️⃣ 专业友好的交流态度
3️⃣ 每15天至少见面一次（防止评分衰减）

高信誉的好处：
🌟 Highly Trusted (4.6-5.0)
   • 匹配优先级 +60%
   • PRO会员 30% off
   • 每月30%概率免费获得PRO

✨ Well Trusted (4.1-4.5)
   • 匹配优先级 +30%
   • PRO会员 20% off
   • 每月30%概率获得10天免费PRO

👍 Trusted (3.6-4.0)
   • 匹配优先级 +10%
   • PRO会员 10% off
```

## ⚠️ 注意事项

### 1. 隐私保护
- 评分标签不公开显示，仅用于内部分析
- 举报信息严格保密
- 只显示最终评分和等级

### 2. 用户体验
- 默认起点3.0分（公平起点）
- 衰减机制有提前10天的警告期
- 低分用户有明确的改进路径

### 3. 安全考虑
- 严重不当行为举报有独立入口
- 验证后立即封禁，保护社区安全
- 防误报机制，避免恶意举报

### 4. 技术债务
- GPS验证需要持续定位权限（可能影响电池）
- 互刷分检测需要复杂的关系图分析
- 大规模用户的衰减计算需要优化性能

## 🎉 总结

信誉评分系统已完整实现所有前端组件：
✅ 数据模型和计算逻辑
✅ 评分UI界面（星级、标签、举报）
✅ 举报系统（类型、流程、确认）
✅ 信誉徽章显示（紧凑/详细模式）
✅ 等级权益系统（匹配加成、PRO折扣）
✅ 衰减和冻结机制

**下一步**：需要后端团队实现数据库表、API端点、GPS验证、定时任务等功能。

