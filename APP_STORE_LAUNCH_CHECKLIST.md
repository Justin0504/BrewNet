# BrewNet App Store 上线清单

## 📅 准备时间线
建议预留 **2-4 周**时间完成所有准备工作和审核。

---

## 1️⃣ Apple 开发者账号准备

### ✅ 必需项
- [ ] 已注册 Apple Developer Program ($99/年)
- [ ] 账号状态为 Active
- [ ] 完成双重认证设置
- [ ] 银行和税务信息已填写（如果有付费功能）

**操作地址**: https://developer.apple.com/account

---

## 2️⃣ App 基本信息

### App 元数据
- [ ] **App 名称**: BrewNet (需在 App Store Connect 验证可用性)
- [ ] **副标题** (30 字符以内): 例如 "Professional Coffee Networking"
- [ ] **Bundle ID**: 需在 Xcode 中设置唯一标识符
  - 格式建议: `com.brewnet.app` 或 `com.yourcompany.brewnet`
  - ⚠️ **重要**: Bundle ID 一旦创建不可更改

### App 分类
- [ ] **主要分类**: Social Networking（社交网络）
- [ ] **次要分类**: Business（商务）或 Networking（人脉）

### 定价
- [ ] **基础 App**: 免费
- [ ] **内购项目** (BrewNet Pro):
  - 需创建 In-App Purchase 产品
  - 设置价格层级
  - 准备本地化描述

---

## 3️⃣ App 描述和关键词

### 中文描述 (建议)
```
BrewNet - 专业人士的咖啡社交平台

🎯 为什么选择 BrewNet？
• 基于 AI 的智能匹配算法，帮你找到志同道合的专业人士
• 咖啡聊天约会系统，让职场社交更轻松自然
• 按行业、经验、技能精准筛选
• 保护隐私，安全可靠

☕ 主要功能
• 智能推荐：双塔模型算法精准匹配
• 咖啡约会：一键发送咖啡聊天邀请
• 深度资料：查看详细的职业背景和技能
• 实时聊天：即时消息沟通
• Pro 会员：无限点赞、超级推荐等特权

🌟 适合谁使用？
• 寻找职业导师的新人
• 希望扩展人脉的专业人士
• 寻找合作伙伴的创业者
• 想要分享经验的行业专家

立即下载 BrewNet，开启你的专业社交之旅！
```

### 英文描述 (建议)
```
BrewNet - Professional Coffee Networking

🎯 Why BrewNet?
• AI-powered smart matching algorithm
• Coffee chat scheduling system
• Filter by industry, experience, and skills
• Privacy-focused and secure

☕ Key Features
• Smart Recommendations: Two-tower ML algorithm
• Coffee Meetings: One-tap invitations
• Detailed Profiles: Professional backgrounds
• Real-time Chat: Instant messaging
• Pro Membership: Unlimited likes & super boosts

🌟 Perfect for:
• Professionals seeking mentors
• Entrepreneurs finding partners
• Industry experts sharing knowledge
• Anyone expanding their network

Download BrewNet and start your professional networking journey!
```

### 关键词 (100 字符以内)
- [ ] 中文: `专业社交,职场人脉,咖啡社交,职业发展,导师,行业交流,商务社交`
- [ ] 英文: `networking,professional,coffee,mentor,business,career,social`

### 宣传文本 (170 字符，可随时更新)
- [ ] 例如: "用 AI 找到你的职场伙伴，一杯咖啡开启新机遇！✨"

---

## 4️⃣ App 截图和预览

### 📱 截图要求
需要为以下设备尺寸准备截图：
- [ ] **6.9" Display (iPhone 16 Pro Max)** - 必需
  - 分辨率: 1320 x 2868 像素 (或 2640 x 5736)
- [ ] **6.7" Display (iPhone 14 Plus)** - 可选但推荐
  - 分辨率: 1290 x 2796 像素
- [ ] **5.5" Display (iPhone 8 Plus)** - 可选
  - 分辨率: 1242 x 2208 像素

### 建议截图内容 (3-10 张)
1. **主界面/匹配页面** - 展示卡片滑动和推荐
2. **用户资料详情** - 展示完整的个人资料
3. **聊天界面** - 展示消息和咖啡邀请
4. **咖啡约会日程** - 展示已安排的见面
5. **个人资料设置** - 展示资料完整度
6. **Pro 会员功能** - 展示高级功能

### 📹 App 预览视频 (可选但强烈推荐)
- [ ] 时长: 15-30 秒
- [ ] 展示核心功能流程
- [ ] 添加背景音乐和文字说明

### 工具推荐
- **截图**: 直接在模拟器或真机截图
- **美化**: Figma, Sketch, 或 App Store Screenshot 模板
- **视频**: 使用 QuickTime 录屏 + iMovie/Final Cut Pro 编辑

---

## 5️⃣ App 图标

### ✅ 当前状态
已有 Logo.png 在 Assets.xcassets 中

