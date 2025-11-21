# 🚀 Headhunting V2.0 部署清单

> **10分钟快速部署指南**

---

## ✅ 部署步骤

### Step 1: 数据库升级 (5分钟)

1. **打开 Supabase Dashboard**
   ```
   https://app.supabase.com/project/YOUR_PROJECT/sql
   ```

2. **执行SQL脚本**
   - 打开文件: `upgrade_headhunting_database.sql`
   - 复制全部内容
   - 粘贴到 SQL Editor
   - 点击 "Run"

3. **验证**
   ```sql
   -- 检查列是否创建
   SELECT column_name FROM information_schema.columns 
   WHERE table_name = 'user_features' 
     AND column_name IN ('searchable_text', 'concept_tags');
   
   -- 应该返回2行
   ```

4. **测试搜索**
   ```sql
   SELECT * FROM headhunting_fulltext_search(
       'product manager', 
       ARRAY[]::UUID[], 
       5
   );
   
   -- 应该返回5条结果
   ```

---

### Step 2: 代码集成 (3分钟)

1. **添加新文件到 Xcode**
   - 打开 `BrewNet.xcodeproj`
   - 拖拽以下文件到 `BrewNet` 文件夹:
     - `QueryParser.swift`
     - `SoftMatching.swift`
     - `FieldAwareScoring.swift`
     - `ConceptTagger.swift`
     - `DynamicWeighting.swift`
   - 确保勾选 Target: `BrewNet`

2. **验证编译**
   ```
   Cmd + B (Build)
   ```
   
   预期: ✅ Build Succeeded

---

### Step 3: 功能测试 (2分钟)

1. **运行应用**
   ```
   Cmd + R
   ```

2. **测试查询**

   **Test 1**: "PM"
   ```
   预期: 看到 Product Manager
   日志: "Synonyms added: product manager, program manager"
   ```

   **Test 2**: "Top tech engineer"
   ```
   预期: 看到 Google, Meta, Amazon 等大厂员工
   日志: "Concept match: Big Tech"
   ```

   **Test 3**: "5 years experience"
   ```
   预期: 4-6年经验的候选人
   日志: "Experience soft: X ≈ 5"
   ```

3. **检查日志**
   
   应该看到:
   ```
   🔍 Parsing query: "..."
   📝 Tokens: ...
   🏢 Companies: ...
   ⚖️ Final weights: ...
   👤 Scoring: ...
   ```

---

## ⚡ 快速验证

### 30秒检查

```bash
# 1. 检查文件是否存在
ls BrewNet/*.swift | grep -E "(QueryParser|SoftMatching|FieldAware|ConceptTagger|DynamicWeighting)"

# 应该看到5个文件

# 2. 检查编译
xcodebuild -scheme BrewNet -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 14' clean build

# 应该看到: BUILD SUCCEEDED
```

---

## 🎯 验收标准

### 必须通过

- [ ] 数据库脚本执行成功
- [ ] 所有新文件已添加
- [ ] Xcode 编译成功
- [ ] 3个测试查询都正常
- [ ] 日志输出正常

### 可选

- [ ] 性能测试通过 (<1s)
- [ ] 对比V1.0结果
- [ ] 收集用户反馈

---

## 🆘 常见问题

### Q1: 数据库报错 "extension does not exist"
```sql
-- 解决: 手动启用扩展
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

### Q2: Xcode 找不到类型
```
解决: 
1. Clean Build Folder (Shift+Cmd+K)
2. 重启 Xcode
3. 检查 Target Membership
```

### Q3: 搜索无结果
```sql
-- 检查数据是否初始化
SELECT COUNT(*) FROM user_features WHERE searchable_text IS NOT NULL;

-- 如果为0，手动触发更新
UPDATE user_features uf
SET searchable_text = generate_searchable_text(uf.user_id)
WHERE user_id IN (SELECT user_id FROM profiles);
```

---

## 🔄 回滚方案

如果出现问题：

```swift
// ExploreView.swift 第269行
// 修改为使用 V1.0
let ranked = rankRecommendations(  // V1.0函数
    recommendations, 
    query: trimmed, 
    currentUserProfile: currentUserProfile
)
```

---

## 📞 支持

**技术负责人**: BrewNet Team Heady  
**文档**: 参考 `HEADHUNTING_V2_DEPLOYMENT_GUIDE.md`  
**紧急**: 检查日志 + 回滚到V1.0

---

**预计部署时间**: 10分钟  
**风险等级**: 🟢 低（有回滚方案）  
**建议时间**: 非高峰期

✅ **准备就绪，可以部署！**

