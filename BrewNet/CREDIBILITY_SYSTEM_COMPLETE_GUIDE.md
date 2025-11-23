# BrewNet 信誉评分系统 (Credibility System) 完整指南

## 系统概述

**信誉评分系统**是 BrewNet 的核心信任机制，通过量化用户的见面行为和评分来建立社区信任度。

---

## 一、核心概念

### 1. **credibility_scores 表**

存储每个用户的信誉评分数据，包括：
- **overall_score** (0-5): 最终综合评分
- **average_rating** (0-5): 平均星级评分
- **fulfillment_rate** (0-100%): 履约率（是否按时见面）
- **tier**: 信誉等级（9个等级）
- **total_meetings**: 总见面次数
- **total_no_shows**: 放鸽子次数
- **is_frozen**: 是否冻结
- **is_banned**: 是否封禁

### 2. **评分计算公式**

```
最终评分 = 70% × 平均评分 + 30% × 履约率得分
```

**示例**:
- 平均评分: 4.5 星
- 履约率: 95% → 履约率得分: 5.0
- 最终评分 = 0.7 × 4.5 + 0.3 × 5.0 = 4.65

---

## 二、信誉等级 (Tier)

### 9 个等级及其影响

| 等级 | 评分范围 | 匹配权重 | 每日右划限制 | Pro 折扣 | 图标 |
|------|---------|---------|-------------|---------|------|
| **Highly Trusted** | 4.6-5.0 | +60% | 无限制 | 7折 | ⭐ |
| **Well Trusted** | 4.1-4.5 | +30% | 无限制 | 8折 | ✅ |
| **Trusted** | 3.6-4.0 | +10% | 无限制 | 9折 | ✓ |
| **Normal** | 2.6-3.5 | 0% | 无限制 | 无 | ○ |
| **Needs Improvement** | 2.1-2.5 | -10% | 无限制 | 无 | ⚠️ |
| **Alert** | 1.6-2.0 | -30% | 3次/天 | 无 | ⚠️ |
| **Low Trust** | 1.1-1.5 | -60% | 1次/天 | 无 | ❌ |
| **Critical** | 0.6-1.0 | -60% | 1次/天 | 无 | 🚨 |
| **Banned** | 0-0.5 | 0% | 0次 | 无 | 🚫 |

---

## 三、评分计算逻辑

### 1. **平均评分 (Average Rating)**

**来源**: `meeting_ratings` 表中所有对该用户的评分

**计算**:
```sql
SELECT AVG(rating) FROM meeting_ratings WHERE rated_user_id = user_id
```

**默认值**: 3.0（新用户）

**更新时机**: 每次有新评分提交时自动更新

---

### 2. **履约率 (Fulfillment Rate)**

**计算公式**:
```
履约率 = (总见面次数 - 放鸽子次数) / 总见面次数 × 100%
```

**示例**:
- 总见面: 10 次
- 放鸽子: 1 次
- 履约率 = (10 - 1) / 10 × 100% = 90%

**默认值**: 100%（新用户，无见面记录）

**更新时机**: 
- 见面完成时: `total_meetings + 1`
- 标记为放鸽子时: `total_no_shows + 1`

---

### 3. **履约率转评分**

将履约率 (0-100%) 转换为 0-5 分：

| 履约率 | 得分 |
|--------|------|
| 95-100% | 5.0 |
| 90-94% | 4.5 |
| 85-89% | 4.0 |
| 80-84% | 3.5 |
| 70-79% | 3.0 |
| 60-69% | 2.5 |
| 50-59% | 2.0 |
| 40-49% | 1.5 |
| 30-39% | 1.0 |
| <30% | 0.5 |

---

### 4. **最终评分计算**

```swift
// 来自 CredibilityCalculator.swift
let overallScore = 0.7 * averageRating + 0.3 * fulfillmentScore
```

**权重说明**:
- **70% 平均评分**: 更重视用户的实际表现（见面质量）
- **30% 履约率**: 确保用户可靠（是否按时见面）

---

## 四、评分衰减机制

### 衰减规则

**触发条件**: 15 天未见面

**衰减速度** (按当前评分):
- **4.5-5.0**: 每天 -0.08 分（高分衰减最快）
- **4.0-4.5**: 每天 -0.06 分
- **3.5-4.0**: 每天 -0.04 分
- **3.0-3.5**: 每天 -0.03 分
- **2.5-3.0**: 每天 -0.02 分
- **<2.5**: 每天 -0.01 分（低分衰减最慢）

**目的**: 鼓励用户保持活跃，高分用户需要更频繁见面来维持评分

---

## 五、系统在应用中的使用

### 1. **用户资料卡片显示** (`UserProfileCardView.swift`)

**位置**: 头像右上角

**显示内容**:
- 平均评分徽章 (`RatingBadgeView`)
- 评分数值（如 "4.5"）

