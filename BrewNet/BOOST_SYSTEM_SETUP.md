# Boost 和 Superboost 系统设置文档

## 概述
已成功实现 Boost 和 Superboost 功能，允许用户增加其个人资料的曝光度。

## 数据库设置

### 1. 运行 SQL 文件
在 Supabase 数据库中运行以下 SQL 文件：
```bash
BrewNet/add_boost_columns.sql
```

这将添加以下字段到 `users` 表：
- `boost_count` (INTEGER) - 用户拥有的普通 boost 数量
- `superboost_count` (INTEGER) - 用户拥有的 superboost 数量
- `active_boost_expiry` (TIMESTAMPTZ) - 当前激活的 boost 过期时间
- `active_superboost_expiry` (TIMESTAMPTZ) - 当前激活的 superboost 过期时间
- `boost_last_used` (TIMESTAMPTZ) - 上次使用 boost 的时间
- `superboost_last_used` (TIMESTAMPTZ) - 上次使用 superboost 的时间

### 2. 测试数据库
可以手动为测试用户添加一些 boost：
```sql
-- 给用户添加测试 boosts
UPDATE users 
SET boost_count = 3, superboost_count = 1
WHERE id = 'YOUR_USER_ID';
```

## 功能说明

### 1. 购买 Boost (ProfileDisplayView)
用户可以从个人资料页面购买 boost：
- **1 Boost** - $9.99 (单次使用)
- **3 Boosts** - $26.99 (节省 10%)
- **5 Boosts** - $39.99 (节省 20%)
- **Superboost** - $29.99 (24小时超级曝光)

购买成功后，boost 数量会自动添加到用户账户。

### 2. 使用 Boost (IncreaseExposureView)
用户可以在主页 Match 卡片页面点击右上角的星星图标来使用 boost：

#### Superboost 特性：
- **持续时间**: 24小时
- **曝光倍数**: 100x
- **效果**: 成为所在区域的顶级资料

#### 普通 Boost 特性：
- **持续时间**: 1小时
- **曝光倍数**: 11x
- **效果**: 增加资料曝光度

### 3. UI/UX 流程

#### 购买流程：
1. 用户进入个人资料页面
2. 点击 "Boost" 卡片
3. 选择要购买的 boost 套餐
4. 点击购买按钮
5. 系统显示购买成功，boost 数量增加

#### 使用流程：
1. 用户在主页点击右上角星星图标
2. 查看可用的 boost/superboost 数量
3. 选择要使用的类型
4. 点击 "Use Boost" 或 "Use Superboost"
5. 系统激活 boost，显示成功消息

## 界面设计

### IncreaseExposureView
- **顶部标题**: "Increase Exposure"
- **副标题**: "Boost your profile visibility"
- **两张卡片**:
  - Superboost 卡片 (金色星星图标)
  - Boost 卡片 (青绿色闪电图标)
- 每张卡片显示：
  - 图标和标题
  - 可用数量（右上角圆形徽章）
  - 曝光倍数和持续时间
  - 描述文本
  - 使用按钮

### BoostPurchaseView
- 优化了上拉展开高度（600px）
- 购买按钮显示加载状态
- 购买成功后显示确认消息
- 背景色填充整个面板，无白色留白

## 技术实现

### 文件修改：
1. **BrewNet/add_boost_columns.sql** (新建)
   - 添加数据库字段和索引

2. **BrewNet/BrewNet/BrewNetMatchesView.swift**
   - 重新设计 `IncreaseExposureView`
   - 添加 `ExposureBoostCard` 组件
   - 实现 `useBoost()` 和 `useSuperboost()` 方法

3. **BrewNet/BrewNet/ProfileDisplayView.swift**
   - 更新 `BoostPurchaseView` 的 `handlePurchase()` 方法
   - 添加购买确认和错误处理
   - 优化上拉面板样式

### 关键方法：

#### 加载 Boost 数量
```swift
private func loadBoostCounts() {
    // 从数据库获取当前用户的 boost 数量
}
```

#### 使用 Boost
```swift
private func useBoost() {
    // 1. 检查用户是否有可用的 boost
    // 2. 计算过期时间（1小时后）
    // 3. 更新数据库（减少计数，设置过期时间）
    // 4. 显示成功消息
}
```

#### 使用 Superboost
```swift
private func useSuperboost() {
    // 1. 检查用户是否有可用的 superboost
    // 2. 计算过期时间（24小时后）
    // 3. 更新数据库（减少计数，设置过期时间）
    // 4. 显示成功消息
}
```

#### 处理购买
```swift
private func handlePurchase(option: BoostOption) {
    // 1. 确定购买的 boost 数量
    // 2. 获取当前数量
    // 3. 更新数据库（增加 boost 计数）
    // 4. 显示购买成功消息
}
```

## 后续改进建议

1. **集成真实支付系统**
   - 集成 Apple Pay / Stripe
   - 添加支付确认流程

2. **推荐算法集成**
   - 在推荐系统中考虑活跃的 boost
   - 为使用 boost 的用户提高排名权重

3. **统计和分析**
   - 追踪 boost 使用效果
   - 显示 boost 期间的浏览量增加

4. **通知系统**
   - Boost 即将过期提醒
   - Boost 过期后的统计报告

5. **UI 增强**
   - 添加 boost 激活状态指示器
   - 在个人资料页面显示剩余时间

## 测试清单

- [x] 创建数据库字段
- [x] 实现购买 boost 功能
- [x] 实现使用 boost 功能
- [x] 实现使用 superboost 功能
- [x] 添加错误处理
- [x] 优化 UI/UX
- [ ] 运行数据库迁移
- [ ] 测试购买流程
- [ ] 测试使用流程
- [ ] 验证数据库更新

## 注意事项

1. 确保在 Supabase 中正确设置 RLS (Row Level Security) 策略
2. 购买功能目前是模拟的，需要集成真实支付系统
3. Boost 过期后需要实现清理机制
4. 建议添加日志记录以追踪 boost 使用情况

