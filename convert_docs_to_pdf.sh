#!/bin/bash

# BrewNet 文档转 PDF 脚本
# 使用前确保已安装: brew install pandoc
# 中文支持需要: brew install --cask mactex-no-gui

echo "🔄 开始转换 Markdown 文档为 PDF..."

# 检查 Pandoc 是否安装
if ! command -v pandoc &> /dev/null; then
    echo "❌ 未检测到 Pandoc，请先安装:"
    echo "   brew install pandoc"
    echo "   brew install --cask mactex-no-gui"
    exit 1
fi

# 创建 PDF 输出目录
mkdir -p PDF_Exports

# 转换主要文档
docs=(
    "README.md"
    "TECHNICAL_DOCUMENTATION.md"
    "APP_STORE_LAUNCH_CHECKLIST.md"
    "APP_STORE_MARKETING.md"
    "PRIVACY_POLICY_DRAFT.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        echo "📄 转换: $doc"
        output="PDF_Exports/${doc%.md}.pdf"
        
        pandoc "$doc" -o "$output" \
            --pdf-engine=xelatex \
            --toc \
            --toc-depth=3 \
            -V geometry:margin=1in \
            -V mainfont="PingFang SC" \
            -V monofont="Monaco" \
            -V colorlinks=true \
            -V linkcolor=blue \
            -V urlcolor=blue \
            -V toccolor=black \
            --highlight-style=tango \
            --metadata title="${doc%.md}" \
            --metadata author="BrewNet Team" \
            --metadata date="$(date +%Y-%m-%d)"
        
        if [ $? -eq 0 ]; then
            echo "   ✅ 成功: $output"
        else
            echo "   ❌ 失败: $doc"
        fi
    else
        echo "   ⚠️  未找到: $doc"
    fi
done

echo ""
echo "🎉 转换完成！PDF 文件保存在 PDF_Exports/ 目录"
echo ""
echo "📊 生成的文件:"
ls -lh PDF_Exports/*.pdf 2>/dev/null || echo "   无文件生成"

