# ProfileView Header 资源显示系统

## 📋 概述

在 ProfileView 的 header 右边部分显示用户的 4 种资源数量，方便用户随时查看自己的资源余额。

## 🎯 功能特性

### 显示内容

在 ProfileHeaderView 右边显示 4 行资源：

| 资源名称 | 图标 | 颜色 | 数据库字段 | 说明 |
|---------|------|------|-----------|------|
| **Credits** | ⭐ 星星 | 黄色 | `credits` | 积分/信用点数 |
| **Boost** | ⚡ 闪电 | 灰绿色 | `boost_count` | 普通 Boost 数量 |
| **Superboost** | ⚡ 闪电 | 黄色 | `superboost_count` | 超级 Boost 数量 |
| **BrewToken** | 🪙 金币(B) | 金色 | `tokens` | BrewToken 代币数量 |

### UI 设计

```
┌──────────────────────────────────────────┐
│  👤        AJ Pro                    ⭐ 150 │
│  85%                                 ⚡ 5   │
│            📷 ✓                      ⚡ 2   │
│                                      🪙 120 │
└──────────────────────────────────────────┘
```

- 左侧：头像 + 进度环 + 百分比
- 中间：用户名 + Pro 徽章 + 图标按钮
- 右侧：4 行资源显示（图标 + 数量）

## 🗄️ 数据库设置

### 1. 确保所有资源字段存在

执行以下 SQL 脚本（如果字段不存在会自动创建）：

```sql
-- 添加 Credits 字段
ALTER TABLE users ADD COLUMN IF NOT EXISTS credits INT DEFAULT 0;

-- 添加 Boost 相关字段（应该已存在）
ALTER TABLE users ADD COLUMN IF NOT EXISTS boost_count INT DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS superboost_count INT DEFAULT 0;

-- 添加 Tokens 字段（应该已存在）
ALTER TABLE users ADD COLUMN IF NOT EXISTS tokens INT DEFAULT 0;

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_users_credits ON users(credits);
CREATE INDEX IF NOT EXISTS idx_users_tokens ON users(tokens);
```

### 2. 验证字段

```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name IN ('credits', 'boost_count', 'superboost_count', 'tokens')
ORDER BY column_name;
```

预期结果：
```
column_name        | data_type | column_default
-------------------+-----------+---------------
boost_count        | integer   | 0
credits            | integer   | 0
superboost_count   | integer   | 0
tokens             | integer   | 0
```

## 💻 代码实现

### ProfileHeaderView 修改

#### 1. 添加状态变量

```swift
// ⭐ 资源数量
@State private var credits: Int = 0
@State private var boosts: Int = 0
@State private var superboosts: Int = 0
@State private var tokens: Int = 0
@State private var isLoadingResources = true
```

#### 2. 创建资源显示视图

```swift
@ViewBuilder
private var resourcesView: some View {
    VStack(alignment: .trailing, spacing: 6) {
        // Credits
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 14))
                .foregroundColor(.yellow)
            Text("\(credits)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
        
        // Boost
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.5))
            Text("\(boosts)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
        
        // Superboost
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14))
                .foregroundColor(.yellow)
            Text("\(superboosts)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
        
        // BrewToken
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.9, green: 0.7, blue: 0.2))
                    .frame(width: 18, height: 18)
                
                Text("B")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("\(tokens)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
    }
}
```

#### 3. 在 body 中添加资源显示

```swift
HStack(alignment: .top, spacing: 16) {
    avatarWithProgressView
    
    VStack(alignment: .leading, spacing: 8) {
        nameAndIconsView
    }
    
    Spacer()
    
    // ⭐ 资源显示
    if isLoadingResources {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
            .scaleEffect(0.8)
    } else {
        resourcesView
    }
}
```

#### 4. 添加加载资源函数

