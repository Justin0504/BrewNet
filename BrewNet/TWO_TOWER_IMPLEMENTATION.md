# Two-Tower 推荐模型落地策略

## 📋 目录

1. [概述](#概述)
2. [架构设计](#架构设计)
3. [数据准备](#数据准备)
4. [模型实现](#模型实现)
5. [部署方案](#部署方案)
6. [评估指标](#评估指标)
7. [渐进式升级](#渐进式升级)

---

## 🎯 概述

### Two-Tower 为什么适合 BrewNet

**核心优势**：
- ✅ **召回 + 精排双阶段**：先召回大量候选，再精细排序
- ✅ **双向匹配友好**：用户塔和物品塔分离建模
- ✅ **冷启动效果好**：只依赖特征，不需要历史交互
- ✅ **可扩展性强**：从简单到复杂，平滑升级

### 你的数据优势

**丰富的结构化特征**：
- 用户资料：6 层结构（Core, Professional, Intent, Preferences, Personality, Privacy）
- 技能标签：明确的技能体系
- 意图分类：4 种 Networking Intention
- 社交信号：Verified Status, Completion Rate

---

## 🏗️ 架构设计

### 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                     用户请求                                │
│              "给我推荐匹配的用户"                            │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │  召回阶段 (Recall)        │
         │  目标: 找到 10,000 候选   │
         └───────────┬───────────────┘
                     │
         ┌───────────┴───────────────┐
         │                           │
         ▼                           ▼
┌─────────────────┐        ┌─────────────────┐
│  用户塔         │        │  物品塔         │
│  (User Tower)   │        │  (Item Tower)   │
│                 │        │                 │
│ Input:          │        │ Input:          │
│ - Current User  │        │ - All Profiles  │
│   Features      │        │   Features      │
│                 │        │                 │
│ ↓               │        │ ↓               │
│ Embedding       │        │ Embedding       │
│ Layer           │        │ Layer           │
│ ↓               │        │ ↓               │
│ User Vector     │        │ Item Vectors    │
│ (64 dim)        │        │ (64 dim × N)    │
└────────┬────────┘        └────────┬────────┘
         │                          │
         └───────────┬──────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │  Top-K 检索               │
         │  (ANN: Approximate NN)    │
         │  返回 Top 1000            │
         └───────────┬───────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │  精排阶段 (Ranking)       │
         │  目标: 选出 Top 20        │
         └───────────┬───────────────┘
                     │
         └───────────┴───────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │  返回给用户               │
         │  Top 20 推荐结果          │
         └───────────────────────────┘
```

### 特征工程

#### 用户塔特征定义

```swift
struct UserTowerFeatures {
    // ========== 稀疏特征 (Categorical) ==========
    
    // Core Identity
    let location: String                    // "San Francisco"
    let timeZone: String                    // "America/Los_Angeles"
    
    // Professional
    let industry: String                    // "Technology"
    let experienceLevel: String             // "senior"
    let careerStage: String                 // "manager"
    
    // Intention
    let mainIntention: String               // "learnGrow"
    
    // ========== 多值稀疏特征 (Multi-hot) ==========
    
    let skills: [String]                    // ["Swift", "AI", "Product Management"]
    let hobbies: [String]                   // ["Coffee Culture", "Photography"]
    let values: [String]                    // ["Innovative", "Collaborative"]
    let languages: [String]                 // ["English", "Mandarin"]
    let subIntentions: [String]             // ["careerDirection", "skillDevelopment"]
    
    // ========== 学习/教授配对 ==========
    
    let skillsToLearn: [String]             // 想学习的技能
    let skillsToTeach: [String]             // 能教授的技能
    let functionsToLearn: [String]          // 想学习的职能
    let functionsToTeach: [String]          // 能指导的职能
    
    // ========== 数值特征 (Dense) ==========
    
    let yearsOfExperience: Double           // 5.5 years
    let profileCompletion: Double           // 0.85
    let isVerified: Int                     // 1 or 0
    
    // ========== 历史行为特征 (可选) ==========
    
    let likedProfileIds: [String]           // 之前喜欢过的用户ID
    let passedProfileIds: [String]          // 之前跳过的用户ID
    let matchedProfileIds: [String]         // 匹配成功的用户ID
}
```

#### 物品塔特征定义

```swift
struct ItemTowerFeatures {
    // 结构完全同 UserTowerFeatures
    // 表示"候选用户"的特征
}
```

---

## 🗂️ 数据准备

### 数据库 Schema

```sql
-- 1. 用户特征表
CREATE TABLE user_features (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    
    -- 稀疏特征
    location VARCHAR(100),
    time_zone VARCHAR(50),
    industry VARCHAR(100),
    experience_level VARCHAR(50),
    career_stage VARCHAR(50),
    main_intention VARCHAR(50),
    
    -- 多值特征 (JSONB)
    skills JSONB,                    -- ["Swift", "AI"]
    hobbies JSONB,                   -- ["Coffee", "Photo"]
    values JSONB,                    -- ["Innovative"]
    languages JSONB,                 -- ["English"]
    sub_intentions JSONB,            -- ["careerDirection"]
    
    -- 学习/教授配对
    skills_to_learn JSONB,           -- ["Machine Learning"]
    skills_to_teach JSONB,           -- ["iOS Development"]
    functions_to_learn JSONB,        -- ["Product Management"]
    functions_to_teach JSONB,        -- ["Software Engineering"]
    
    -- 数值特征
    years_of_experience FLOAT,
    profile_completion FLOAT,
    is_verified INT,
    
    -- Embedding 向量 (未来存储)
    user_embedding FLOAT[],          -- [0.1, 0.2, ..., 0.9] 64维
    
    -- 元数据
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 2. 用户交互日志表
CREATE TABLE user_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    target_user_id UUID NOT NULL REFERENCES users(id),
    interaction_type VARCHAR(20) NOT NULL, -- 'like', 'pass', 'match'
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, target_user_id, interaction_type)
);

CREATE INDEX idx_interactions_user ON user_interactions(user_id);
CREATE INDEX idx_interactions_target ON user_interactions(target_user_id);
CREATE INDEX idx_interactions_type ON user_interactions(interaction_type);

-- 3. 推荐结果缓存表
CREATE TABLE recommendation_cache (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    recommended_user_ids JSONB,      -- 用户ID列表
    scores JSONB,                    -- 对应的分数列表
    model_version VARCHAR(50),       -- "two_tower_v1"
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);

CREATE INDEX idx_cache_expires ON recommendation_cache(expires_at);
```

### 数据同步触发器

```sql
-- 当用户资料更新时，自动更新 user_features
CREATE OR REPLACE FUNCTION sync_user_features()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_features (
        user_id,
        location,
        time_zone,
        industry,
        experience_level,
        career_stage,
        main_intention,
        skills,
        hobbies,
        values,
        languages,
        sub_intentions,
        skills_to_learn,
        skills_to_teach,
        functions_to_learn,
        functions_to_teach,
        years_of_experience,
        profile_completion,
        is_verified
    ) VALUES (
        NEW.id,
        NEW.core_identity->>'location',
        NEW.core_identity->>'time_zone',
        NEW.professional_background->>'industry',
        NEW.professional_background->>'experience_level',
        NEW.professional_background->>'career_stage',
        NEW.networking_intention->>'selected_intention',
        NEW.professional_background->'skills',
        NEW.personality_social->'hobbies',
        NEW.personality_social->'values_tags',
        NEW.professional_background->'languages_spoken',
        NEW.networking_intention->'selected_sub_intentions',
        -- 提取 skills_to_learn (where learnIn = true)
        (SELECT jsonb_agg(e->>'skill_name')
         FROM jsonb_array_elements(NEW.networking_intention->'skill_development'->'skills') e
         WHERE (e->>'learn_in')::boolean = true),
        -- 提取 skills_to_teach (where guideIn = true)
        (SELECT jsonb_agg(e->>'skill_name')
         FROM jsonb_array_elements(NEW.networking_intention->'skill_development'->'skills') e
         WHERE (e->>'guide_in')::boolean = true),
        -- 提取 functions_to_learn/teach 类似逻辑...
        COALESCE((NEW.professional_background->>'years_of_experience')::FLOAT, 0),
        -- 计算 profile_completion
        calculate_profile_completion(NEW),
        CASE WHEN NEW.privacy_trust->'verified_status' = 'verified_professional' THEN 1 ELSE 0 END
    )
    ON CONFLICT (user_id) DO UPDATE
    SET
        location = EXCLUDED.location,
        time_zone = EXCLUDED.time_zone,
        industry = EXCLUDED.industry,
        -- ... 更新其他字段
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_sync_user_features
AFTER INSERT OR UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION sync_user_features();
```

---

## 💻 模型实现

### 阶段 1: 简单向量化（立即可用）

**不使用深度学习，快速上线**

```swift
// MARK: - Simple Two-Tower Encoder
class SimpleTwoTowerEncoder {
    
    // 特征库（从数据中收集）
    static let allSkills = [
        "Swift", "Python", "JavaScript", "React", "iOS Development",
        "AI", "Machine Learning", "Product Management", "UX Design",
        // ... 更多技能
    ]
    
    static let allHobbies = [
        "Coffee Culture", "Photography", "Hiking", "Reading",
        "Gaming", "Music", "Travel", "Cooking",
        // ... 更多爱好
    ]
    
    static let allIndustries = [
        "Technology", "Finance", "Healthcare", "Education",
        "E-commerce", "Gaming", "Media", "Consulting",
        // ... 更多行业
    ]
    
    // MARK: - 编码用户为特征向量
    
    /// 编码 UserTower 输入
    static func encodeUser(_ features: UserTowerFeatures) -> [Double] {
        var vector: [Double] = []
        
        // 1. One-hot 编码稀疏特征
        vector += oneHotEncode(features.industry, allCategories: allIndustries)
        vector += oneHotEncode(features.experienceLevel, allCategories: ["entry", "mid", "senior"])
        vector += oneHotEncode(features.mainIntention, allCategories: ["learnGrow", "connectShare", "buildCollaborate", "unwindChat"])
        
        // 2. Multi-hot 编码多值特征
        vector += multiHotEncode(features.skills, allCategories: allSkills)
        vector += multiHotEncode(features.hobbies, allCategories: allHobbies)
        vector += multiHotEncode(features.values, allCategories: ["Innovative", "Collaborative", "Curious", "Passionate"])
        
        // 3. 归一化数值特征
        vector.append(features.yearsOfExperience / 50.0)  // 归一化到 [0, 1]
        vector.append(features.profileCompletion)         // 已经是 [0, 1]
        vector.append(Double(features.isVerified))
        
        return vector
    }
    
    /// 计算用户 Embedding（简单版：投影到低维）
    static func computeEmbedding(_ features: [Double]) -> [Double] {
        // 降维：从高维特征向量投影到 64 维
        let embeddingDim = 64
        var embedding = [Double](repeating: 0.0, count: embeddingDim)
        
        // 简单的线性投影（未来可以用学习到的权重）
        for i in 0..<features.count {
            let hash = i % embeddingDim
            embedding[hash] += features[i]
        }
        
        // L2 归一化
        let norm = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        return embedding.map { $0 / max(norm, 1e-10) }
    }
    
    // MARK: - 计算相似度
    
    /// 计算两个用户的匹配分数
    static func calculateSimilarity(
        userFeatures: UserTowerFeatures,
        candidateFeatures: ItemTowerFeatures
    ) -> Double {
        let userEmbedding = computeEmbedding(encodeUser(userFeatures))
        let candidateEmbedding = computeEmbedding(encodeCandidate(candidateFeatures))
        return cosineSimilarity(userEmbedding, candidateEmbedding)
    }
    
    // MARK: - Helper Functions
    
    private static func oneHotEncode(_ value: String, allCategories: [String]) -> [Double] {
        guard let index = allCategories.firstIndex(of: value) else {
            return [Double](repeating: 0.0, count: allCategories.count)
        }
        var oneHot = [Double](repeating: 0.0, count: allCategories.count)
        oneHot[index] = 1.0
        return oneHot
    }
    
    private static func multiHotEncode(_ values: [String], allCategories: [String]) -> [Double] {
        var multiHot = [Double](repeating: 0.0, count: allCategories.count)
        for value in values {
            if let index = allCategories.firstIndex(of: value) {
                multiHot[index] = 1.0
            }
        }
        return multiHot
    }
    
    private static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        return dotProduct / max(magnitudeA * magnitudeB, 1e-10)
    }
    
    /// 编码物品塔输入（同用户塔）
    static func encodeCandidate(_ features: ItemTowerFeatures) -> [Double] {
        // 转换为 UserTowerFeatures 格式
        let userFeatures = UserTowerFeatures(
            location: features.location,
            timeZone: features.timeZone,
            industry: features.industry,
            experienceLevel: features.experienceLevel,
            careerStage: features.careerStage,
            mainIntention: features.mainIntention,
            skills: features.skills,
            hobbies: features.hobbies,
            values: features.values,
            languages: features.languages,
            subIntentions: features.subIntentions,
            skillsToLearn: features.skillsToLearn,
            skillsToTeach: features.skillsToTeach,
            functionsToLearn: features.functionsToLearn,
            functionsToTeach: features.functionsToTeach,
            yearsOfExperience: features.yearsOfExperience,
            profileCompletion: features.profileCompletion,
            isVerified: features.isVerified,
            likedProfileIds: [],
            passedProfileIds: [],
            matchedProfileIds: []
        )
        return encodeUser(userFeatures)
    }
}
```

### 阶段 2: 深度学习模型（Python 训练）

**使用 PyTorch 训练真正的 Two-Tower**

```python
# train_two_tower.py
import torch
import torch.nn as nn
import numpy as np
from torch.utils.data import Dataset, DataLoader
import json

class UserItemDataset(Dataset):
    """用户-物品交互数据集"""
    def __init__(self, interactions_file):
        with open(interactions_file, 'r') as f:
            self.data = json.load(f)
    
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        item = self.data[idx]
        return {
            'user_features': torch.FloatTensor(item['user_features']),
            'item_features': torch.FloatTensor(item['item_features']),
            'label': torch.FloatTensor([item['label']])  # 1=like, 0=pass
        }

class TwoTowerModel(nn.Module):
    """Two-Tower 模型"""
    
    def __init__(
        self,
        user_feature_dim: int,
        item_feature_dim: int,
        embedding_dim: int = 64
    ):
        super().__init__()
        
        # 用户塔
        self.user_tower = nn.Sequential(
            nn.Linear(user_feature_dim, 128),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(128, 64),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(64, embedding_dim)
        )
        
        # 物品塔
        self.item_tower = nn.Sequential(
            nn.Linear(item_feature_dim, 128),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(128, 64),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(64, embedding_dim)
        )
        
        # L2 归一化层
        self.normalize = nn.functional.normalize
    
    def forward(self, user_features, item_features):
        # 分别通过两个塔
        user_emb = self.user_tower(user_features)
        item_emb = self.item_tower(item_features)
        
        # L2 归一化
        user_emb = self.normalize(user_emb, p=2, dim=1)
        item_emb = self.normalize(item_emb, p=2, dim=1)
        
        return user_emb, item_emb
    
    def predict_score(self, user_features, item_features):
        """预测匹配分数"""
        user_emb, item_emb = self.forward(user_features, item_features)
        # 余弦相似度 = 点积（因为已经归一化）
        return (user_emb * item_emb).sum(dim=1)


def train_model():
    # 初始化
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model = TwoTowerModel(
        user_feature_dim=512,  # 根据你的特征维度调整
        item_feature_dim=512,
        embedding_dim=64
    ).to(device)
    
    # 优化器和损失函数
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = nn.BCEWithLogitsLoss()  # 二分类损失
    
    # 数据加载
    dataset = UserItemDataset('interactions.json')
    dataloader = DataLoader(dataset, batch_size=64, shuffle=True)
    
    # 训练
    for epoch in range(100):
        total_loss = 0
        for batch in dataloader:
            user_features = batch['user_features'].to(device)
            item_features = batch['item_features'].to(device)
            labels = batch['label'].to(device)
            
            # 前向传播
            user_emb, item_emb = model(user_features, item_features)
            
            # 计算相似度
            scores = (user_emb * item_emb).sum(dim=1).unsqueeze(1)
            
            # 损失
            loss = criterion(scores, labels)
            
            # 反向传播
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
        
        print(f'Epoch {epoch}, Loss: {total_loss / len(dataloader):.4f}')
    
    # 保存模型
    torch.save(model.state_dict(), 'two_tower_model.pth')
    print('Model saved!')

if __name__ == '__main__':
    train_model()
```

---

## 🚀 部署方案

### 方案 A: iOS 端集成（Core ML）

```python
# 转换为 Core ML
import coremltools as ct

# 加载训练好的模型
model = TwoTowerModel(user_feature_dim=512, item_feature_dim=512)
model.load_state_dict(torch.load('two_tower_model.pth'))
model.eval()

# 转换为 Core ML
example_input_user = torch.rand(1, 512)
example_input_item = torch.rand(1, 512)

traced_model = torch.jit.trace(
    model,
    (example_input_user, example_input_item)
)

coreml_model = ct.convert(
    traced_model,
    inputs=[
        ct.TensorType(name="user_features", shape=(1, 512)),
        ct.TensorType(name="item_features", shape=(1, 512))
    ],
    outputs=[
        ct.TensorType(name="user_embedding"),
        ct.TensorType(name="item_embedding")
    ]
)

coreml_model.save("TwoTower.mlmodel")
```

### 方案 B: 服务端部署（Supabase Edge Functions）

```typescript
// supabase/functions/recommend/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { userId, limit = 20 } = await req.json()
    
    // 1. 获取用户特征
    const { data: userFeatures } = await supabase
      .from('user_features')
      .select('*')
      .eq('user_id', userId)
      .single()
    
    // 2. 计算用户 Embedding
    const userEmbedding = computeEmbedding(userFeatures)
    
    // 3. 批量计算所有候选用户的 Embedding
    const { data: candidates } = await supabase
      .from('user_features')
      .select('*')
      .neq('user_id', userId)
      .limit(1000)
    
    // 4. 计算相似度并排序
    const scoredCandidates = candidates
      .map(candidate => {
        const candidateEmbedding = computeEmbedding(candidate)
        const score = cosineSimilarity(userEmbedding, candidateEmbedding)
        return { userId: candidate.user_id, score }
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
    
    return new Response(
      JSON.stringify({ recommendations: scoredCandidates }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400
    })
  }
})

function cosineSimilarity(a: number[], b: number[]): number {
  const dot = a.reduce((sum, val, i) => sum + val * b[i], 0)
  const normA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0))
  const normB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0))
  return dot / (normA * normB)
}
```

---

## 📊 评估指标

### 离线评估

```swift
struct ModelEvaluator {
    
