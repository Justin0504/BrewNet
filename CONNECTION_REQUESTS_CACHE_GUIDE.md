# Connection Requests 缓存实现文档

## 📦 概述

为 Connection Requests 和 Temporary Chat 添加了本地缓存功能，提升加载速度和用户体验。

## ✨ 实现的功能

### 1. **缓存机制**
- **存储方式**: UserDefaults（本地持久化）
- **缓存过期时间**: 5分钟（因为临时消息更新频繁）
- **缓存内容**: 
  - Connection Requests 列表
  - 每个请求的 Temporary Messages（最多10条）
  - 用户资料信息
  - Pro 用户状态

### 2. **缓存策略**
- ✅ **首次加载**: 先从缓存读取，立即显示数据
- ✅ **后台刷新**: 异步从服务器获取最新数据并更新缓存
- ✅ **智能更新**: 数据变化时才更新UI
- ✅ **自动清理**: 接受/拒绝请求时自动从缓存移除

## 📁 代码位置

### 1. **LocalCacheManager 扩展**
**文件**: `BrewNet/BrewNet/ProfileDisplayView.swift`

新增方法：
```swift
// 保存 Connection Requests 数据
func saveConnectionRequestsData(userId: String, requests: [ConnectionRequest])

// 加载 Connection Requests 数据
func loadConnectionRequestsData(userId: String) -> ConnectionRequestsCacheData?

// 快速更新单个请求的临时消息
func updateConnectionRequestMessages(userId: String, requestId: String, messages: [TemporaryMessage])

// 清除单个连接请求的缓存
func invalidateConnectionRequest(userId: String, requestId: String)
```

### 2. **ConnectionRequestsView 修改**
**文件**: `BrewNet/BrewNet/ConnectionRequestsView.swift`

修改的方法：
- `loadConnectionRequests()` - 添加缓存读取逻辑
- `handleAccept()` - 接受请求后清除缓存
- `handleReject()` - 拒绝请求后清除缓存

新增方法：
- `refreshConnectionRequestsInBackground()` - 后台刷新数据
- `updateUnreadTemporaryMessageCount()` - 同步更新未读消息数

## 🔄 工作流程

### 首次加载流程
```
用户打开 Connection Requests 页面
    ↓
检查缓存
    ↓
缓存存在且未过期？
    ├─ 是 → 立即显示缓存数据
    │        ↓
    │     后台刷新最新数据
    │        ↓
    │     更新缓存和UI（如有变化）
    │
    └─ 否 → 从 Supabase 加载数据
             ↓
          保存到缓存
             ↓
          显示数据
```

### 接受/拒绝请求流程
```
用户点击接受/拒绝按钮
    ↓
从UI列表移除请求
    ↓
发送请求到 Supabase
    ↓
成功？
    ├─ 是 → 从缓存中移除该请求
    │        ↓
    │     发送通知
    │
    └─ 否 → 恢复UI列表
             ↓
          显示错误信息
```

## 📊 缓存数据结构

```swift
struct ConnectionRequestsCacheData: Codable {
    var requests: [ConnectionRequest]  // 请求列表
    let timestamp: Date?                // 缓存时间戳
}

// ConnectionRequest 包含：
struct ConnectionRequest {
    let id: String
    let requesterId: String
    let requesterName: String
    let requesterProfile: ConnectionRequestProfile
    let reasonForInterest: String?
    let createdAt: Date
    let isFeatured: Bool
    var temporaryMessages: [TemporaryMessage]  // 临时消息列表
    var isRequesterPro: Bool
}
```

## 🎯 使用示例

### 在其他视图中清除缓存

如果你在其他地方需要强制刷新 Connection Requests：

```swift
// 清除单个请求的缓存
LocalCacheManager.shared.invalidateConnectionRequest(
    userId: currentUser.id, 
    requestId: requestId
)

// 清除所有缓存（包括 Connection Requests）
LocalCacheManager.shared.clearCache(userId: currentUser.id)
```

### 手动更新临时消息缓存

```swift
// 快速更新某个请求的临时消息（不重新加载整个列表）
LocalCacheManager.shared.updateConnectionRequestMessages(
    userId: currentUser.id,
    requestId: requestId,
    messages: updatedMessages
)
```

## 🔍 调试日志

缓存操作会输出详细的日志，方便调试：

```
💾 [Cache] 已保存 Connection Requests 数据到本地缓存（包含 3 个请求）
   📩 包含 5 条临时消息

📦 [Cache] 从本地缓存加载 Connection Requests 数据（3 个请求，45 秒前）
   📩 包含 5 条临时消息

🔄 [ConnectionRequests] 后台刷新数据中...
🔄 [ConnectionRequests] 后台刷新完成，数据已更新

🗑️ [Cache] 已从缓存中移除请求: abc-123-def

⏰ [Cache] Connection Requests 缓存已过期 (320 秒前)
```

## ⚡ 性能优化

### 优化点
1. **即时响应**: 从缓存加载数据，用户无需等待网络请求
2. **后台刷新**: 不阻塞UI，在后台异步更新数据
3. **智能更新**: 只在数据真正变化时才更新UI
4. **局部更新**: 接受/拒绝请求时只更新单条记录，不重新加载整个列表
5. **消息限制**: 每个请求最多缓存10条临时消息，避免缓存过大

### 缓存大小估算
- 每个 ConnectionRequest: ~2-3 KB
- 10条临时消息: ~1-2 KB
- 总计（假设10个请求）: ~30-50 KB

## 🔒 注意事项

### 1. 缓存一致性
- 缓存会在5分钟后自动过期
- 接受/拒绝请求时会自动清除对应缓存
- 建议在发送新的临时消息后手动刷新缓存

### 2. 数据同步
- 后台刷新会自动保持数据同步
- 如果需要强制刷新，调用 `loadConnectionRequests()` 即可

### 3. 用户登出
- 清除缓存时建议调用 `LocalCacheManager.shared.clearCache(userId:)`
- 确保不会泄露用户隐私数据

## 📝 与其他缓存系统的对比

| 缓存类型 | 存储方式 | 过期时间 | 主要用途 |
|---------|---------|---------|---------|
| **ConnectionRequestsCache** | UserDefaults | 5分钟 | 连接请求 + 临时消息 |
| **CredibilityScoreCache** | 内存字典 | 5分钟 | 信誉评分数据 |
| **ImageCacheManager** | 内存+磁盘 | 7天 | 用户头像图片 |
| **LocalCacheManager** (其他) | UserDefaults | 12-24小时 | Credits/Redeem/Chats |

## 🎉 优势

1. ✅ **快速响应**: 用户打开页面立即看到数据
2. ✅ **节省流量**: 减少重复的网络请求
3. ✅ **离线支持**: 在网络不佳时仍能显示缓存数据
4. ✅ **用户体验**: 无需等待加载，流畅的交互体验
5. ✅ **智能刷新**: 后台自动更新，保持数据最新

## 🚀 未来改进

可能的优化方向：
- [ ] 添加增量更新（只更新变化的请求）
- [ ] 支持本地消息预加载
- [ ] 添加缓存统计和监控
- [ ] 实现更精细的缓存失效策略
- [ ] 支持多用户账号切换时的缓存隔离

---

**实现日期**: 2025-11-22  
**版本**: 1.0  
**维护者**: BrewNet Team

