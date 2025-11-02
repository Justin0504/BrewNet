# 统计每个 Main Intention 的用户数量

## 概述

本文档提供了在 Supabase 数据库中统计每个 Networking Intention 用户数量的 SQL 查询方法。

## 数据库结构

`profiles` 表中的 `networking_intention` 列是 JSONB 类型，包含以下结构：

```json
{
  "selected_intention": "Learn & Grow",
  "selected_sub_intentions": [...],
  ...
}
```

## SQL 查询方法

### 方法 1：使用 Postgres JSONB 操作符查询（推荐）

这是最直接的方法，利用了 Postgres 的 JSONB 操作符：

```sql
-- 统计每个 Main Intention 的用户数量
SELECT 
    networking_intention->>'selected_intention' as intention,
    COUNT(*) as user_count
FROM profiles
GROUP BY networking_intention->>'selected_intention'
ORDER BY user_count DESC;
```

**结果示例：**
```
intention              | user_count
--------------------- | -----------
Learn & Grow          | 937
Connect & Share       | 426
Build & Collaborate   | 1300
Unwind & Chat         | 1500
```

### 方法 2：单独查询每个 Intention

如果需要单独获取某个 Intention 的用户数量：

```sql
-- 查询 "Learn & Grow" 的用户数量
SELECT COUNT(*) 
FROM profiles 
WHERE networking_intention->>'selected_intention' = 'Learn & Grow';

-- 查询 "Connect & Share" 的用户数量
SELECT COUNT(*) 
FROM profiles 
WHERE networking_intention->>'selected_intention' = 'Connect & Share';

-- 查询 "Build & Collaborate" 的用户数量
SELECT COUNT(*) 
FROM profiles 
WHERE networking_intention->>'selected_intention' = 'Build & Collaborate';

-- 查询 "Unwind & Chat" 的用户数量
SELECT COUNT(*) 
FROM profiles 
WHERE networking_intention->>'selected_intention' = 'Unwind & Chat';
```

### 方法 3：创建视图（可选）

如果频繁查询，可以创建一个视图：

```sql
-- 创建视图
CREATE OR REPLACE VIEW intention_user_counts AS
SELECT 
    networking_intention->>'selected_intention' as intention,
    COUNT(*) as user_count
FROM profiles
GROUP BY networking_intention->>'selected_intention';

-- 使用视图查询
SELECT * FROM intention_user_counts ORDER BY user_count DESC;
```

### 方法 4：排除当前用户

如果需要排除特定用户（例如当前登录用户）：

```sql
-- 统计每个 Intention 的用户数量（排除 user_id='xxx'）
SELECT 
    networking_intention->>'selected_intention' as intention,
    COUNT(*) as user_count
FROM profiles
WHERE user_id != 'your-user-id-here'  -- 替换为实际的用户 ID
GROUP BY networking_intention->>'selected_intention'
ORDER BY user_count DESC;
```

## 应用内实现

在 Swift 应用中，我们已经实现了以下功能：

### 1. SupabaseService 方法

```swift
// 获取所有 Intention 的用户数量映射
func getUserCountsByAllIntentions() async throws -> [String: Int]
```

该方法获取最多 10,000 个 profiles，然后在客户端统计每个 intention 的用户数量。

### 2. ExploreView 数据加载

在 `ExploreMainView` 中，使用 `loadUserCounts()` 方法加载数据：

```swift
@State private var userCounts: [String: Int] = [:]

private func loadUserCounts() {
    Task {
        do {
            let counts = try await supabaseService.getUserCountsByAllIntentions()
            await MainActor.run {
                self.userCounts = counts
            }
        } catch {
            print("❌ Failed to load user counts: \(error)")
        }
    }
}
```

### 3. 实时显示

用户数量会在 `ExploreCategoryCard` 中实时显示，格式化为 K（千）单位：

- 1000+ = 1K, 1.1K, 1.2K, etc.
- 10000+ = 10K, 11K, 12K, etc.

## 性能优化

### 当前实现限制

当前实现限制最多获取 10,000 个 profiles。如果数据库中有更多用户，建议：

1. **数据库端实现**：使用 Postgres 函数或视图
2. **缓存机制**：定期更新计数，避免每次都查询所有数据
3. **索引优化**：考虑为 `networking_intention` 创建 GIN 索引

### GIN 索引（可选）

如果查询频繁，可以创建 GIN 索引以提升性能：

```sql
-- 创建 GIN 索引
CREATE INDEX idx_profiles_networking_intention ON profiles 
USING GIN (networking_intention);
```

## 在 Supabase Dashboard 中执行

1. 登录 Supabase Dashboard
2. 进入 SQL Editor
3. 选择你的项目数据库
4. 粘贴上述 SQL 查询
5. 点击 "Run" 执行查询

## 验证查询

执行以下查询验证数据结构是否正确：

```sql
-- 查看示例数据
SELECT 
    id,
    networking_intention->>'selected_intention' as intention,
    networking_intention
FROM profiles
LIMIT 10;
```

确保 `selected_intention` 字段包含以下值之一：
- "Learn & Grow"
- "Connect & Share"
- "Build & Collaborate"
- "Unwind & Chat"

## 故障排除

### 问题：查询返回空结果

**可能原因**：
1. 数据格式不匹配
2. JSON 结构错误

**解决方案**：
```sql
-- 检查数据格式
SELECT networking_intention FROM profiles LIMIT 1;
```

### 问题：计数不准确

**可能原因**：
1. 某些 profiles 的 `networking_intention` 为 NULL
2. 字段名称拼写错误

**解决方案**：
```sql
-- 检查 NULL 值
SELECT COUNT(*) FROM profiles WHERE networking_intention IS NULL;

-- 检查字段值
SELECT DISTINCT networking_intention->>'selected_intention' 
FROM profiles;
```

