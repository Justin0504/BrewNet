# Gemini API Key 更新指南

## 问题说明
当前 API Key 已被标记为泄露，需要生成新的 API Key。

## 生成新 API Key 的步骤

### 1. 访问 Google AI Studio
打开浏览器，访问：**https://aistudio.google.com/app/apikey**

### 2. 登录 Google 账号
使用您的 Google 账号登录

### 3. 创建新的 API Key
- 点击 **"Create API Key"** 或 **"Get API Key"** 按钮
- 如果需要，选择或创建一个 Google Cloud 项目
- 复制生成的 API Key（格式类似：`AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`）

### 4. 更新 Info.plist
将新的 API Key 更新到 `BrewNet/BrewNet/Info.plist` 文件中：

```xml
<key>GEMINI_API_KEY</key>
<string>YOUR_NEW_API_KEY_HERE</string>
```

### 5. 验证
- 清理 Xcode 构建缓存（Product → Clean Build Folder）
- 重新运行应用
- 检查控制台是否显示 "✅ Gemini API Key 已配置"

## 注意事项
- **不要**将 API Key 提交到 Git 仓库（如果已提交，请立即撤销并生成新 Key）
- **不要**在公开场合分享 API Key
- 如果 Key 再次被标记为泄露，请立即生成新的并更新

## 当前状态
- 当前 Key: `AIzaSyBSWp3cE-f-aAYuNn8ofQk9TCoTa8cQg6Y` (已泄露，需要更换)
- 状态: ❌ 已泄露，无法使用

