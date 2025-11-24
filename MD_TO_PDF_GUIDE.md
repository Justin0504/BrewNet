# Markdown 转 PDF 指南

## 🚀 快速开始 (推荐方法)

### 方法 1: 使用提供的脚本 (一键转换所有文档)

#### 第一步: 安装依赖
```bash
# 安装 Pandoc
brew install pandoc

# 安装 LaTeX (用于生成高质量中文 PDF)
brew install --cask mactex-no-gui
# 注意: mactex 大约 4GB，下载需要时间
```

#### 第二步: 运行转换脚本
```bash
cd /Users/justin/BrewNet-Fresh
./convert_docs_to_pdf.sh
```

#### 结果
所有 PDF 文件会生成在 `PDF_Exports/` 目录中：
- `README.pdf`
- `TECHNICAL_DOCUMENTATION.pdf`
- `APP_STORE_LAUNCH_CHECKLIST.pdf`
- `APP_STORE_MARKETING.md`
- `PRIVACY_POLICY_DRAFT.pdf`

---

## 📝 单独转换某个文件

### 基础转换 (最简单)
```bash
pandoc README.md -o README.pdf
```

### 高质量转换 (推荐)
```bash
pandoc README.md -o README.pdf \
  --pdf-engine=xelatex \
  --toc \
  --toc-depth=3 \
  -V geometry:margin=1in \
  -V mainfont="PingFang SC" \
  -V colorlinks=true
```

### 参数说明
- `--pdf-engine=xelatex`: 使用 XeLaTeX 引擎 (支持中文)
- `--toc`: 生成目录
- `--toc-depth=3`: 目录深度为 3 级
- `-V geometry:margin=1in`: 页边距 1 英寸
- `-V mainfont="PingFang SC"`: 使用苹方字体 (中文支持)
- `-V colorlinks=true`: 链接显示为彩色

---

## 🌐 方法 2: 在线转换 (无需安装)

### 推荐网站

1. **Markdown to PDF** (最简单)
   - 网址: https://www.markdowntopdf.com/
   - 步骤: 上传 `.md` 文件 → 点击转换 → 下载 PDF

2. **CloudConvert** (功能强大)
   - 网址: https://cloudconvert.com/md-to-pdf
   - 支持批量转换
   - 可以自定义样式

3. **Dillinger** (在线编辑器)
   - 网址: https://dillinger.io/
   - 实时预览
   - 直接导出 PDF

### 使用步骤
1. 打开任一网站
2. 上传 `.md` 文件或粘贴内容
3. 点击 "Convert" 或 "Export"
4. 下载生成的 PDF

---

## 💻 方法 3: VS Code 插件

### 安装步骤
1. 打开 VS Code
2. 进入扩展市场 (Cmd+Shift+X)
3. 搜索 **"Markdown PDF"**
4. 安装插件

### 使用步骤
1. 在 VS Code 中打开 `.md` 文件
2. 右键点击编辑器
3. 选择 **"Markdown PDF: Export (pdf)"**
4. PDF 会保存在同一目录

### 配置 (可选)
在 VS Code 设置中搜索 "Markdown PDF"，可以自定义：
- 页边距
- 字体
- 页眉页脚
- 样式表

---

## 📱 方法 4: Typora (所见即所得)

### 安装
- 下载地址: https://typora.io/
- 支持 macOS, Windows, Linux
- 付费软件 ($14.99)

### 使用步骤
1. 用 Typora 打开 `.md` 文件
2. 菜单栏: **File → Export → PDF**
3. 选择保存位置

### 优点
- 所见即所得编辑
- PDF 样式美观
- 完美支持中文
- 支持自定义主题

---

## 🎨 高级自定义

### 使用自定义 CSS 样式
```bash
pandoc README.md -o README.pdf \
  --pdf-engine=xelatex \
  --css=custom-style.css \
  -V mainfont="PingFang SC"
```

### 添加封面页
```bash
pandoc README.md -o README.pdf \
  --pdf-engine=xelatex \
  --toc \
  --metadata title="BrewNet Technical Documentation" \
  --metadata author="BrewNet Team" \
  --metadata date="2025-11-20"
```

### 合并多个 MD 文件为一个 PDF
```bash
pandoc README.md TECHNICAL_DOCUMENTATION.md -o Combined.pdf \
  --pdf-engine=xelatex \
  --toc \
  -V mainfont="PingFang SC"
```

---

## ⚙️ 安装说明

### macOS

#### Pandoc
```bash
brew install pandoc
```

#### LaTeX (用于高质量 PDF)
```bash
# 完整版 (约 4GB)
brew install --cask mactex

# 精简版 (推荐，约 400MB)
brew install --cask mactex-no-gui

# 或使用 BasicTeX (最小版本，约 100MB)
brew install --cask basictex
```

#### 验证安装
```bash
pandoc --version
xelatex --version
```

---

## 🐛 常见问题

### Q1: 中文显示乱码或方框？
**A**: 需要使用支持中文的字体
```bash
pandoc file.md -o file.pdf \
  --pdf-engine=xelatex \
  -V mainfont="PingFang SC"  # 或 "Songti SC", "Heiti SC"
```

### Q2: 报错 "xelatex not found"？
**A**: 需要安装 LaTeX
```bash
brew install --cask mactex-no-gui
```

安装后，可能需要重启终端或添加到 PATH:
```bash
export PATH="/Library/TeX/texbin:$PATH"
```

### Q3: 表格或代码块显示不正确？
**A**: 使用 `--highlight-style` 参数
```bash
pandoc file.md -o file.pdf \
  --highlight-style=tango \
  -V geometry:margin=0.75in
```

### Q4: 图片显示不出来？
**A**: 确保图片路径正确，使用相对路径或绝对路径
```markdown
# 相对路径
![Logo](./images/logo.png)

# 绝对路径
![Logo](/Users/justin/BrewNet-Fresh/logo.png)
```

### Q5: PDF 文件太大？
**A**: 压缩图片或使用在线工具压缩 PDF
```bash
# 使用 ImageMagick 压缩图片
brew install imagemagick
convert original.png -quality 85 compressed.png
```

---

## 📊 各方法对比

| 方法 | 优点 | 缺点 | 适合场景 |
|------|------|------|----------|
| **Pandoc** | 免费、功能强大、可自动化 | 需要安装、学习曲线 | 批量转换、自动化 |
| **在线工具** | 无需安装、即用即走 | 需要网络、隐私风险 | 临时使用 |
| **VS Code** | 集成编辑器、方便 | 功能相对简单 | 日常开发 |
| **Typora** | 所见即所得、美观 | 付费软件 | 专业文档编辑 |

---

## 🎯 推荐方案

### 场景 1: 批量转换所有文档
**使用**: 提供的 `convert_docs_to_pdf.sh` 脚本

### 场景 2: 单个文件转换
**使用**: Pandoc 命令行或在线工具

### 场景 3: 编辑和导出
**使用**: Typora 或 VS Code 插件

### 场景 4: 需要精美排版
**使用**: Pandoc + 自定义 LaTeX 模板

---

## 📚 参考资源

- **Pandoc 官方文档**: https://pandoc.org/
- **Pandoc 用户指南**: https://pandoc.org/MANUAL.html
- **LaTeX 模板**: https://github.com/Wandmalfarbe/pandoc-latex-template
- **Markdown 语法**: https://www.markdownguide.org/

---

**需要帮助？** 查看技术文档或联系开发团队。