    /// 计算 Hit Rate @ K
    static func hitRate(
        recommendations: [String],  // 推荐的用户ID列表
        groundTruth: Set<String>    // 用户实际交互的用户ID
    ) -> Double {
        let topK = Set(recommendations.prefix(K))
        let hits = topK.intersection(groundTruth)
        return Double(hits.count) / Double(K)
    }
    
    /// 计算 NDCG @ K
    static func ndcg(
        recommendations: [(userId: String, score: Double)],
        groundTruth: Set<String>
    ) -> Double {
        var dcg: Double = 0.0
        for (rank, rec) in recommendations.enumerated() {
            if groundTruth.contains(rec.userId) {
                dcg += 1.0 / log2(Double(rank + 2))
            }
        }
        
        // 计算 IDCG
        let idealHits = min(K, groundTruth.count)
        var idcg: Double = 0.0
        for i in 0..<idealHits {
            idcg += 1.0 / log2(Double(i + 2))
        }
        
        return dcg / max(idcg, 1e-10)
    }
    
    /// AUC (AUC-ROC)
    static func auc(
        positiveScores: [Double],
        negativeScores: [Double]
    ) -> Double {
        var auc: Double = 0.0
        for posScore in positiveScores {
            for negScore in negativeScores {
                if posScore > negScore {
                    auc += 1.0
                } else if posScore == negScore {
                    auc += 0.5
                }
            }
        }
        return auc / Double(positiveScores.count * negativeScores.count)
    }
}
```

### 在线 A/B 测试

```swift
// A/B 测试框架
enum RecommendationVersion {
    case baseline      // 当前时间排序
    case twoTowerV1    // Two-Tower 版本 1
    case twoTowerV2    // Two-Tower 版本 2（增强）
}

