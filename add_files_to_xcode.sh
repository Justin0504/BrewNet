#!/bin/bash

# 添加信誉评分系统文件到 Xcode 项目
# 用法: ./add_files_to_xcode.sh

echo "📦 准备添加信誉评分系统文件到 Xcode 项目..."

PROJECT_DIR="/Users/justin/BrewNet-Fresh/BrewNet"
PROJECT_FILE="$PROJECT_DIR/BrewNet.xcodeproj/project.pbxproj"

# 检查项目文件是否存在
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ 错误: 找不到项目文件 $PROJECT_FILE"
    exit 1
fi

# 要添加的文件列表
FILES=(
    "BrewNet/CredibilitySystem.swift"
    "BrewNet/MeetingRatingView.swift"
    "BrewNet/MisconductReportView.swift"
    "BrewNet/CredibilityBadgeView.swift"
)

echo ""
echo "🔍 检查文件是否存在..."
for file in "${FILES[@]}"; do
    full_path="$PROJECT_DIR/$file"
    if [ -f "$full_path" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (不存在)"
        exit 1
    fi
done

echo ""
echo "⚠️  注意: 由于 Xcode 项目文件格式复杂，建议手动添加文件。"
echo ""
echo "请按照以下步骤操作："
echo ""
echo "1️⃣  打开 Xcode："
echo "   双击打开 BrewNet.xcodeproj"
echo ""
echo "2️⃣  在左侧项目导航器中，右键点击 'BrewNet/BrewNet' 文件夹"
echo ""
echo "3️⃣  选择 'Add Files to BrewNet'"
echo ""
echo "4️⃣  导航到以下目录并选择这4个文件（按住 Command 键多选）："
echo "   📁 $PROJECT_DIR/BrewNet/"
echo ""
for file in "${FILES[@]}"; do
    filename=$(basename "$file")
    echo "   ✅ $filename"
done
echo ""
echo "5️⃣  确保勾选："
echo "   ☑️  'Add to targets: BrewNet'"
echo "   ☑️  'Create groups' (不是 Create folder references)"
echo ""
echo "6️⃣  点击 'Add' 按钮"
echo ""
echo "7️⃣  清理并重新编译："
echo "   Shift + Command + K (清理)"
echo "   Command + B (编译)"
echo ""
echo "8️⃣  运行测试："
echo "   Command + R"
echo ""
echo "完成后，评分界面应该会在确认见面后弹出！🎉"
echo ""

