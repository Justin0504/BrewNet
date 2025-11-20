# BrewNet - 专业人士的咖啡社交平台

<div align="center">

![BrewNet Logo](BrewNet/BrewNet/Assets.xcassets/Logo.imageset/Logo.png)

**用 AI 找到你的职场伙伴，一杯咖啡开启新机遇**

[![Platform](https://img.shields.io/badge/platform-iOS%2017.0+-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

</div>

---

## 📖 项目简介

BrewNet 是一款基于 AI 智能推荐的专业社交应用，帮助职场人士通过"咖啡聊天"的方式建立真实、有价值的职业人脉。

### 🎯 核心特性

- **🤖 AI 智能匹配**: 双塔神经网络算法精准推荐
- **☕ 咖啡约会系统**: 一键发送见面邀请
- **🎨 精美 UI 设计**: SwiftUI 打造流畅体验
- **🔒 隐私优先**: 用户完全控制信息可见性
- **⚡ 实时聊天**: 即时消息和在线状态
- **🌟 Pro 会员**: 无限点赞、超级推荐等高级功能

---

## 🗂️ 文档导航

### 📚 核心文档

| 文档 | 说明 | 适合人群 |
|------|------|----------|
| **[技术文档](TECHNICAL_DOCUMENTATION.md)** | 完整的技术架构、API、数据库设计 | 开发者、技术负责人 |
| **[App Store 上线清单](APP_STORE_LAUNCH_CHECKLIST.md)** | 16 步上线指南，从准备到发布 | 项目经理、开发者 |
| **[营销素材指南](APP_STORE_MARKETING.md)** | 截图、文案、视频脚本 | 产品经理、市场团队 |
| **[隐私政策草稿](PRIVACY_POLICY_DRAFT.md)** | 完整的隐私政策模板 | 法务、产品经理 |

### 🔧 技术文档快速链接

#### 架构和设计
- [系统架构图](TECHNICAL_DOCUMENTATION.md#3-系统架构)
- [MVVM 架构模式](TECHNICAL_DOCUMENTATION.md#32-应用架构模式)
- [数据流设计](TECHNICAL_DOCUMENTATION.md#34-数据流)

#### 核心功能
- [用户认证模块](TECHNICAL_DOCUMENTATION.md#41-用户认证模块)
- [推荐匹配算法](TECHNICAL_DOCUMENTATION.md#5-推荐系统详解)
- [聊天系统](TECHNICAL_DOCUMENTATION.md#44-聊天模块)
- [咖啡邀请功能](TECHNICAL_DOCUMENTATION.md#45-咖啡聊天模块)

#### 数据库
- [数据库设计](TECHNICAL_DOCUMENTATION.md#6-数据库设计)
- [RLS 安全策略](TECHNICAL_DOCUMENTATION.md#64-rls-row-level-security-策略)
- [触发器和同步](TECHNICAL_DOCUMENTATION.md#63-数据同步触发器)

#### API 接口
- [认证接口](TECHNICAL_DOCUMENTATION.md#71-认证接口)
- [推荐接口](TECHNICAL_DOCUMENTATION.md#73-推荐接口)
- [聊天接口](TECHNICAL_DOCUMENTATION.md#75-聊天接口)

---

## 🚀 快速开始

### 环境要求

```
macOS 14.0+
Xcode 15.0+
iOS 17.0+
Swift 5.9+
```

### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/Justin0504/BrewNet.git
cd BrewNet-Fresh
```

2. **打开项目**
```bash
open BrewNet/BrewNet.xcodeproj
```

3. **配置 Supabase**
```swift
// SupabaseService.swift 中配置
let supabaseURL = "YOUR_SUPABASE_URL"
let supabaseKey = "YOUR_SUPABASE_ANON_KEY"
```

4. **运行项目**
- 选择模拟器或真机
- 按 `Cmd + R` 运行

---

## 🏗️ 技术栈

### 前端
- **SwiftUI** - 声明式 UI 框架
- **Combine** - 响应式编程
- **AsyncImage** - 异步图片加载
- **PhotosPicker** - 照片选择

### 后端
- **Supabase** - BaaS 平台
  - PostgreSQL 数据库
  - 实时订阅
  - 对象存储
  - 认证服务

### AI/ML
- **Two-Tower Encoder** - 双塔推荐算法
- **Multi-hot Encoding** - 特征编码
- **Cosine Similarity** - 相似度计算

### 支付
- **StoreKit 2** - 应用内购买和订阅

---

## 📊 项目结构

```
BrewNet/
├── BrewNet/                    # 主应用代码
│   ├── BrewNetApp.swift       # App 入口
│   ├── Models/                 # 数据模型
│   │   ├── ProfileModels.swift
│   │   ├── EducationModels.swift
│   │   └── UserTowerFeatures.swift
│   ├── Views/                  # UI 视图
│   │   ├── BrewNetMatchesView.swift
│   │   ├── ChatInterfaceView.swift
│   │   ├── ProfileSetupView.swift
│   │   └── UserProfileCardView.swift
│   ├── Services/               # 服务层
│   │   ├── AuthManager.swift
│   │   ├── SupabaseService.swift
│   │   ├── RecommendationService.swift
│   │   └── SimpleTwoTowerEncoder.swift
│   └── Assets.xcassets/        # 资源文件
├── BrewNetTests/               # 单元测试
├── BrewNetUITests/             # UI 测试
└── Documentation/              # 文档
    ├── TECHNICAL_DOCUMENTATION.md
    ├── APP_STORE_LAUNCH_CHECKLIST.md
    └── APP_STORE_MARKETING.md
```

---

## 🎨 核心功能演示

### 1. 智能推荐
```
用户资料 → AI 特征提取 → 相似度计算 → 个性化推荐
```

### 2. 卡片滑动
- 右滑/点赞 ❤️ - 感兴趣
- 左滑/跳过 ✖️ - 不感兴趣
- 双方点赞 → 匹配成功 🎉

### 3. 咖啡约会
```
发送邀请 → 填写时间地点 → 对方接受 → 添加到日程
```

### 4. 实时聊天
- 即时消息送达
- 已读状态显示
- 在线状态指示

---

## 📈 数据统计

```
代码行数: 30,000+ lines
Swift 文件: 50+ files
数据库表: 8 tables
API 接口: 20+ endpoints
支持语言: 中文、英文
```

---

## 🔐 隐私和安全

### 数据保护
- ✅ HTTPS/TLS 加密传输
- ✅ 数据库加密存储
- ✅ Row Level Security (RLS)
- ✅ 用户可删除所有数据

### 隐私控制
- ✅ 自定义资料可见性
- ✅ 位置信息模糊化
- ✅ 举报和拉黑功能
- ✅ 符合 GDPR/CCPA 标准

详见: [隐私政策草稿](PRIVACY_POLICY_DRAFT.md)

---

## 🌟 Pro 会员功能

| 功能 | 免费用户 | Pro 会员 |
|------|---------|----------|
| 每日点赞次数 | 10 次 | ♾️ 无限 |
| 查看谁赞了你 | ❌ | ✅ |
| 超级推荐位 | ❌ | ✅ |
| 高级筛选 | 基础筛选 | ✅ 全部 |
| 客服支持 | 标准 | ✅ 优先 |
| Pro 徽章 | ❌ | ✅ |

**订阅价格:**
- 月订阅: $9.99/月
- 年订阅: $79.99/年 (省 33%)

---

## 🧪 测试

### 运行单元测试
```bash
xcodebuild test \
  -scheme BrewNet \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### 运行 UI 测试
```bash
xcodebuild test \
  -scheme BrewNetUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## 📦 部署

### TestFlight 内测
1. 在 Xcode 中 Archive
2. 上传到 App Store Connect
3. 创建测试组并邀请用户
4. 收集反馈

### App Store 发布
详见: [App Store 上线清单](APP_STORE_LAUNCH_CHECKLIST.md)

---

## 🛠️ 开发指南

### 代码规范
- 使用 SwiftLint 检查代码风格
- 遵循 Apple Swift Style Guide
- 命名清晰，注释完整

### Git 工作流
```bash
# 创建功能分支
git checkout -b feature/your-feature

# 提交更改
git commit -m "feat: add new feature"

# 推送到远程
git push origin feature/your-feature

# 创建 Pull Request
```

### 提交消息规范
```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式调整
refactor: 重构代码
test: 测试相关
chore: 构建/工具变更
```

---

## 🐛 常见问题

### Q1: 推荐结果为空？
**A**: 检查 `user_features` 表是否同步，确保资料完整度 > 50%

### Q2: 照片上传失败？
**A**: 确认 Supabase Storage bucket 已创建，检查 RLS 策略

### Q3: 无法购买订阅？
**A**: 使用 Sandbox 测试账号，确保产品已在 App Store Connect 配置

更多问题: [技术文档 - 常见问题](TECHNICAL_DOCUMENTATION.md#13-常见问题)

---

## 🗺️ Roadmap

### ✅ 已完成
- [x] 用户认证系统
- [x] 个人资料管理
- [x] AI 推荐算法
- [x] 聊天系统
- [x] 咖啡邀请功能
- [x] Pro 订阅
- [x] 高级筛选
- [x] 行为指标系统

### 🚧 进行中
- [ ] 推送通知
- [ ] App Store 上线准备
- [ ] 性能优化

### 📋 计划中
- [ ] 语音消息
- [ ] 视频通话预约
- [ ] 社区功能
- [ ] Android 版本
- [ ] Web 版本

详见: [技术文档 - 未来规划](TECHNICAL_DOCUMENTATION.md#14-未来规划)

---

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 📧 联系方式

- **项目主页**: https://github.com/Justin0504/BrewNet
- **问题反馈**: https://github.com/Justin0504/BrewNet/issues
- **邮箱**: [您的邮箱]

---

## 🙏 致谢

- **Supabase** - 优秀的 BaaS 平台
- **Apple** - SwiftUI 和 StoreKit 2
- **开源社区** - 各种优秀的库和工具

---

## 📱 下载体验

<div align="center">

### 即将登陆 App Store

**敬请期待 BrewNet 1.0 正式版！**

[🔔 订阅更新通知](https://your-website.com/subscribe)

---

**让每一杯咖啡都成为职业发展的转折点** ☕✨

</div>

---

*最后更新: 2025-11-20*

