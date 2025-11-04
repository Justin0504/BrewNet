#!/bin/bash

# 检查 Edge Function 是否部署的脚本

echo "🔍 检查 Edge Function 部署状态..."
echo ""

PROJECT_REF="jcxvdolcdifdghaibspy"
FUNCTION_NAME="gemini-ai"
FUNCTION_URL="https://${PROJECT_REF}.supabase.co/functions/v1/${FUNCTION_NAME}"

echo "📋 项目信息："
echo "   - 项目 ID: ${PROJECT_REF}"
echo "   - 函数名称: ${FUNCTION_NAME}"
echo "   - 函数 URL: ${FUNCTION_URL}"
echo ""

echo "🧪 测试函数是否存在..."
echo ""

# 测试函数（不需要认证，看看返回什么）
response=$(curl -s -w "\n%{http_code}" -X POST "${FUNCTION_URL}" \
  -H "Content-Type: application/json" \
  -H "apikey: test" \
  -d '{"prompt":"test"}' 2>&1)

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

echo "📊 HTTP 状态码: ${http_code}"
echo "📄 响应内容: ${body}"
echo ""

if [ "$http_code" == "404" ]; then
    echo "❌ 函数未找到！"
    echo ""
    echo "请检查："
    echo "1. 在 Supabase Dashboard 中确认函数名称是 'gemini-ai'（完全小写）"
    echo "2. 确认函数已成功部署（状态显示 'Deployed' 或 'Active'）"
    echo "3. 确认项目 ID 正确：${PROJECT_REF}"
    echo "4. 尝试在 Dashboard 中测试函数"
elif [ "$http_code" == "401" ]; then
    echo "✅ 函数存在！但需要认证"
    echo "这意味着函数已部署，只是需要有效的认证 token"
elif [ "$http_code" == "400" ]; then
    echo "✅ 函数存在！但请求格式不正确"
    echo "这意味着函数已部署，只是请求参数有问题"
else
    echo "📊 状态码: ${http_code}"
    echo "响应: ${body}"
fi