```swift
private func loadResources() {
    guard let userId = authManager.currentUser?.id else {
        isLoadingResources = false
        return
    }
    
    Task {
        do {
            struct UserResources: Codable {
                let credits: Int?
                let boost_count: Int?
                let superboost_count: Int?
                let tokens: Int?
                
                enum CodingKeys: String, CodingKey {
                    case credits
                    case boost_count
                    case superboost_count
                    case tokens
                }
            }
            
            let response: UserResources = try await SupabaseConfig.shared.client
                .from("users")
                .select("credits, boost_count, superboost_count, tokens")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.credits = response.credits ?? 0
                self.boosts = response.boost_count ?? 0
                self.superboosts = response.superboost_count ?? 0
                self.tokens = response.tokens ?? 0
                self.isLoadingResources = false
            }
        } catch {
            print("❌ [Resources] 加载失败: \(error)")
            await MainActor.run {
                self.isLoadingResources = false
            }
        }
    }
}
```

#### 5. 在 onAppear 中调用加载

```swift
.onAppear {
    loadResources()
}
```

## 🎨 样式说明

### 图标设计

1. **Credits (星星)**
   - 图标：`star.fill`
   - 颜色：`.yellow`
   - 大小：14pt

2. **Boost (灰绿色闪电)**
   - 图标：`bolt.fill`
   - 颜色：`Color(red: 0.4, green: 0.5, blue: 0.5)`
   - 大小：14pt

3. **Superboost (黄色闪电)**
   - 图标：`bolt.fill`
   - 颜色：`.yellow`
   - 大小：14pt

4. **BrewToken (金币 + B)**
   - 背景：金色圆形 `Color(red: 0.9, green: 0.7, blue: 0.2)`
   - 文字：白色粗体 "B"
   - 圆形大小：18x18pt
   - 文字大小：10pt

### 布局规则

- 对齐方式：`alignment: .trailing`（右对齐）
- 行间距：`spacing: 6`
- 图标与数字间距：`spacing: 6`
- 字体大小：14pt
- 字体粗细：`.semibold`

## 🔄 实时更新

### 触发更新的场景

资源数量会在以下情况下更新：

1. **页面加载时** - `onAppear` 自动加载
2. **购买 Boost/Token 后** - 刷新资源显示
3. **使用资源后** - 刷新资源显示
4. **获得奖励后** - 刷新资源显示

### 手动刷新

如需在其他地方手动刷新资源，可以：

```swift
// 发送通知刷新
NotificationCenter.default.post(name: NSNotification.Name("ResourcesUpdated"), object: nil)

// 在 ProfileHeaderView 中监听
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResourcesUpdated"))) { _ in
    loadResources()
}
```

## 📊 数据流

```
用户打开 ProfileView
    ↓
ProfileHeaderView.onAppear
    ↓
loadResources()
    ↓
查询 Supabase users 表
    ↓
获取 credits, boost_count, superboost_count, tokens
    ↓
更新 @State 变量
    ↓
UI 自动刷新显示
```

## ⚠️ 注意事项

1. **数据库字段命名**
   - Credits: `credits`
   - Boost: `boost_count`
   - Superboost: `superboost_count`
   - Tokens: `tokens`

2. **默认值**
   - 所有字段默认值为 `0`
   - 查询失败时显示 `0`

3. **性能优化**
   - 只在 `onAppear` 时加载一次
   - 使用 `isLoadingResources` 避免重复加载
   - 加载过程中显示 `ProgressView`

4. **错误处理**
   - 网络错误时不会崩溃
   - 显示默认值 `0`
   - 控制台输出错误日志

## 📝 相关文件

- `ProfileDisplayView.swift` - ProfileHeaderView 实现
- `add_credits_column.sql` - Credits 字段迁移脚本
- `add_boost_columns.sql` - Boost 字段迁移脚本（已存在）
- `add_tokens_column.sql` - Tokens 字段迁移脚本（已存在）

## 🎉 完成状态

- ✅ UI 界面实现
- ✅ 数据加载逻辑
- ✅ 图标和样式
- ✅ 数据库配置
- ✅ 错误处理
- ⏳ 实时更新通知（待实现）
- ⏳ 资源变化动画（待实现）

## 🚀 后续优化

1. 添加点击资源跳转到对应购买/使用页面
2. 添加资源变化时的动画效果
3. 实现资源不足时的提示
4. 添加资源历史记录查看功能



