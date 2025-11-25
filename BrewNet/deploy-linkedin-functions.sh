#!/bin/bash

# LinkedIn OAuth Functions Deployment Script
# This script deploys both LinkedIn callback and exchange functions to Supabase

set -e  # Exit on error

echo "🚀 LinkedIn OAuth Functions Deployment Script"
echo "=============================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI is not installed${NC}"
    echo "Install it with: brew install supabase/tap/supabase"
    echo "Or: npm install -g supabase"
    exit 1
fi

echo -e "${GREEN}✅ Supabase CLI found${NC}"
echo ""

# Check if user is logged in
if ! supabase projects list &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Supabase${NC}"
    echo "Running: supabase login"
    supabase login
fi

# Check if project is linked
if [ ! -f "supabase/.temp/project-ref" ]; then
    echo -e "${YELLOW}⚠️  Project not linked${NC}"
    echo "Linking to project: jcxvdolcdifdghaibspy"
    supabase link --project-ref jcxvdolcdifdghaibspy
fi

echo -e "${GREEN}✅ Project linked${NC}"
echo ""

# Check environment variables
echo "Checking environment variables..."
if ! supabase secrets list | grep -q "LINKEDIN_CLIENT_ID"; then
    echo -e "${YELLOW}⚠️  LINKEDIN_CLIENT_ID not set${NC}"
    echo "Set it with: supabase secrets set LINKEDIN_CLIENT_ID=782dcovcs9zyfv"
fi

if ! supabase secrets list | grep -q "LINKEDIN_CLIENT_SECRET"; then
    echo -e "${RED}❌ LINKEDIN_CLIENT_SECRET not set${NC}"
    echo "Set it with: supabase secrets set LINKEDIN_CLIENT_SECRET=your_secret"
    exit 1
fi

if ! supabase secrets list | grep -q "LINKEDIN_REDIRECT_URI"; then
    echo -e "${YELLOW}⚠️  LINKEDIN_REDIRECT_URI not set${NC}"
    echo "Set it with: supabase secrets set LINKEDIN_REDIRECT_URI=https://brewnet.app/auth/linkedin/callback"
fi

echo -e "${GREEN}✅ Environment variables checked${NC}"
echo ""

# Deploy Callback function
echo "📦 Deploying linkedin-callback function..."
if supabase functions deploy linkedin-callback --no-verify-jwt; then
    echo -e "${GREEN}✅ linkedin-callback deployed successfully${NC}"
else
    echo -e "${RED}❌ linkedin-callback deployment failed${NC}"
    exit 1
fi
echo ""

# Deploy Exchange function
echo "📦 Deploying linkedin-exchange function..."
if supabase functions deploy linkedin-exchange --no-verify-jwt; then
    echo -e "${GREEN}✅ linkedin-exchange deployed successfully${NC}"
else
    echo -e "${RED}❌ linkedin-exchange deployment failed${NC}"
    exit 1
fi
echo ""

# Deploy Import function
echo "📦 Deploying linkedin-import function..."
if supabase functions deploy linkedin-import --no-verify-jwt; then
    echo -e "${GREEN}✅ linkedin-import deployed successfully${NC}"
else
    echo -e "${RED}❌ linkedin-import deployment failed${NC}"
    exit 1
fi
echo ""

# Summary
echo "=============================================="
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo ""
echo "Function URLs:"
echo "  Callback: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback"
echo "  Exchange: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-exchange"
echo "  Import: https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-import"
echo ""
echo "Next steps:"
echo "  1. Configure LinkedIn Developer Portal redirect URL"
echo "  2. Test the OAuth flow in your iOS app"
echo "  3. Check logs: supabase functions logs linkedin-callback"
echo ""

