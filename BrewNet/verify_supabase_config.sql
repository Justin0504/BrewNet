-- =====================================================
-- BrewNet Supabase 配置验证脚本
-- 用于检查所有必要的表和配置是否已正确设置
-- =====================================================

-- =====================================================
-- 1. 检查表是否存在
-- =====================================================

SELECT 
    '1. 表检查' AS check_category,
    table_name AS item_name,
    CASE 
        WHEN table_name IN ('users', 'profiles', 'posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages', 'anonymous_posts') 
        THEN '✅ 存在' 
        ELSE '⚠️ 其他表' 
    END AS status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('users', 'profiles', 'posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages', 'anonymous_posts')
ORDER BY table_name;

-- =====================================================
-- 2. 检查 profiles 表结构
-- =====================================================

SELECT 
    '2. profiles 表字段' AS check_category,
    column_name AS item_name,
    data_type AS item_type,
    CASE 
        WHEN column_name IN ('core_identity', 'professional_background', 'networking_intention', 'networking_preferences', 'personality_social', 'privacy_trust')
        THEN '✅ JSONB 字段正确'
        WHEN column_name IN ('id', 'user_id', 'created_at', 'updated_at')
        THEN '✅ 基础字段正确'
        ELSE '✅ 其他字段'
    END AS status
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'profiles'
ORDER BY column_name;

-- =====================================================
-- 3. 检查 profiles 表是否包含正确的 JSONB 字段
-- =====================================================

SELECT 
    '3. JSONB 字段验证' AS check_category,
    column_name AS item_name,
    CASE 
        WHEN data_type = 'jsonb' 
        THEN '✅ JSONB 类型正确' 
        ELSE '❌ 类型不正确'
    END AS status
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'profiles'
AND column_name IN ('core_identity', 'professional_background', 'networking_intention', 'networking_preferences', 'personality_social', 'privacy_trust');

-- =====================================================
-- 4. 检查索引
-- =====================================================

SELECT 
    '4. 索引检查' AS check_category,
    indexname AS item_name,
    CASE 
        WHEN indexname LIKE 'idx_%' 
        THEN '✅ 索引已创建' 
        ELSE '⚠️ 系统索引'
    END AS status
FROM pg_indexes
WHERE schemaname = 'public' 
AND tablename = 'profiles'
ORDER BY indexname;

-- =====================================================
-- 5. 检查 RLS 是否启用
-- =====================================================

SELECT 
    '5. RLS 状态' AS check_category,
    tablename AS item_name,
    CASE 
        WHEN rowsecurity = true 
        THEN '✅ RLS 已启用' 
        ELSE '❌ RLS 未启用'
    END AS status
FROM pg_tables
WHERE schemaname = 'public' 
AND tablename = 'profiles';

-- =====================================================
-- 6. 检查 RLS 策略
-- =====================================================

SELECT 
    '6. RLS 策略' AS check_category,
    policyname AS item_name,
    CASE 
        WHEN policyname IN ('Users can view their own profile', 'Users can update their own profile', 'Users can insert their own profile')
        THEN '✅ 策略已创建'
        ELSE '⚠️ 其他策略'
    END AS status
FROM pg_policies
WHERE schemaname = 'public' 
AND tablename = 'profiles'
ORDER BY policyname;

-- =====================================================
-- 7. 检查触发器
-- =====================================================

SELECT 
    '7. 触发器检查' AS check_category,
    trigger_name AS item_name,
    CASE 
        WHEN trigger_name = 'update_profiles_updated_at' 
        THEN '✅ 更新时间触发器已创建' 
        ELSE '⚠️ 其他触发器'
    END AS status
FROM information_schema.triggers
WHERE trigger_schema = 'public' 
AND event_object_table = 'profiles'
ORDER BY trigger_name;

-- =====================================================
-- 8. 检查触发器函数
-- =====================================================

SELECT 
    '8. 触发器函数' AS check_category,
    routine_name AS item_name,
    CASE 
        WHEN routine_name = 'update_updated_at_column' 
        THEN '✅ 触发器函数已创建' 
        ELSE '⚠️ 其他函数'
    END AS status
FROM information_schema.routines
WHERE routine_schema = 'public' 
AND routine_name = 'update_updated_at_column';

-- =====================================================
-- 9. 检查 auth.users 表（Supabase Auth）
-- =====================================================

SELECT 
    '9. Auth 用户表' AS check_category,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'auth' AND tablename = 'users')
        THEN '✅ auth.users 表存在'
        ELSE '❌ auth.users 表不存在'
    END AS item_name,
    'N/A' AS status;

-- =====================================================
-- 10. 检查外键约束
-- =====================================================

