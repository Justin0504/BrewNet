# BrewNet — App Store 提交清单 & 文案

版本 1.0 (Build 8)。以下内容可直接复制进 App Store Connect。

---

## 1. App 信息

- **名称**: BrewNet
- **副标题 (30 字符内)**: Your AI networking agent
- **类别**: 主 = Business；副 = Social Networking
- **年龄分级**: 4+（无不适内容;问卷全选 None）
- **Bundle ID**: com.justinyuan.BrewNet
- **App ID**: 6796967801

## 2. 描述 (Description)

```
BrewNet is your AI networking agent. Tell it who you want to meet — a founder who's raised a seed round, an alum at Stripe, a mentor in your field — and it does the rest: finds the right people, breaks the ice, and sets up the coffee. You just show up.

WHY BREWNET
• Just say who you need. Describe the person in plain words. Brew understands intent, not keywords, and starts scouting instantly.
• Double-blind introductions. Brew and the other person's agent quietly agree on a time and place. One tap and it's booked. If they pass, you never know — no awkward rejections.
• It reaches beyond the app. Have someone specific in mind who isn't on BrewNet? Brew drafts a warm intro and reaches them directly — they accept with one tap, no download required.
• Show up prepared. Before every coffee, Brew briefs you on who they are and what to talk about.
• Keep relationships warm. Brew reminds you to follow up and drafts the note, turning one-off coffees into a real network.

Networking, without the work.

BrewNet Pro unlocks unlimited scouting, more weekly picks, and priority. Founding members get Pro free.
```

## 3. 关键词 (100 字符内,逗号分隔,无空格)

```
networking,coffee chat,ai agent,warm intro,mentor,career,professional,alumni,connect,meet,startup
```

## 4. 推广文本 (Promotional Text, 170 字符,可随时改无需审核)

```
New: Brew now reaches people who aren't even on the app yet — one tap, no download, and your coffee is booked. Founding invites open now.
```

## 5. What's New (本次版本)

```
The first release of BrewNet — your AI networking agent that sets up coffee chats worth having. Tell Brew who you want to meet and it handles the rest.
```

## 6. 必填 URL

- **Support URL**: 需要一个支持页(可用 Notion/简单落地页)。建议: 建一个含邮箱的简单页面。
- **Privacy Policy URL**: 见下方 PRIVACY_POLICY.md，需托管到公网(Notion 公开页 / GitHub Pages / 简单站点均可),把 URL 填进来。**这是提交硬性要求。**
- **Marketing URL**（可选）

## 7. App Privacy（隐私营养标签，在 ASC 里勾选）

数据来源:PrivacyInfo.xcprivacy 已声明。ASC 里对应勾:
- **Contact Info → Email Address**: Linked to identity, App Functionality + Analytics, 不用于追踪
- **Contact Info → Name**: Linked, App Functionality
- **User Content → Photos**: Linked, App Functionality
- **Location → Precise Location**: Linked, App Functionality
- **Identifiers → User ID**: Linked, App Functionality
- **Usage Data → Product Interaction**: Linked, Analytics + App Functionality
- **Financial Info → Payment Info**: Linked, App Functionality（订阅用）
- **Tracking**: No（不追踪,无第三方广告 SDK）

## 8. 审核备注 (App Review Notes)

```
BrewNet is an AI-assisted professional networking app. To review core features, please use the demo account below. Matching, chat, and coffee scheduling all work against a seeded pool of demo profiles.

Demo account:
  Email: cj@umich.edu
  Password: 123456

Account deletion: Profile tab → top-right menu (•••) → Delete Account.
Sign in with Apple is supported on the login screen.
Push notifications require a real device (coffee acceptance / reminders).
```

## 9. 演示账号(给审核员)

- Email: `cj@umich.edu`
- Password: `123456`
（提交前确认这个号 profileSetupCompleted=true、能进主界面、池子非空。）

## 10. 截图（必需:6.7" 和 6.5"，各 3-10 张）

建议 5 张,叙事顺序:
1. Brew 对话首页(欢迎 + "who do you want to meet")
2. Talent Scout 精选卡(top-3 + 理由)
3. Brew Handshake 双盲提案卡
4. 站外 warm intro / 落地页
5. Weekly Brew / 见面简报

（可用 iPhone 17 Pro Max 模拟器截图,或真机截图。尺寸: 6.7"=1290×2796。)

---

## 提交前最终检查

- [ ] Build 8 处理完成(ASC 显示可选)
- [ ] Privacy Policy URL 已托管并填入
- [ ] Support URL 已填
- [ ] 截图已上传(6.7" + 6.5")
- [ ] App Privacy 问卷已按第 7 节勾选
- [ ] 演示账号可用 + 审核备注已填
- [ ] 加密合规:Info.plist 已设 ITSAppUsesNonExemptEncryption=false(不会再弹问)
- [ ] 撤销暴露过的 app-specific password
