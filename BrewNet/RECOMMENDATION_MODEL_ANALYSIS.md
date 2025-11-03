# BrewNet 推荐系统模型分析

## 🔍 当前状态

### 现有推荐逻辑

**无机器学习模型**，仅使用简单的**规则基础排序**：

```swift
// 当前实现
var query = client
    .from("profiles")
    .select()
    .neq("user_id", value: currentUserId)
    .order("created_at", ascending: false)  // ⚠️ 仅按时间排序
```

**排序方式**: `ORDER BY created_at DESC`（最新注册优先）

---

## 📊 可用数据维度

虽然代码中有丰富的用户特征，但**未被用于推荐**：

### 1. Core Identity（核心身份）
- Name, Bio, Location
- Pronouns, Time Zone
- Personal Website, GitHub, LinkedIn
- Available Timeslots

### 2. Professional Background（专业背景）
- Current Company, Job Title
- Industry, Experience Level
- Education, Years of Experience
- **Skills**: `["Product Strategy", "UX Design", "iOS Development"]`
- Languages Spoken
- Work Experiences

### 3. Networking Intention（网络意图）
- `selectedIntention`: Learn & Grow, Connect & Share, Build & Collaborate, Unwind & Chat
- `selectedSubIntentions`: Career Direction, Skill Development, Industry Transition
- `careerDirection`: Functions (learn_in, guide_in)
- `skillDevelopment`: Skills (learn_in, guide_in)
- `industryTransition`: Industries (learn_in, guide_in)

### 4. Personality & Social（个性社交）
- **Hobbies**: `["Coffee Culture", "Photography", "Hiking"]`
- **Values**: `["Innovative", "Collaborative", "Curious"]`
- Preferred Meeting Vibe: Casual, Reflective, etc.

### 5. Privacy & Trust（隐私控制）
- Visibility Settings
- Verified Status
- Data Sharing Consent

---

## 🎯 推荐模型设计方案

### 方案 1: 基于内容的推荐 (Content-Based Filtering)

**推荐度评分公式**：

```
Score(profile_i) = Σ(weight_j × similarity(feature_i, feature_j))

其中：
- feature_i = 当前用户特征
- feature_j = 候选用户特征
- weight_j = 特征权重
```

**具体特征匹配**：

| 特征类型 | 权重 | 相似度计算 |
|---------|------|-----------|
| **Skills 交集** | 0.3 | Jaccard Similarity |
| **Industry** | 0.2 | 完全匹配 = 1.0, 相似行业 = 0.5 |
| **Networking Intention** | 0.25 | 完全匹配 = 1.0 |
| **Sub-Intentions 交集** | 0.15 | Jaccard Similarity |
| **Hobbies 交集** | 0.1 | Jaccard Similarity |

**实现示例**：

```swift
func calculateRecommendationScore(
    currentProfile: BrewNetProfile,
    candidateProfile: BrewNetProfile
) -> Double {
    var score: Double = 0.0
    
    // Skills 匹配度
    let skillSimilarity = calculateJaccardSimilarity(
        currentProfile.professionalBackground.skills,
        candidateProfile.professionalBackground.skills
    )
    score += 0.3 * skillSimilarity
    
    // Intention 匹配度
    if currentProfile.networkingIntention.selectedIntention == 
       candidateProfile.networkingIntention.selectedIntention {
        score += 0.25
    }
    
    // Sub-Intentions 匹配度
    let subIntentionSimilarity = calculateJaccardSimilarity(
        currentProfile.networkingIntention.selectedSubIntentions,
        candidateProfile.networkingIntention.selectedSubIntentions
    )
    score += 0.15 * subIntentionSimilarity
    
    // Hobbies 匹配度
    let hobbySimilarity = calculateJaccardSimilarity(
        currentProfile.personalitySocial.hobbies,
        candidateProfile.personalitySocial.hobbies
    )
    score += 0.1 * hobbySimilarity
    
    // Industry 匹配度
    if let currentIndustry = currentProfile.professionalBackground.industry,
       let candidateIndustry = candidateProfile.professionalBackground.industry {
        score += 0.2 * calculateIndustrySimilarity(currentIndustry, candidateIndustry)
    }
    
    return min(score, 1.0) // 归一化到 [0, 1]
}

func calculateJaccardSimilarity<T: Hashable>(_ set1: [T], _ set2: [T]) -> Double {
    guard !set1.isEmpty || !set2.isEmpty else { return 0.0 }
    let intersection = Set(set1).intersection(Set(set2)).count
    let union = Set(set1).union(Set(set2)).count
    return Double(intersection) / Double(union)
}
```

