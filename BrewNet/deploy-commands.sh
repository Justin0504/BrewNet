#!/bin/bash

echo "🚀 LinkedIn OAuth 部署命令"
echo "=========================="
echo ""

echo "步骤 1: 登录 Supabase（会打开浏览器）"
echo "supabase login"
echo ""

echo "步骤 2: 链接项目"
echo "supabase link --project-ref jcxvdolcdifdghaibspy"
echo ""

echo "步骤 3: 设置环境变量"
echo "supabase secrets set LINKEDIN_CLIENT_ID=782dcovcs9zyfv"
echo "supabase secrets set LINKEDIN_CLIENT_SECRET=YOUR_LINKEDIN_CLIENT_SECRET_HERE"
echo "supabase secrets set LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback"
echo ""

echo "步骤 4: 验证环境变量"
echo "supabase secrets list"
echo ""

echo "步骤 5: 部署 Callback 函数"
echo "supabase functions deploy linkedin-callback --no-verify-jwt"
echo ""

echo "步骤 6: 部署 Exchange 函数"
echo "supabase functions deploy linkedin-exchange --no-verify-jwt"
echo ""

echo "步骤 7: 测试 Callback 函数"
echo "curl \"https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback?code=test123&state=test456\""
echo ""

echo "步骤 8: 查看函数日志"
echo "supabase functions logs linkedin-callback"
echo "supabase functions logs linkedin-exchange"
echo ""

echo "✅ 完成！"
