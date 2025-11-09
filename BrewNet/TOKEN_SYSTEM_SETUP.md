# Token 充值系统设置指南

## 📋 概述

Token 充值系统允许用户购买 Tokens 用于 Coffee Chat 邀请和其他高级功能。

## 🎯 功能特性

### UI 功能
- ✅ ProfileDisplayView 中添加了 "Buy Tokens" 卡片
- ✅ Token 购买界面（TokenPurchaseView）
- ✅ 5 个价格档位的轮播展示
- ✅ 与 Boost 购买界面风格一致
- ✅ 显示价格、数量、优惠、单价等详细信息

### 价格档位

| 价格 (USD) | Tokens 数量 | 说明 | 单价折算 | 优惠 |
|-----------|------------|-----|---------|-----|
| $4.99 | 50 Tokens | 体验包，适合首次尝试 | ≈ $0.10 / Token | - |
| $9.99 | 120 Tokens | 最常用档位 | ≈ $0.083 / Token | +20% Bonus |
| $19.99 | 260 Tokens | 热门档位 | ≈ $0.077 / Token | +30% Bonus |
| $49.99 | 700 Tokens | 专业用户档 | ≈ $0.071 / Token | +40% Bonus |
| $99.99 | 1,500 Tokens | Mentor / Power User 套餐 | ≈ $0.066 / Token | +50% Bonus |

## 🗄️ 数据库设置

### 1. 执行 SQL 脚本

在 Supabase Dashboard 中执行 `add_tokens_column.sql`：

```sql
-- 添加 tokens 字段到 users 表
ALTER TABLE users
ADD COLUMN IF NOT EXISTS tokens INT DEFAULT 0;

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_users_tokens ON users(tokens);
```

### 2. 验证

```sql
-- 查看字段是否已添加
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name = 'tokens';

-- 查看当前用户的 tokens
SELECT id, email, tokens FROM users ORDER BY tokens DESC LIMIT 10;
```

## 📱 使用方法

### 用户端

1. 在 Profile 页面找到 "Buy Tokens" 卡片
2. 点击打开充值界面
3. 左右滑动查看不同价格档位
4. 选择合适的档位
5. 点击 "Purchase" 按钮完成购买

### 开发者端

#### 查询用户 Token 余额

```swift
let userId = authManager.currentUser?.id
let response = try await SupabaseConfig.shared.client
    .from("users")
    .select("tokens")
    .eq("id", userId)
    .single()
    .execute()
```

#### 扣除 Tokens（使用功能时）

```swift
// 例如：发送 Coffee Chat 邀请扣除 5 tokens
let userId = authManager.currentUser?.id
let currentTokens = // ... 查询当前 tokens
let newTokens = currentTokens - 5

try await SupabaseConfig.shared.client
    .from("users")
    .update(["tokens": newTokens])
    .eq("id", userId)
    .execute()
```

#### 增加 Tokens（购买时）

```swift
// 购买成功后增加 tokens
let userId = authManager.currentUser?.id
let currentTokens = // ... 查询当前 tokens
let purchasedTokens = 120 // 用户购买的数量
let newTokens = currentTokens + purchasedTokens

try await SupabaseConfig.shared.client
    .from("users")
    .update(["tokens": newTokens])
    .eq("id", userId)
    .execute()
```

## 🔄 与现有系统集成

### Coffee Chat 系统

修改 `sendInvitation` 函数，在发送邀请前检查并扣除 tokens：

```swift
func sendInvitation(to userId: String, message: String) async throws {
    // 1. 检查 token 余额
    let currentUser = authManager.currentUser
    guard let tokens = currentUser?.tokens, tokens >= 5 else {
        throw InvitationError.insufficientTokens
    }
    
    // 2. 扣除 tokens
    try await deductTokens(userId: currentUser.id, amount: 5)
    
    // 3. 发送邀请
    // ... 现有的邀请逻辑
}
```

## 💳 支付集成（待实现）

### 需要集成的支付方式

1. **Apple Pay / In-App Purchase (推荐)**
   - 适用于 iOS App
   - 需要配置 App Store Connect
   - 符合 Apple 审核要求

2. **Stripe**
   - 适用于 Web 版
   - 支持信用卡支付
   - 需要后端 API 配合

### 实现步骤

1. 创建支付后端 API
2. 集成支付 SDK
3. 实现支付回调
4. 验证支付成功后更新数据库
5. 记录交易历史

## 📊 数据库表结构建议

### users 表（已添加）
- `tokens` (INT): 用户当前的 token 余额

### 建议新增：token_transactions 表（可选）
用于记录所有 token 交易历史：

```sql
CREATE TABLE token_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    amount INT NOT NULL, -- 正数表示增加，负数表示扣除
    type VARCHAR(50) NOT NULL, -- 'purchase', 'usage', 'refund', 'bonus'
    description TEXT,
    related_id UUID, -- 关联的订单/邀请 ID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_token_transactions_user ON token_transactions(user_id);
CREATE INDEX idx_token_transactions_created ON token_transactions(created_at);
```

## 🎨 UI 样式说明

### TokenCard
- 黄色主题 (`Color(red: 0.9, green: 0.7, blue: 0.2)`)
- 信用卡图标 (`creditcard.fill`)
- 与 BoostCard 相似的布局

### TokenPurchaseView
- 轮播式展示 5 个价格档位
- 显示 Bonus 徽章
- 棕色系配色方案
- 700pt 高度的 sheet 展示

## ⚠️ 注意事项

1. **支付安全**：实际支付逻辑需要在后端实现，不能仅在客户端完成
2. **交易记录**：建议记录所有 token 交易历史以便审计
3. **余额同步**：确保客户端和服务器的 token 余额保持同步
4. **防止重复购买**：实现幂等性检查，防止用户重复支付
5. **退款机制**：考虑实现 token 退款功能

## 🔐 安全建议

1. 所有 token 操作必须在服务器端验证
2. 使用数据库事务确保操作原子性
3. 记录所有 token 变更的审计日志
4. 实现防刷机制，限制异常操作

## 📝 TODO

- [ ] 实现实际的支付集成（Apple Pay / Stripe）
- [ ] 创建后端 API 处理支付回调
- [ ] 实现交易历史记录表
- [ ] 在 TokenCard 上显示用户当前的 token 余额
- [ ] 实现 token 余额不足提示
- [ ] 添加购买成功/失败的提示动画

## 📞 相关文件

- `ProfileDisplayView.swift` - 主要实现文件
  - `TokenCard` - Token 充值入口卡片
  - `TokenPurchaseView` - Token 购买界面
  - `TokenOption` - Token 选项模型
  - `TokenOptionCard` - Token 选项卡片

- `add_tokens_column.sql` - 数据库迁移脚本

## 🎉 完成状态

- ✅ UI 界面完成
- ✅ 数据库配置完成
- ✅ 基础逻辑框架完成
- ⏳ 支付集成待实现
- ⏳ 交易历史待实现
- ⏳ 余额显示待实现

