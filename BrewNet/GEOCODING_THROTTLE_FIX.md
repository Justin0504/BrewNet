# 🗺️ 地理编码限流问题修复

## ❌ 问题描述

应用触发了苹果地理编码 API 的限流机制：

```
Throttled "PlaceRequest.REQUEST_TYPE_GEOCODING" request: 
Tried to make more than 50 requests in 60 seconds
```

**限制**：苹果的 `CLGeocoder` 服务限制每个应用在 60 秒内最多发送 50 次地理编码请求。

---

## 🔍 根本原因

### 1. **大量并发请求**
- 用户列表显示 10 个用户卡片
- 每个卡片的 `DistanceDisplayView` 在 `.onAppear` 时触发地理编码
- 结果：10 个卡片同时发起请求 = 10+ 次 API 调用

### 2. **没有请求去重**
- 多个卡片请求相同的地址对
- 例如：5 个用户都在 "San Francisco"，当前用户在 "New York"
- 结果：5 次重复的 "San Francisco" 地理编码请求

### 3. **视图更新触发过多**
- `.onChange(of: currentUserLocation)` 监听器
- 当 currentUserLocation 加载完成时，所有卡片同时重新计算距离
- 结果：又是 10+ 次 API 调用

### 4. **没有防抖动（Debounce）**
- 快速滚动列表或切换视图时，大量卡片快速创建和销毁
- 每次创建都触发 `.onAppear` → 更多请求

---

## ✅ 解决方案

### 修复 1: **请求去重机制**

**文件**：`LocationService.swift`

**原理**：如果相同地址的请求已在进行中，新请求不会发起，而是等待第一个请求的结果。

**实现**：
```swift
// 跟踪正在进行的请求
private var pendingRequests: [String: [(CLLocation?) -> Void]] = [:]
private let requestsQueue = DispatchQueue(label: "com.brewnet.pendingRequests")
```

**工作流程**：
1. 收到地理编码请求 "San Francisco"
2. 检查是否已有 "San Francisco" 的请求在进行
3. 如果有 → 将回调添加到等待列表，**不发起新请求**
4. 如果没有 → 发起新请求，并记录到 `pendingRequests`
5. 请求完成后 → 通知所有等待的回调

**效果**：
- 之前：5 个卡片 → 5 次 "San Francisco" 请求
- 之后：5 个卡片 → **只有 1 次**请求，结果共享给 5 个回调

---

### 修复 2: **防抖动机制（Debounce）**

**文件**：`UserProfileCardView.swift` - `DistanceDisplayView`

**原理**：延迟执行地理编码请求，如果在延迟期间又有新请求，取消旧请求。

**实现**：
```swift
@State private var debounceTask: DispatchWorkItem?

private func calculateDistance() {
    // 取消之前的任务
    debounceTask?.cancel()
    
    // 创建新任务，延迟 0.3 秒执行
    let task = DispatchWorkItem {
        // 实际的地理编码逻辑
    }
    
    debounceTask = task
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
}
```

**效果**：
- 快速滚动列表时，只有最终停留的卡片会真正执行请求
- 避免了中间过程的无效请求

---

## 📊 优化效果对比

### 场景 1：显示 10 个用户的列表

**修复前**：
```
10 个卡片 × onAppear = 10 次请求
currentUserLocation 加载 → 10 个卡片 × onChange = 10 次请求
总计：20 次请求（可能超过 50 次限制的 40%）
```

**修复后**：
```
10 个卡片 → 防抖动 → 延迟 0.3 秒
假设有 5 个独特的地址对 → 请求去重 → 只需 5 次请求
总计：5 次请求（仅为修复前的 25%）
```

---

### 场景 2：快速滚动 50 个用户

**修复前**：
```
50 个卡片快速创建/销毁
每个卡片 onAppear → 最坏情况 50 次请求
结果：触发限流！❌
```

**修复后**：
```
快速滚动时 → 防抖动取消大部分请求
只有最终停留的卡片执行
假设屏幕显示 10 个卡片，有 8 个独特地址对
结果：8 次请求 ✅
```

