# ✅ Gemini API Key 配置修复

## 🐛 问题

应用启动后显示：
```
ℹ️ 使用模拟 AI 响应（未配置 API Key）
```

虽然已在 Xcode Scheme 中配置了环境变量。

## 🔍 原因

**环境变量键名格式错误**

在 `BrewNet.xcscheme` 文件中：
```xml
<!-- ❌ 错误：使用了反引号 -->
<EnvironmentVariable
    key = "`GEMINI_API_KEY`"
    value = "AIzaSyBLKpuoF-OV-e_wfdQyRqIwGDjZT8cdWe4"
    isEnabled = "YES">
</EnvironmentVariable>
```

**正确格式**：
```xml
<!-- ✅ 正确：不使用反引号 -->
<EnvironmentVariable
    key = "GEMINI_API_KEY"
    value = "AIzaSyBLKpuoF-OV-e_wfdQyRqIwGDjZT8cdWe4"
    isEnabled = "YES">
</EnvironmentVariable>
```

## ✅ 修复

已修复 `BrewNet/BrewNet.xcodeproj/xcshareddata/xcschemes/BrewNet.xcscheme`

## 🧪 验证

重新运行应用，应该看到：
```
✅ Gemini API Key 已配置，将使用真实 AI 响应
```

而不是：
```
ℹ️ 使用模拟 AI 响应（未配置 API Key）
```

## 📝 重要提示

⚠️ **注意**: `xcshareddata/xcschemes/BrewNet.xcscheme` 是**共享的 scheme**，已提交到 Git。

这意味着：
- ✅ 所有团队成员可以共享相同的配置
- ⚠️ API Key 被暴露在版本控制中

### 安全建议

#### 方案 1: 使用私有 Scheme（推荐）

1. 删除共享 scheme：
```bash
rm BrewNet/BrewNet.xcodeproj/xcshareddata/xcschemes/BrewNet.xcscheme
```

2. 在 Xcode 中重新创建 scheme：
   - Product → Scheme → Manage Schemes
   - 创建新的私有 scheme

3. 配置环境变量：
   - Edit Scheme → Run → Arguments → Environment Variables
   - 添加 `GEMINI_API_KEY`

#### 方案 2: 使用 Info.plist

1. 添加到 `BrewNet/Info.plist`：
```xml
<key>GEMINI_API_KEY</key>
<string>AIzaSyBLKpuoF-OV-e_wfdQyRqIwGDjZT8cdWe4</string>
```

2. 从 `.gitignore` 排除：
```
BrewNet/Info.plist
```

#### 方案 3: 生产环境使用服务器代理（最佳）

**推荐用于生产环境**：

1. 创建后台 API 代理
2. API Key 存储在服务器
3. 应用请求服务器
4. 服务器转发到 Gemini API

**优点**：
- ✅ 最安全
- ✅ 可以限流和缓存
- ✅ 不暴露 API Key
- ✅ 易于管理和更新

## 🎯 当前状态

✅ 环境变量配置已修复  
⚠️ API Key 已暴露在 Git 中  
📋 建议尽快更新到安全的方案  

## 🔄 下一步

1. **立即**: 测试 Gemini AI 是否工作
2. **短期**: 从 Git 中移除共享 scheme
3. **长期**: 实施服务器代理方案

---

**修复完成！重启 Xcode 测试！**