### 📋 检查清单
- [ ] 图标尺寸完整 (1024x1024 for App Store)
- [ ] 无透明通道
- [ ] 无圆角 (Apple 会自动添加)
- [ ] 视觉清晰，易识别
- [ ] 在不同背景下可见

### 建议优化
如果当前图标需要优化，可以：
- 简化设计，确保在小尺寸下清晰
- 使用 BrewNet 品牌色
- 加入咖啡或社交元素

---

## 6️⃣ 隐私政策和用户协议

### ⚠️ **必需项** - Apple 要求
- [ ] **隐私政策 URL** - 必须提供
  - 需托管在可公开访问的网站
  - 说明收集哪些数据、如何使用、如何保护
  - 建议使用: iubenda.com 或自建网站

- [ ] **用户协议/服务条款 URL** - 推荐提供
  - 说明用户权利和责任
  - 免责声明

### 需要说明的数据收集
根据 BrewNet 功能，需在隐私政策中说明：
- ✅ 用户账号信息（邮箱、姓名）
- ✅ 个人资料（照片、职业背景、技能）
- ✅ 位置信息（用于推荐附近用户）
- ✅ 聊天消息
- ✅ 使用数据（匹配、点赞记录）
- ✅ 支付信息（Pro 订阅，由 Apple 处理）

### 🛡️ 隐私清单 (Privacy Manifest)
iOS 17+ 要求提供 PrivacyInfo.xcprivacy 文件：
- [ ] 创建 Privacy Manifest
- [ ] 声明 Required Reason API 使用
- [ ] 声明收集的数据类型

**我可以帮你生成这个文件！**

---

## 7️⃣ 代码签名和证书

### Development
- [ ] Development Certificate 已创建
- [ ] Development Provisioning Profile 已配置

### Distribution (App Store)
- [ ] **Distribution Certificate** 已创建
- [ ] **App Store Provisioning Profile** 已配置
- [ ] 在 Xcode 中正确配置 Team 和 Signing

### 操作步骤
1. 打开 Xcode → BrewNet Project → Signing & Capabilities
2. 选择 Team (需要 Apple Developer 账号)
3. 勾选 "Automatically manage signing"
4. 确保 Bundle Identifier 正确

---

## 8️⃣ App Capabilities 和权限

### 当前已使用的权限
- [x] Location (定位) - `NSLocationWhenInUseUsageDescription`
- [ ] Push Notifications (推送通知) - **建议添加**
- [ ] In-App Purchase (内购) - **Pro 订阅必需**
- [ ] iCloud (可选，用于数据同步)

### 需要在 Xcode 中启用
1. Signing & Capabilities 标签
2. 点击 "+ Capability"
3. 添加需要的能力

### 权限描述文本优化
当前 Info.plist 中的定位权限描述可以更友好：
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>BrewNet uses your location to recommend nearby professionals and suggest convenient coffee chat locations.</string>
```

---

## 9️⃣ 内购 (In-App Purchase) 配置

### BrewNet Pro 订阅设置
- [ ] 在 App Store Connect 创建订阅组
- [ ] 创建订阅产品:
  - **月订阅**: 例如 $9.99/月
  - **年订阅**: 例如 $79.99/年 (打 33% 折扣)
- [ ] 设置本地化价格
- [ ] 准备订阅描述和权益说明
- [ ] 上传订阅推广图片

### 代码中需要配置的产品 ID
在代码中搜索并确认产品 ID：
```swift
// 需要与 App Store Connect 中创建的 ID 一致
static let monthlyProID = "com.brewnet.pro.monthly"
static let yearlyProID = "com.brewnet.pro.yearly"
```

---

## 🔟 测试准备

### TestFlight 内测
- [ ] 创建 Internal Testing 组（免审核，最多 100 人）
- [ ] 创建 External Testing 组（需审核，最多 10,000 人）
- [ ] 准备 Beta 测试说明
- [ ] 邀请测试用户
- [ ] 收集反馈并修复 bug

### 审核前自测清单
- [ ] 所有核心功能正常运行
- [ ] 没有崩溃或严重 bug
- [ ] 网络请求都能正确处理错误
- [ ] 支付流程完整（包括恢复购买）
- [ ] 隐私设置可用
- [ ] 用户可以删除账户
- [ ] 所有文本无错别字
- [ ] 深色模式下显示正常
- [ ] 不同屏幕尺寸适配良好

---

## 1️⃣1️⃣ 构建和上传

### 版本号设置
- [ ] **Version**: 1.0.0 (对外显示的版本)
- [ ] **Build**: 1 (内部构建号，每次上传递增)

### 构建步骤
```bash
# 1. 在 Xcode 中
Product → Archive