class ABTestManager {
    
    func getRecommendationVersion(for userId: String) -> RecommendationVersion {
        // 基于用户ID哈希分桶
        let bucket = hash(userId) % 100
        switch bucket {
        case 0..<50:
            return .baseline     // 50% 使用基线
        case 50..<80:
            return .twoTowerV1   // 30% 使用 Two-Tower V1
        default:
            return .twoTowerV2   // 20% 使用 Two-Tower V2
        }
    }
    
    func trackMetric(
        version: RecommendationVersion,
        metric: String,
        value: Double
    ) {
        // 发送到分析服务（Firebase, Amplitude 等）
        Analytics.logEvent("recommendation_metric", parameters: [
            "version": version.rawValue,
            "metric": metric,
            "value": value
        ])
    }
}
```

---

## 🔄 渐进式升级

### Phase 1: 基础设施（1-2 周）

**目标**: 建立数据管道

- [ ] 创建 `user_features` 表
- [ ] 实现数据同步触发器
- [ ] 收集所有特征 vocabulary（skills, industries 等）
- [ ] 实现简单向量化

**交付物**: 数据可以正确同步，特征提取完整

---

### Phase 2: 简单 Two-Tower（2-3 周）

**目标**: 部署基于规则的 Two-Tower

- [ ] 实现 `SimpleTwoTowerEncoder`
- [ ] 在 Supabase Edge Functions 部署推理
- [ ] 替换当前的时间排序
- [ ] A/B 测试：50% baseline vs 50% Two-Tower

**预期效果**: CTR 提升 20-30%

---

### Phase 3: 深度学习 Two-Tower（1-2 月）

**目标**: 训练真正的神经网络

- [ ] 收集 1,000+ 交互数据
- [ ] Python 训练脚本
- [ ] 模型转换 Core ML
- [ ] iOS 端集成
- [ ] A/B 测试验证

**预期效果**: CTR 提升 40-60%

---

### Phase 4: 持续优化（长期）

**目标**: 模型迭代和精调

- [ ] 在线学习：根据新交互更新模型
- [ ] 负采样优化：处理不平衡数据
- [ ] 多任务学习：同时优化 match 和 response
- [ ] Feature Crossing：学习特征组合

**预期效果**: 持续提升 5-10%/季度

---

## 🎯 关键成功因素

1. **数据质量**: 特征准确、完整
2. **冷启动**: 新用户也能获得好推荐
3. **多样性**: 避免过度相似的用户
4. **实时性**: 推荐延迟 < 100ms
5. **可解释性**: 知道为什么推荐这个用户

---

## 📚 参考资源

**学术论文**:
1. "Sampling-Bias-Corrected Neural Modeling for Large Corpus Item Recommendations" (Google, 2019)
2. "Deep Neural Networks for YouTube Recommendations" (Google, 2016)

**开源实现**:
1. PyTorch Two-Tower: https://github.com/facebookresearch/faiss
2. ANN Search: https://github.com/spotify/annoy
3. Core ML Tools: https://apple.github.io/coremltools/

**商业案例**:
1. Airbnb: "Applying Deep Learning to Airbnb Search"
2. Pinterest: "Home feed personalization at Pinterest"
3. LinkedIn: "Scaling Recommender Systems"

---

**开始你的 Two-Tower 之旅吧！🚀**