SELECT 
    '10. 外键约束' AS check_category,
    constraint_name AS item_name,
    CASE 
        WHEN constraint_type = 'FOREIGN KEY' 
        THEN '✅ 外键已创建' 
        ELSE '⚠️ 其他约束'
    END AS status
FROM information_schema.table_constraints
WHERE table_schema = 'public' 
AND table_name = 'profiles'
AND constraint_type = 'FOREIGN KEY';

-- =====================================================
-- 11. 检查数据完整性（示例数据）
-- =====================================================

SELECT 
    '11. 数据统计' AS check_category,
    'profiles 记录数' AS item_name,
    CASE 
        WHEN COUNT(*) >= 0 
        THEN '✅ ' || COUNT(*)::text || ' 条记录' 
        ELSE '❌ 查询失败'
    END AS status
FROM profiles;

SELECT 
    '11. 数据统计' AS check_category,
    'users 记录数' AS item_name,
    CASE 
        WHEN COUNT(*) >= 0 
        THEN '✅ ' || COUNT(*)::text || ' 条记录' 
        ELSE '❌ 查询失败'
    END AS status
FROM users;

-- =====================================================
-- 12. 检查 legacy networking_intent 字段（不应该存在）
-- =====================================================

SELECT 
    '12. 旧字段检查' AS check_category,
    'networking_intent 字段' AS item_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'profiles' 
            AND column_name = 'networking_intent'
        )
        THEN '⚠️ 旧字段仍存在，需要迁移'
        ELSE '✅ 旧字段已移除'
    END AS status;

-- =====================================================
-- 13. 最终验证结果汇总
-- =====================================================

DO $$
DECLARE
    v_table_count INTEGER;
    v_rls_enabled BOOLEAN;
    v_policy_count INTEGER;
    v_trigger_count INTEGER;
    v_correct_jsonb_fields INTEGER;
BEGIN
    -- 统计核心表数量
    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN ('users', 'profiles');
    
    -- 检查 RLS 状态
    SELECT rowsecurity INTO v_rls_enabled
    FROM pg_tables
    WHERE schemaname = 'public' 
    AND tablename = 'profiles';
    
    -- 统计策略数量
    SELECT COUNT(*) INTO v_policy_count
    FROM pg_policies
    WHERE schemaname = 'public' 
    AND tablename = 'profiles';
    
    -- 统计触发器数量
    SELECT COUNT(*) INTO v_trigger_count
    FROM information_schema.triggers
    WHERE trigger_schema = 'public' 
    AND event_object_table = 'profiles';
    
    -- 统计正确的 JSONB 字段数量
    SELECT COUNT(*) INTO v_correct_jsonb_fields
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'profiles'
    AND column_name IN ('core_identity', 'professional_background', 'networking_intention', 'networking_preferences', 'personality_social', 'privacy_trust')
    AND data_type = 'jsonb';
    
    -- 输出汇总
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'BrewNet Supabase 配置验证结果汇总';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE '核心表数量: %', v_table_count;
    RAISE NOTICE 'RLS 已启用: %', v_rls_enabled;
    RAISE NOTICE 'RLS 策略数量: %', v_policy_count;
    RAISE NOTICE '触发器数量: %', v_trigger_count;
    RAISE NOTICE '正确 JSONB 字段数: %', v_correct_jsonb_fields;
    RAISE NOTICE '';
    
    -- 最终判断
    IF v_table_count >= 2 
       AND v_rls_enabled = true 
       AND v_policy_count >= 3 
       AND v_trigger_count >= 1 
       AND v_correct_jsonb_fields = 6 THEN
        RAISE NOTICE '✅ 配置验证通过！所有设置正确。';
    ELSE
        RAISE NOTICE '❌ 配置验证失败！请检查上述项目。';
        RAISE NOTICE '';
        IF v_table_count < 2 THEN
            RAISE NOTICE '   - 缺少核心表，请运行 quick_profiles_setup.sql';
        END IF;
        IF v_rls_enabled = false THEN
            RAISE NOTICE '   - RLS 未启用';
        END IF;
        IF v_policy_count < 3 THEN
            RAISE NOTICE '   - RLS 策略不足，应该有 3 个策略';
        END IF;
        IF v_trigger_count < 1 THEN
            RAISE NOTICE '   - 缺少触发器';
        END IF;
        IF v_correct_jsonb_fields < 6 THEN
            RAISE NOTICE '   - JSONB 字段不正确，应该有 6 个字段';
        END IF;
    END IF;
    
    RAISE NOTICE '=====================================================';
END $$;

-- =====================================================
-- 完成
-- =====================================================

-- 提示：运行此脚本将显示详细的验证结果
-- 所有检查项都应该显示 ✅ 状态