# 2. 等待归档完成
# 3. 在 Organizer 中点击 "Distribute App"
# 4. 选择 "App Store Connect"
# 5. 上传
```

### ⚠️ 常见问题
- 确保使用 Release 配置
- 确保选择了正确的 Team
- 确保证书和描述文件有效
- 如果上传失败，检查 Application Loader 日志

---

## 1️⃣2️⃣ App Store Connect 配置

### App 信息页面 (https://appstoreconnect.apple.com)
- [ ] 登录 App Store Connect
- [ ] 创建新 App (My Apps → + → New App)
- [ ] 填写基本信息:
  - 平台: iOS
  - 名称: BrewNet
  - 主要语言: 简体中文或英语
  - Bundle ID: 选择你创建的 Bundle ID
  - SKU: 内部标识符，例如 BREWNET001

### 版本信息
- [ ] 上传截图（所有尺寸）
- [ ] 上传 App 预览视频（如有）
- [ ] 填写描述、关键词、宣传文本
- [ ] 设置分类和内容分级
- [ ] 填写版权信息
- [ ] 填写支持 URL 和营销 URL

### 定价和可用性
- [ ] 设置价格: 免费
- [ ] 选择可用国家/地区
- [ ] 设置发布日期（手动或自动）

### App 审核信息
- [ ] 提供测试账号（包含不同角色的账号）
- [ ] 提供审核备注（如有特殊说明）
- [ ] 提供联系方式（电话、邮箱）

---

## 1️⃣3️⃣ 内容分级

### Age Rating（年龄分级）
需要填写问卷，根据 BrewNet 特性：
- [ ] 卡通或幻想暴力: 无
- [ ] 真实暴力: 无
- [ ] 成人/性暗示内容: 无
- [ ] 社交网络: **是** ✅
- [ ] 用户生成内容: **是** ✅ (用户资料、聊天)
- [ ] 位置服务: **是** ✅

**预估评级**: 17+ (因为有社交和用户生成内容)

---

## 1️⃣4️⃣ Apple 审核指南合规性检查

### 🚨 重点审核项
- [ ] **2.1 性能** - App 完整且无 bug
- [ ] **2.3.1 准确元数据** - 截图、描述与实际功能一致
- [ ] **3.1.1 内购** - 必须使用 Apple IAP（不能引导用户外部支付）
- [ ] **4.0 设计** - 遵循 Human Interface Guidelines
- [ ] **5.1.1 隐私** - 必须有隐私政策
- [ ] **5.1.2 数据使用** - 明确说明数据收集和使用

### BrewNet 特定注意事项
1. **社交功能审核**:
   - [ ] 必须有举报/拉黑功能
   - [ ] 必须有内容审核机制
   - [ ] 用户可以控制谁能看到他们的信息

2. **约会/社交应用要求**:
   - [ ] 用户必须能删除账户
   - [ ] 年龄限制设置正确
   - [ ] 防止骚扰和不当内容

3. **支付审核**:
   - [ ] Pro 订阅使用 StoreKit 2
   - [ ] 提供恢复购买功能
   - [ ] 清楚展示订阅条款

---

## 1️⃣5️⃣ 提交审核

### 最终检查
- [ ] 所有必填信息已填写
- [ ] 构建版本已上传并处理完成
- [ ] 测试账号可用
- [ ] 隐私政策 URL 可访问
- [ ] 所有截图和描述准确

### 提交流程
1. 在 App Store Connect 选择刚上传的构建版本
2. 点击 "Submit for Review"
3. 回答附加问题（加密、广告等）
4. 确认提交

### ⏱️ 审核时间
- 通常 1-3 天
- 首次提交可能需要更长时间
- 可在 App Store Connect 查看状态

---

## 1️⃣6️⃣ 发布后工作

### 上线当天
- [ ] 确认 App 在 App Store 可见
- [ ] 测试下载和首次使用流程
- [ ] 准备用户支持渠道
- [ ] 监控崩溃和性能数据

### 持续运营
- [ ] 定期更新 App（修复 bug、新功能）
- [ ] 回复用户评论
- [ ] 分析 App Store Connect Analytics
- [ ] 收集用户反馈并迭代

---

## 📚 有用的资源

- **Apple 开发者文档**: https://developer.apple.com/documentation/
- **App Store 审核指南**: https://developer.apple.com/app-store/review/guidelines/
- **App Store Connect 帮助**: https://help.apple.com/app-store-connect/
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/
- **TestFlight 测试指南**: https://developer.apple.com/testflight/

---

## 🎯 快速行动计划

### 本周 (Week 1)
- [ ] 确认 Apple Developer 账号状态
- [ ] 设置 Bundle ID 和证书
- [ ] 准备隐私政策和用户协议
- [ ] 开始准备截图和描述文本

### 下周 (Week 2)
- [ ] 完成所有元数据准备
- [ ] 配置 In-App Purchase
- [ ] 第一次 TestFlight 构建
- [ ] 内部测试

### 第三周 (Week 3)
- [ ] External TestFlight 测试
- [ ] 修复发现的 bug
- [ ] 完善截图和描述

### 第四周 (Week 4)
- [ ] 最终测试
- [ ] 提交审核
- [ ] 准备发布和推广材料

---

**需要我帮助你完成其中的某一项吗？例如：**
1. 生成 Privacy Manifest 文件
2. 优化 Info.plist 配置
3. 创建截图模板
4. 编写隐私政策草稿
5. 检查代码中的审核风险点

