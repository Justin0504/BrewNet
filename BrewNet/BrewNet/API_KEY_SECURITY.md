# API Key 安全指南

## ⚠️ 重要：为什么 API Key 总是被标记为 "Leaked"

**根本原因：API Key 被提交到了 Git 仓库**

一旦 API Key 出现在 Git 历史中，Google 会通过各种方式检测到它（包括但不限于）：
- GitHub/GitLab 等平台的自动安全扫描
- 公开的代码仓库
- 代码分享平台
- 各种安全扫描工具

**即使仓库是私有的，一旦 Key 出现在 Git 历史中，就有泄露的风险。**

## 🔧 解决方案

### 1. 立即行动（必须完成）

#### A. 生成新的 API Key
1. 访问：https://aistudio.google.com/app/apikey
2. 删除旧的泄露的 API Key
3. 创建新的 API Key
4. **不要立即使用新 Key，先完成下面的步骤**

#### B. 从 Git 中移除 Info.plist
```bash
# 1. 从 Git 跟踪中移除（但保留本地文件）
git rm --cached BrewNet/BrewNet/Info.plist

# 2. 提交更改
git commit -m "Remove Info.plist from Git tracking (contains API key)"

# 3. 推送到远程仓库
git push
```

#### C. 确保 .gitignore 已配置
`.gitignore` 已经配置为忽略 `Info.plist`，但需要确保：
- 团队成员都拉取最新代码
- 不要强制推送包含 API Key 的提交

### 2. 团队成员配置

每个团队成员需要：

1. **复制示例文件**
   ```bash
   cp BrewNet/BrewNet/Info.plist.example BrewNet/BrewNet/Info.plist
   ```

2. **添加自己的 API Key**
   - 编辑 `BrewNet/BrewNet/Info.plist`
   - 将 `YOUR_GEMINI_API_KEY_HERE` 替换为你的 API Key

3. **验证 .gitignore**
   - 确保 `Info.plist` 不会被 Git 跟踪
   - 运行 `git status` 确认 `Info.plist` 不在未跟踪文件列表中

### 3. 长期解决方案（可选但推荐）

#### 方案 A：使用环境变量（推荐）
在 Xcode Scheme 中配置环境变量：
1. Product → Scheme → Edit Scheme
2. Run → Arguments → Environment Variables
3. 添加：`GEMINI_API_KEY` = `你的API Key`

然后修改代码从环境变量读取（但这需要修改 `GeminiAIService.swift`）

#### 方案 B：使用 Xcode 配置（Build Settings）
创建 `Info-local.plist`（已在 .gitignore 中），在构建时合并

#### 方案 C：使用密钥管理服务
- AWS Secrets Manager
- Google Secret Manager
- 或其他密钥管理服务

## 📋 检查清单

- [ ] 生成新的 API Key
- [ ] 从 Git 中移除 Info.plist
- [ ] 确认 .gitignore 已配置
- [ ] 更新本地 Info.plist（不要提交）
- [ ] 通知团队成员更新本地配置
- [ ] 考虑从 Git 历史中完全移除旧的 API Key（使用 git filter-branch）

## 🚨 紧急情况处理

如果 API Key 已经在公开仓库中：
1. **立即删除**泄露的 API Key（在 Google AI Studio 中）
2. **生成新的** API Key
3. **使用 git filter-branch 或 BFG Repo-Cleaner** 从历史中移除 API Key
4. **强制推送**（需要团队成员重新克隆仓库）

## 📝 当前状态

- ✅ `.gitignore` 已配置忽略 `Info.plist`
- ✅ `Info.plist.example` 已创建作为模板
- ⚠️ **需要从 Git 中移除现有的 Info.plist**
- ⚠️ **需要生成新的 API Key**

## 🔗 相关文件

- `BrewNet/BrewNet/Info.plist` - 包含真实 API Key（不应提交到 Git）
- `BrewNet/BrewNet/Info.plist.example` - 模板文件（可以提交）
- `.gitignore` - Git 忽略配置

