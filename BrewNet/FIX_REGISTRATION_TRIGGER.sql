-- =============================================
-- 紧急修复：禁用导致注册失败的触发器
-- 执行位置：Supabase Dashboard → SQL Editor
-- =============================================

-- 步骤 1: 查看当前触发器
SELECT 
    trigger_name,
    event_object_table,
    event_object_schema,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
   OR (event_object_table = 'users' AND event_object_schema = 'public');

-- 步骤 2: 禁用 credibility 触发器（导致注册失败的根本原因）
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;

-- 步骤 3: 验证触发器已删除
SELECT 
    trigger_name,
    event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created_create_credibility';
-- 应该返回空结果（0 行）

-- =============================================
-- 验证修复结果
-- =============================================

-- 查看剩余的触发器
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
ORDER BY trigger_name;

-- =============================================
-- 现在可以测试注册了
-- =============================================
-- 1. 在应用中尝试注册新用户
-- 2. 应该成功！
-- 3. 用户会在 auth.users 和 public.users 中创建
-- 4. credibility_scores 需要稍后手动创建（见下一步）

-- =============================================
-- 后续步骤：为用户创建信誉评分（可选）
-- =============================================

-- 方式 1: 批量为现有用户创建信誉评分
INSERT INTO credibility_scores (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM credibility_scores)
ON CONFLICT (user_id) DO NOTHING;

-- 方式 2: 在应用代码中延迟创建
-- 当用户首次查看信誉评分时，自动创建

-- =============================================
-- 验证数据一致性
-- =============================================

-- 检查用户表数据
SELECT 
    'auth.users 用户数' as metric,
    COUNT(*) as count
FROM auth.users
UNION ALL
SELECT 
    'public.users 用户数',
    COUNT(*)
FROM users
UNION ALL
SELECT 
    'credibility_scores 记录数',
    COUNT(*)
FROM credibility_scores;

-- 查找缺少信誉评分的用户
SELECT 
    au.id,
    au.email,
    pu.name
FROM auth.users au
LEFT JOIN users pu ON au.id::text = pu.id
LEFT JOIN credibility_scores cs ON au.id = cs.user_id
WHERE cs.user_id IS NULL;

-- =============================================
-- 完成
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '✅ 触发器已禁用';
    RAISE NOTICE '✅ 现在可以正常注册了';
    RAISE NOTICE '💡 提示：新用户的信誉评分需要稍后手动创建或在应用中延迟创建';
END $$;