**优点**：
- ✅ 无需历史交互数据
- ✅ 冷启动友好
- ✅ 可解释性强
- ✅ 实现简单

**缺点**：
- ❌ 可能产生"信息茧房"
- ❌ 需要手动调优权重

---

### 方案 2: 协同过滤 (Collaborative Filtering)

**基于用户的协同过滤** (User-Based CF)：

```
推荐度 = 找到与当前用户"相似"的用户，推荐这些用户喜欢的档案
```

**相似度计算**：

```swift
func calculateUserSimilarity(
    user1: BrewNetProfile,
    user2: BrewNetProfile
) -> Double {
    // 基于 Skills, Hobbies, Intention 计算余弦相似度
    let v1 = createFeatureVector(user1)
    let v2 = createFeatureVector(user2)
    return cosineSimilarity(v1, v2)
}

func createFeatureVector(profile: BrewNetProfile) -> [Double] {
    // 将多维度特征转换为固定长度向量
    // 例如：one-hot 编码 skills, industry, intention 等
    return [
        // ... feature values
    ]
}
```

**优点**：
- ✅ 可以发现用户隐藏偏好
- ✅ 推荐多样性好

**缺点**：
- ❌ 需要大量历史数据
- ❌ 冷启动问题（新用户无交互）
- ❌ 计算复杂度高

---

### 方案 3: 混合模型 (Hybrid Approach)

**组合 Content-Based 和 CF**：

```swift
func calculateFinalScore(
    currentProfile: BrewNetProfile,
    candidateProfile: BrewNetProfile
) -> Double {
    let contentScore = calculateContentBasedScore(currentProfile, candidateProfile)
    let cfScore = calculateCollaborativeFilteringScore(currentProfile, candidateProfile)
    
    // 加权组合
    return 0.7 * contentScore + 0.3 * cfScore
}
```

---

### 方案 4: 深度学习推荐 (Deep Learning)

**使用神经网络**：

```
输入：用户特征向量 (维度 = 特征数量)
     ↓
     Dense Layer 1 (64 units, ReLU)
     ↓
     Dense Layer 2 (32 units, ReLU)
     ↓
     Dense Layer 3 (16 units, ReLU)
     ↓
输出：匹配分数 (0-1)
```

**推荐框架**：
- TensorFlow Lite / Core ML
- PyTorch Mobile
- TuriCreate

**优点**：
- ✅ 自动学习特征权重
- ✅ 可以处理复杂非线性关系

**缺点**：
- ❌ 需要大量训练数据
- ❌ 模型体积大
- ❌ 离线训练，线上推理

---

## 🚀 实施建议

### 阶段 1: 快速实现（1-2 周）

**实施方案 1 (Content-Based)**：

1. 在 `SupabaseService.swift` 中添加评分函数
2. 修改 `getRecommendedProfiles` 查询逻辑
3. 在数据库层添加评分计算（PostgreSQL Function）

**SQL 实现示例**：

