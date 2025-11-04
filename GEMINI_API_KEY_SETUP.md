# Gemini API Key 设置指南

## 问题：API Key 被报告为泄露

如果看到错误信息：
```
Your API key was reported as leaked. Please use another API key.
```

说明你的 API Key 可能已经被泄露（例如被提交到 GitHub 公开仓库），需要生成新的 API Key。

## 解决方案

### 方法 1：使用环境变量（推荐）

1. **在 Xcode 中设置环境变量**：
   - 打开 Xcode Scheme Editor：`Product > Scheme > Edit Scheme...`
   - 选择 `Run` > `Arguments`
   - 在 `Environment Variables` 中添加：
     - Name: `GEMINI_API_KEY`
     - Value: `你的新 API Key`

2. **或者通过命令行设置**：
   ```bash
   export GEMINI_API_KEY="你的新 API Key"
   ```

### 方法 2：使用 Info.plist（不推荐，容易被提交）

⚠️ **警告**：如果使用此方法，请确保：
- `Info.plist` 已添加到 `.gitignore`
- 或者使用 `Info-local.plist` 并添加到 `.gitignore`

在 `Info.plist` 中添加：
```xml
<key>GEMINI_API_KEY</key>
<string>你的新 API Key</string>
```

## 获取新的 Gemini API Key

1. 访问 [Google AI Studio](https://aistudio.google.com/app/apikey)
2. 登录你的 Google 账号
3. 点击 "Create API Key"
4. 选择或创建一个 Google Cloud 项目
5. 复制生成的 API Key

## 安全建议

1. **永远不要将 API Key 提交到 Git**：
   - ✅ 使用环境变量
   - ✅ 使用 `.gitignore` 忽略包含 API Key 的文件
   - ❌ 不要硬编码在源代码中
   - ❌ 不要提交到 GitHub 公开仓库

2. **定期轮换 API Key**：
   - 如果怀疑泄露，立即删除旧 Key 并生成新的

3. **限制 API Key 权限**：
   - 在 Google Cloud Console 中限制 API Key 的使用范围
   - 设置 IP 白名单（如果可能）

4. **监控 API 使用**：
   - 定期检查 API 使用情况
   - 如果发现异常使用，立即更换 Key

## 验证设置

运行应用后，查看控制台输出：
- ✅ `Gemini API Key 已配置，将使用真实 AI 响应` - 配置成功
- ⚠️ `Gemini API Key 未配置，将使用模拟响应` - 未配置，将使用模拟模式

## 当前状态

代码已配置为：
1. 优先从环境变量 `GEMINI_API_KEY` 读取
2. 其次从 `Info.plist` 的 `GEMINI_API_KEY` 键读取
3. 如果都没有，使用模拟模式（不会调用真实 API）

## 故障排除

如果仍然看到 403 错误：
1. 确认新 API Key 已正确设置
2. 检查 API Key 是否有效（在 Google AI Studio 中测试）
3. 确认 API Key 没有被限制或禁用
4. 检查网络连接和防火墙设置