**代码位置**:
```swift
// 第 322-325 行
if let score = credibilityScore {
    RatingBadgeView(rating: score.averageRating, size: .small)
        .offset(x: 8, y: -8)
}
```

---

### 2. **资料详情页显示** (`ProfileDisplayView.swift`)

**位置**: 用户资料展开页面

**显示内容**:
- 完整信誉徽章 (`CredibilityBadgeView`)
- 评分详情（平均评分、履约率、总见面次数）
- 等级徽章和权益说明
- 衰减警告（如果 15 天未见面）

**代码位置**:
```swift
// 第 1942 行
@State private var credibilityScore: CredibilityScore?

// 显示完整徽章
CredibilityBadgeView(score: credibilityScore, showDetails: true)
```

---

### 3. **匹配推荐系统** (`ExploreView.swift`)

**作用**: 影响推荐排序

**逻辑**:
```swift
// 来自 CredibilitySystem.swift 第 88-99 行
var matchingWeightMultiplier: Double {
    switch tier {
    case .highlyTrusted: return 1.6      // +60%
    case .wellTrusted: return 1.3        // +30%
    case .trusted: return 1.1            // +10%
    case .normal: return 1.0             // 0%
    case .needsImprovement: return 0.9   // -10%
    case .alert: return 0.7              // -30%
    case .lowTrust, .critical: return 0.4 // -60%
    case .banned: return 0.0             // 封禁
    }
}
```

**应用**: 在计算推荐分数时，将信誉等级作为权重因子

---

### 4. **见面评分功能** (`MeetingRatingView.swift`)

**功能**: 用户见面后可以互相评分

**评分内容**:
- 星级评分 (0.5-5.0)
- 标签选择（正面/中性/负面）
- 评论（可选）
- GPS 验证（是否真的见面）

**提交后**:
- 自动更新 `meeting_ratings` 表
- 触发器自动调用 `calculate_credibility_score()` 函数
- 更新被评分用户的信誉评分

---

### 5. **举报功能** (`MisconductReportView.swift`)

**功能**: 用户可以举报不当行为

**举报类型**:
- 暴力、威胁或恐吓
- 性骚扰或不当身体接触
- 跟踪或侵犯隐私
- 欺诈、冒充或强制销售
- 其他严重不当行为

**影响**: 严重举报可能导致账户冻结或封禁

---

## 六、数据库自动更新机制

### 1. **新用户自动创建记录**

**触发器**: `on_auth_user_created_create_credibility`

**位置**: `auth.users` 表

**功能**: 当新用户注册时，自动在 `credibility_scores` 表中创建默认记录

**SQL**:
```sql
CREATE TRIGGER on_auth_user_created_create_credibility
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_credibility_score_for_new_user();
```

**默认值**:
- `overall_score = 3.0`
- `average_rating = 3.0`
- `fulfillment_rate = 100.0`
- `tier = 'Normal'`

---

### 2. **评分提交后自动更新**

**触发器**: `after_rating_insert`

**位置**: `meeting_ratings` 表

**功能**: 当有新评分提交时，自动重新计算被评分用户的信誉评分

**SQL**:
```sql
CREATE TRIGGER after_rating_insert
    AFTER INSERT ON meeting_ratings
    FOR EACH ROW
    EXECUTE FUNCTION on_rating_submitted();
```

**执行流程**:
```
用户提交评分
  ↓
插入到 meeting_ratings 表
  ↓
触发器触发
  ↓
调用 calculate_credibility_score() 函数
  ↓
重新计算 overall_score, average_rating, tier
  ↓
更新 credibility_scores 表
```

---

### 3. **见面完成统计更新**

**函数**: `mark_meeting_completed()`

**功能**: 标记见面完成，更新双方统计

**更新内容**:
- `total_meetings + 1`
- `last_meeting_date = NOW()`
- 重新计算双方的信誉评分

---

## 七、缓存机制

### CredibilityScoreCache

**位置**: `CredibilitySystem.swift` 第 5-47 行

**功能**: 缓存信誉评分，减少数据库查询

**缓存时间**: 5 分钟

**使用场景**:
- 用户资料卡片快速显示
- 避免频繁查询数据库
- 后台自动刷新缓存

**代码示例**:
```swift
// 从缓存获取
if let cachedScore = CredibilityScoreCache.shared.getScore(for: userId) {
    // 使用缓存
} else {
    // 从数据库查询
    let score = try await supabaseService.getCredibilityScore(userId: userId)
    // 保存到缓存
    CredibilityScoreCache.shared.setScore(score, for: userId)
}
```

---

## 八、完整数据流

### 用户注册流程