```sql
CREATE OR REPLACE FUNCTION calculate_match_score(
    current_skills TEXT[],
    candidate_skills TEXT[],
    current_intention TEXT,
    candidate_intention TEXT
) RETURNS DOUBLE PRECISION AS $$
DECLARE
    skill_intersection INTEGER;
    skill_union INTEGER;
    skill_similarity DOUBLE PRECISION;
BEGIN
    -- 计算 Skills Jaccard Similarity
    SELECT COUNT(*) INTO skill_intersection
    FROM unnest(current_skills) AS cs
    WHERE cs = ANY(candidate_skills);
    
    SELECT COUNT(DISTINCT skill) INTO skill_union
    FROM unnest(ARRAY[current_skills, candidate_skills]);
    
    skill_similarity := skill_intersection::DOUBLE PRECISION / NULLIF(skill_union, 0);
    
    -- 计算总分
    RETURN (
        0.3 * skill_similarity +
        0.25 * CASE WHEN current_intention = candidate_intention THEN 1.0 ELSE 0.0 END +
        0.45 * 0.0 -- 其他特征待添加
    );
END;
$$ LANGUAGE plpgsql;

-- 使用函数排序
SELECT *, calculate_match_score(?, skills, ?, networking_intention->>'selected_intention') AS score
FROM profiles
WHERE user_id != ?
ORDER BY score DESC, created_at DESC
LIMIT ? OFFSET ?;
```

### 阶段 2: 模型优化（1-2 月）

**实施方案 3 (Hybrid)**：
1. 收集用户交互数据（pass/like）
2. 计算用户相似度矩阵
3. 训练简单的线性模型
4. 在线下使用 Supabase Edge Functions

### 阶段 3: 深度学习（3-6 月）

**实施方案 4 (Deep Learning)**：
1. 数据收集：至少 10,000+ 用户交互记录
2. 模型训练：Python + PyTorch
3. 模型转换：Core ML / TensorFlow Lite
4. 模型部署：Supabase Edge Functions 或 iOS 本地推理

---

## 📈 数据需求

### 最小数据集

| 推荐方式 | 需要的用户数量 | 需要的交互数量 |
|---------|--------------|--------------|
| Content-Based | 100+ | 0 |
| User-Based CF | 1,000+ | 10,000+ |
| Hybrid | 5,000+ | 50,000+ |
| Deep Learning | 10,000+ | 100,000+ |

---

## 🔧 技术栈建议

### 当前技术栈
- **前端**: Swift + SwiftUI
- **后端**: Supabase (PostgreSQL)
- **AI**: Gemini API（仅用于聊天话题生成）

### 推荐集成方案

1. **轻量级**（适合 Content-Based）：
   - PostgreSQL Functions
   - Supabase Edge Functions (Deno)

2. **中量级**（适合 Hybrid）：
   - Python Flask / FastAPI 服务
   - Supabase Edge Functions + TuriCreate

3. **重量级**（适合 Deep Learning）：
   - 独立推荐服务（Python + PyTorch）
   - Core ML 模型部署
   - TensorFlow Lite on iOS

---

## 💡 快速原型建议

**立即可以做的改进**：

1. **混合排序**：
```swift
// 保持时间权重，但加入特征权重
ORDER BY 
    (matched_features * 0.6 + time_decay * 0.4) DESC,
    created_at DESC
```

2. **Intent 优先**：
```swift
// 用户选择 category 时，优先显示相同 intent
WHERE networking_intention->'selected_intention' = :intent
ORDER BY created_at DESC
```

3. **技能匹配**：
```swift
// 简单交集匹配，Top-K
WHERE skills && :current_user_skills  -- PostgreSQL array overlap
ORDER BY array_length(array(SELECT unnest(skills) INTERSECT SELECT unnest(:current_user_skills)), 1) DESC
```

---

## 📝 总结

**现状**: 
- ❌ 无推荐模型，仅按时间排序
- ✅ 有丰富的用户特征数据
- ✅ 有 Gemini AI 基础（可用于文本理解）

**建议**:
1. **短期**（1-2周）：实现 Content-Based 推荐
2. **中期**（1-2月）：收集数据，建立 Hybrid 模型
3. **长期**（3-6月）：引入深度学习模型

**关键指标**:
- 推荐准确率 (Precision@K)
- 点击率 (CTR)
- 匹配率 (Match Rate)
- 用户满意度 (Rating)

---

**最后更新**: 2024-12-28
**版本**: 1.0