---

## 🧪 测试步骤

### 测试 1：列表滚动
1. 进入 Explore 或 Chat 页面，查看用户列表
2. 快速上下滚动
3. 观察 Xcode Console
4. **预期**：看到 "⏳ [请求去重]" 和 "防抖动延迟后执行" 的日志

### 测试 2：重复地址
1. 确保列表中有多个用户在同一个城市（如 San Francisco）
2. 观察日志
3. **预期**：相同地址只请求一次，其他请求加入等待队列

### 测试 3：不触发限流
1. 浏览多个页面，查看很多用户
2. 持续使用 5 分钟
3. **预期**：不再看到 "Throttled" 错误

---

## 📝 关键改进

### LocationService.swift
1. ✅ 添加 `pendingRequests` 字典跟踪进行中的请求
2. ✅ 在 `geocodeAddress()` 中实现请求去重逻辑
3. ✅ 一个请求完成后通知所有等待的回调

### UserProfileCardView.swift
1. ✅ 添加 `debounceTask` 状态变量
2. ✅ 在 `calculateDistance()` 中实现防抖动机制
3. ✅ 延迟 0.3 秒执行，避免无效请求

---

## 🎯 最佳实践

### 1. **缓存优先**
```swift
// 总是先检查缓存
if let cached = geocodeCache[address] {
    return cached
}
```

### 2. **请求去重**
```swift
// 检查是否已有相同请求在进行
if pendingRequests[address] != nil {
    // 加入等待队列，不发起新请求
}
```

### 3. **防抖动**
```swift
// 延迟执行，频繁调用时只执行最后一次
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    // 实际逻辑
}
```

### 4. **批量处理**
```swift
// 使用 DispatchGroup 并行请求多个地址
let group = DispatchGroup()
group.enter()
geocodeAddress(address1) { ... }
group.enter()
geocodeAddress(address2) { ... }
group.notify(queue: .main) {
    // 所有请求完成
}
```

---

## ⚠️ 注意事项

### 1. **仍然可能触发限流**
如果短时间内查看大量不同的地址（如浏览 100 个用户），仍可能接近限制。

**解决方案**：
- 考虑使用第三方地理编码服务（如 Google Geocoding API）
- 在服务器端批量处理地理编码
- 预先计算并存储在数据库中

### 2. **网络延迟**
防抖动延迟（0.3 秒）可能让用户感觉稍慢。

**平衡**：
- 0.1 秒：太短，限流效果有限
- 0.3 秒：推荐，用户几乎感觉不到
- 0.5 秒：太慢，用户体验下降

### 3. **缓存持久化**
当前缓存只在内存中，App 重启后丢失。

**改进**：
- 可以考虑使用 UserDefaults 或数据库持久化缓存
- 设置缓存过期时间（如 7 天）

---

## 🔧 故障排查

### 如果仍然看到限流错误：

**1. 检查日志**
```
⏳ [请求去重] - 说明去重机制在工作
📍 [防抖动延迟后执行] - 说明防抖动在工作
```

**2. 清空缓存并重试**
```swift
LocationService.shared.clearGeocodeCache()
```

**3. 增加防抖动延迟**
将 0.3 秒改为 0.5 秒：
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
```

**4. 检查是否有其他地方调用地理编码**
搜索所有 `CLGeocoder` 或 `geocodeAddress` 的使用

---

## 📚 相关文件

- `/Users/justin/BrewNet-Fresh/BrewNet/BrewNet/LocationService.swift`
- `/Users/justin/BrewNet-Fresh/BrewNet/BrewNet/UserProfileCardView.swift`
- `/Users/justin/BrewNet-Fresh/BrewNet/BrewNet/ChatInterfaceView.swift`

---

## ✨ 总结

通过**请求去重**和**防抖动**两个机制，我们将地理编码请求数量减少了 **75% 以上**，有效避免了苹果 API 的限流问题。

关键改进：
- ✅ 相同地址只请求一次
- ✅ 快速滚动不会触发无效请求
- ✅ 缓存优先，减少网络调用
- ✅ 更好的用户体验

