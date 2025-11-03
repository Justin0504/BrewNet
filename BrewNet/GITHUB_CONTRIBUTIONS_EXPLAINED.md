# GitHub Contributions 和 Branch 显示问题解释

## 🔍 问题分析

### 为什么看不到 Cancannewneew-CHN 的 branch？

**原因：**
1. **Fork 仓库模式**：
   - 用户 `Cancannewneew-CHN` 的工作在**他自己的 fork 仓库**中
   - Fork 仓库：`https://github.com/Cancannewneew-CHN/BrewNet.git`
   - 主仓库：`https://github.com/Justin0504/BrewNet.git`

2. **分支位置**：
   - 分支 `Cancannewneew` 在用户的 fork 仓库中，**不在主仓库**
   - 在主仓库的 GitHub 页面上，你只能看到主仓库的分支
   - Fork 仓库的分支需要通过 PR 来查看

### 为什么看不到他的 Contributions？

**原因：**
GitHub 的 Contributions Graph 有特定规则：

1. **直接提交到主仓库**：
   - ✅ 直接在主仓库中 commit 会显示在 contributions graph
   - ❌ 通过 PR merge 的提交**不会**显示原始作者的 contributions（除非特定条件）

2. **PR Merge 的情况**：
   - 当 PR 被合并时，GitHub 创建的是一个 **merge commit**
   - Merge commit 的作者是**合并者**（通常是仓库维护者），不是原始 PR 作者
   - 所以 contributions graph 中可能显示的是合并者，而不是 PR 作者

3. **条件**：
   GitHub **只会在以下情况显示 contributions**：
   - ✅ 直接在主仓库分支上的提交
   - ✅ 提交到主仓库的默认分支（main/master）
   - ✅ 提交是最近 1 年内
   - ✅ 提交者邮箱与 GitHub 账户关联

**PR 合并的提交：**
- ❌ 通常不显示在原始作者的 contributions graph
- ✅ 但会显示在 PR 历史中
- ✅ 会显示在仓库的 commit 历史中

---

## 📊 当前情况分析

从 Git 历史看到：

```bash
# Fork 仓库中的提交（Cancannewneew-CHN 的仓库）
3ede080 Cancannewneew <...> feat: Unify color theme across app
73edef1 Cancannewneew <...> Update BrewNet UI

# 主仓库中的合并提交
a56e9dc HAAP HANG LIU <...> Merge pull request #2 from Cancannewneew-CHN/Cancannewneew
```

**这意味着：**
- ✅ 用户的代码在**他的 fork** 中
- ✅ PR 被合并到**主仓库**
- ⚠️ Contributions graph 可能显示的是合并者（HAAP HANG LIU），而不是原始作者

---

## 🔧 如何查看用户的贡献？

### 方法 1: 查看 PR 历史
```
GitHub → Pull Requests → 查看所有 PR
```
可以看到所有来自 `Cancannewneew-CHN` 的 PR

### 方法 2: 查看 Fork 仓库
```
https://github.com/Cancannewneew-CHN/BrewNet
```
直接在用户的 fork 仓库中查看他的所有分支和提交

### 方法 3: 使用 Git 命令
```bash
# 查看用户的所有提交（包括 fork）
git log --all --author="Cancannewneew"

# 查看 PR 相关的提交
git log --all --grep="pull request" --oneline

# 查看合并提交的详细信息
git show <merge-commit-hash>
```

### 方法 4: 查看 Git Blame（文件级别的贡献）
在 GitHub 文件页面，可以看到每一行的作者信息

---

## 💡 解决方案

### 如果想在主仓库看到用户的贡献：

**选项 A: Co-author 提交（推荐）**
在合并 PR 时，可以添加原始作者为 co-author：
```bash
git commit --amend --author="Cancannewneew <email>"
```

**选项 B: 使用 squash and merge**
- GitHub PR 设置中，使用 "Squash and merge"
- 合并时可以编辑提交信息，添加原始作者

**选项 C: 直接在主仓库创建分支**
让用户在主仓库中直接创建分支（需要 write access）

---

## 📝 如何查看用户的 Fork 和分支？

### 在 GitHub 上：

1. **查看用户的 Fork**：
   ```
   https://github.com/Cancannewneew-CHN/BrewNet
   ```

2. **查看 PR 详情**：
   - 主仓库 → Pull Requests → PR #6
   - 可以看到 PR 来自哪个 fork 和分支

3. **查看用户的所有 PR**：
   - 在主仓库的 PR 列表中筛选：`author:Cancannewneew-CHN`

### 在本地：

```bash
# 查看 fork 仓库的分支
git fetch canc
git branch -r | grep canc

# 查看 fork 仓库的提交
git log canc/main --oneline

# 查看特定分支
git show canc/Cancannewneew
```

---

## 🎯 总结

**为什么看不到：**
- ✅ 分支在 fork 仓库中，不在主仓库
- ✅ Contributions 显示的是合并者，不是原始 PR 作者（GitHub 的设计）

**如何查看：**
- ✅ 通过 PR 历史查看
- ✅ 直接在用户的 fork 仓库查看
- ✅ 使用 Git 命令查看

**这是正常的 GitHub 工作流**：
- Fork → 创建分支 → PR → 合并
- 这种模式下，原始贡献会在 fork 仓库和 PR 历史中可见