```
1. 用户注册
   ↓
2. auth.signUp() 创建 auth.users 记录
   ↓
3. 触发器: on_auth_user_created_create_credibility
   ↓
4. 自动创建 credibility_scores 记录（默认值）
   ↓
5. service.createUser() 创建 public.users 记录
   ↓
✅ 注册完成，用户有默认信誉评分 3.0
```

---

### 见面评分流程

```
1. 用户 A 和用户 B 见面
   ↓
2. 见面完成后，双方可以互相评分
   ↓
3. 用户 A 提交对用户 B 的评分
   ↓
4. 插入到 meeting_ratings 表
   ↓
5. 触发器: after_rating_insert
   ↓
6. 调用 calculate_credibility_score(userB_id)
   ↓
7. 重新计算用户 B 的:
   - average_rating (从所有评分计算)
   - fulfillment_rate (从见面统计计算)
   - overall_score (70% × rating + 30% × fulfillment)
   - tier (根据 overall_score 确定)
   ↓
8. 更新 credibility_scores 表
   ↓
9. 清除缓存，通知 UI 更新
   ↓
✅ 用户 B 的信誉评分已更新
```

---

## 九、系统影响

### 1. **匹配推荐**

**高信誉用户**:
- 在推荐列表中排名更靠前
- 获得更多曝光机会
- 更容易被其他用户看到

**低信誉用户**:
- 排名下降
- 曝光减少
- 可能被限制每日右划次数

---

### 2. **用户行为**

**鼓励**:
- ✅ 按时见面（提高履约率）
- ✅ 获得好评（提高平均评分）
- ✅ 保持活跃（避免评分衰减）

**惩罚**:
- ❌ 放鸽子（降低履约率）
- ❌ 获得差评（降低平均评分）
- ❌ 长期不活跃（评分衰减）

---

### 3. **Pro 订阅激励**

**高信誉用户特权**:
- Highly Trusted: Pro 7折
- Well Trusted: Pro 8折
- Trusted: Pro 9折

**目的**: 鼓励用户维护高信誉，获得经济激励

---

## 十、关键文件位置

### Swift 代码

| 文件 | 功能 | 关键位置 |
|------|------|---------|
| `CredibilitySystem.swift` | 核心逻辑、数据模型 | 第 49-541 行 |
| `CredibilityBadgeView.swift` | UI 显示组件 | 完整文件 |
| `SupabaseService.swift` | 数据库查询 | 第 5809-5840 行 |
| `UserProfileCardView.swift` | 卡片显示评分 | 第 1212-1283 行 |
| `ProfileDisplayView.swift` | 详情页显示 | 第 1942-1986 行 |
| `MeetingRatingView.swift` | 评分提交界面 | 完整文件 |
| `MisconductReportView.swift` | 举报界面 | 完整文件 |

### SQL 脚本

| 文件 | 功能 |
|------|------|
| `create_credibility_system_tables.sql` | 创建表、触发器、函数 |

---

## 十一、常见问题

### Q1: 新用户为什么没有信誉评分？

**A**: 新用户注册时，触发器 `on_auth_user_created_create_credibility` 应该自动创建记录。如果失败，可能是：
- 触发器被禁用
- `credibility_scores` 表不存在
- RLS 策略阻止插入

**解决方案**: 手动创建记录或修复触发器

---

### Q2: 评分如何更新？

**A**: 评分在以下情况自动更新：
1. 有新评分提交时（触发器自动计算）
2. 见面完成时（更新统计）
3. 15 天未见面时（评分衰减）

---

### Q3: 如何查看用户的信誉评分？

**A**: 
- **代码**: `supabaseService.getCredibilityScore(userId:)`
- **UI**: 用户资料卡片右上角显示平均评分
- **详情**: 点击用户资料查看完整信誉徽章

---

### Q4: 评分会影响匹配吗？

**A**: 是的！评分通过 `matchingWeightMultiplier` 影响推荐排序：
- 高信誉用户: +10% 到 +60% 权重加成
- 低信誉用户: -10% 到 -60% 权重惩罚
- 封禁用户: 0% 权重（不显示）

---

## 十二、系统价值

### 1. **建立信任**

通过量化用户行为，建立社区信任机制

### 2. **提高质量**

鼓励用户认真对待每次见面，提高整体体验

### 3. **防止滥用**

低信誉用户受到限制，防止恶意行为

### 4. **激励活跃**

评分衰减机制鼓励用户保持活跃

### 5. **经济激励**

高信誉用户获得 Pro 折扣，形成正向循环

---

## 总结

**credibility_scores 系统**是 BrewNet 的核心信任机制，通过：
- ✅ 量化用户行为（评分、履约率）
- ✅ 自动计算和更新（数据库触发器）
- ✅ 影响匹配推荐（权重加成/惩罚）
- ✅ 限制低信誉用户（每日右划限制）
- ✅ 激励高信誉用户（Pro 折扣）

来建立一个健康、可信赖的专业社交网络。

