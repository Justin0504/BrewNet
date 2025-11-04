# Profile 更新问题修复指南

## 问题描述

错误：`cannot cast type profiles to jsonb`

这个错误表明 PostgREST 在尝试更新 JSONB 字段时遇到了类型转换问题。这是一个已知的 PostgREST bug，可能与表名或 JSONB 字段的处理有关。

## 可能的解决方案

### 方案 1: 检查 PostgREST 版本

在 Supabase Dashboard 中：
1. 进入 Settings → API
2. 检查 PostgREST 版本
3. 如果版本较旧，尝试更新

### 方案 2: 使用 Supabase Edge Functions

创建一个 Edge Function 来更新 profile，完全绕过 PostgREST：

```typescript
// supabase/functions/update-profile/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { profileId, profileData } = await req.json()
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    const { data, error } = await supabase
      .from('profiles')
      .update(profileData)
      .eq('id', profileId)
      .select()
      .single()
    
    if (error) throw error
    
    return new Response(JSON.stringify(data), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
```

### 方案 3: 使用数据库函数（推荐）

使用我们创建的 `update_profile_jsonb` RPC 函数，但需要确保函数签名正确。

### 方案 4: 检查数据库配置

执行以下 SQL 检查是否有问题：

```sql
-- 检查 profiles 表结构
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles';

-- 检查是否有视图
SELECT viewname FROM pg_views WHERE viewname LIKE '%profile%';

-- 检查 PostgREST schema cache
-- 可能需要刷新 schema cache
NOTIFY pgrst, 'reload schema';
```

### 方案 5: 临时解决方案

如果更新失败，可以：
1. 删除旧 profile
2. 创建新 profile（使用 createProfile）

但这会丢失 created_at 时间戳。

## 当前状态

- ✅ Profile 读取正常
- ✅ Profile 创建正常
- ❌ Profile 更新失败（PostgREST bug）

## 建议

1. **短期**: 使用创建新 profile + 删除旧 profile 的方式（如果允许）
2. **中期**: 创建 Supabase Edge Function 来更新 profile
3. **长期**: 等待 PostgREST 修复或升级版本

## 测试步骤

1. 在 Supabase Dashboard 中执行 `test_profile_update_direct.sql` 测试直接 SQL 更新
2. 如果直接 SQL 更新成功，说明问题在 PostgREST
3. 考虑使用 Edge Functions 作为解决方案

