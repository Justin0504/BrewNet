# 📍 Location Setup Guide - 位置设置指南

## 问题描述

在查看其他用户的 Profile 或在聊天界面查看距离时，如果显示：
- "Set your location to see distance"（设置你的位置以查看距离）
- `currentUserLocation: nil`

这表示**当前用户没有在自己的 Profile 中设置位置信息**。

## 解决方案

### ✅ 方法 1：通过 App 设置位置（推荐）

1. **打开 Profile 页面**
   - 在 App 底部导航栏点击 "Profile"

2. **进入编辑模式**
   - 点击页面中的 "Edit Profile" 按钮

3. **设置位置**
   - 在 "Basic Information" 步骤中
   - 找到 "Location" 输入框
   - 输入你的位置，例如：
     - `San Francisco, CA, USA`
     - `New York, NY, USA`
     - `Beijing, China`
   
4. **使用自动定位（可选）**
   - 点击 "📍 Use Current Location" 按钮
   - 授权位置权限
   - App 会自动获取并填充你的当前位置

5. **保存设置**
   - 点击 "Save" 或 "Next" 按钮
   - 完成 Profile 更新流程

### ✅ 方法 2：通过数据库直接更新（开发/测试用）

如果需要直接在数据库中设置位置（例如开发测试时）：

1. **打开 Supabase Dashboard**
   - 进入 SQL Editor

2. **执行查询脚本**
   ```sql
   -- 运行 check_user_location.sql 中的查询
   -- 查看当前位置状态
   
   -- 如果需要手动设置，取消注释以下命令：
   UPDATE profiles 
   SET core_identity = jsonb_set(
       core_identity,
       '{location}',
       '"San Francisco, CA, USA"'
   )
   WHERE user_id = '你的用户ID';
   ```

3. **验证更新**
   ```sql
   SELECT 
       id,
       user_id,
       core_identity->>'location' as location
   FROM profiles 
   WHERE user_id = '你的用户ID';
   ```

## 工作原理

### 数据存储

位置信息存储在两个地方：

1. **`profiles` 表**（主要来源）
   - 字段：`core_identity->>'location'` (JSONB)
   - 这是 App 实际使用的位置数据

2. **`users` 表**（旧版，可能已弃用）
   - 字段：`location` (TEXT)
   - 某些旧代码可能还在使用

### 距离计算流程

1. **加载当前用户位置**
   ```swift
   loadCurrentUserLocation() → 从 profiles 表加载
   ↓
   core_identity.location → currentUserLocation
   ```

2. **计算距离**
   ```swift
   DistanceDisplayView(
       otherUserLocation: "MI",
       currentUserLocation: "San Francisco, CA"  // 如果为 nil，显示提示
   )
   ↓
   LocationService.calculateDistanceBetweenAddresses()
   ↓
   使用 CLGeocoder 进行地理编码
   ↓
   显示距离：例如 "3,200 km"
   ```

## 常见问题

### Q1: 为什么我设置了位置但还是显示 nil？

**可能原因**：
- Profile 没有正确保存
- 网络问题导致保存失败
- 数据库同步延迟

**解决方法**：
1. 退出并重新登录 App
2. 检查网络连接
3. 重新设置位置并确保看到 "Profile updated successfully" 提示

### Q2: 距离计算为什么显示 "Calculating..."？

**可能原因**：
- 地理编码请求正在处理中（通常 1-3 秒）
- 地址格式不正确，无法识别
- 网络问题或地理编码服务限流

**解决方法**：
- 等待几秒钟
- 确保地址格式正确（包含城市、州/省、国家）
- 使用标准的地址格式，例如：`City, State, Country`

### Q3: 我不想公开我的精确位置怎么办？

**建议**：
- 只填写城市级别的位置，不要填写详细地址
- 例如：`San Francisco, CA` 而不是 `123 Main St, San Francisco, CA 94102`
- App 只会显示城市到城市的距离，不会显示精确位置

## 验证步骤

设置完位置后，可以通过以下方式验证：

1. **在 Profile 页面查看**
   - 你的位置应该显示在 Profile 卡片上
   - 位置图标旁边应该显示你设置的城市

2. **在聊天界面查看**
   - 打开任意聊天对话
   - 点击对方的头像查看 Profile Card
   - 如果对方也设置了位置，应该能看到距离

3. **在 Match 卡片上查看**
   - 在 Explore 页面
   - Match 卡片上应该显示对方的距离

## 技术细节

### LocationService 防抖动机制

为了避免过多的地理编码请求（可能导致限流），`DistanceDisplayView` 实现了防抖动机制：

- **延迟时间**：300ms
- **请求去重**：相同地址对不会重复请求
- **缓存机制**：计算结果会被缓存

### 日志说明

正常的位置加载日志：
```
📍 [ChatProfileCard] 开始加载当前用户位置...
   - 当前用户 ID: xxx
✅ [ChatProfileCard] 已加载当前用户位置: San Francisco, CA
👁️ [DistanceDisplay] onAppear 触发
   - otherUserLocation: MI
   - currentUserLocation: San Francisco, CA
📍 [DistanceDisplay] 防抖动延迟后执行地理编码...
✅ [DistanceDisplay] ✅✅✅ 距离计算成功: 3,200 km ✅✅✅
```

如果位置为空的日志：
```
📍 [ChatProfileCard] 开始加载当前用户位置...
   - 当前用户 ID: xxx
⚠️ [ChatProfileCard] 当前用户没有设置位置信息
👁️ [DistanceDisplay] onAppear 触发
   - currentUserLocation: nil
⚠️ [DistanceDisplay] 当前用户地址为空，等待加载...
```

## 相关文件

- `ProfileSetupView.swift` - Profile 编辑界面，包含 Location 输入框
- `ChatInterfaceView.swift` - 聊天界面，包含 ProfileCardSheetView
- `UserProfileCardView.swift` - 距离显示组件 DistanceDisplayView
- `LocationService.swift` - 位置服务和距离计算
- `check_user_location.sql` - 数据库查询脚本

## 总结

**最简单的解决方案**：
1. 打开 App
2. 进入 Profile → Edit Profile
3. 在 Location 字段输入你的城市
4. 保存

设置完成后，你就可以看到与其他用户的距离了！🎉

