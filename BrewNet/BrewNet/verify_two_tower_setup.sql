-- Two-Tower Recommendation System Verification Script
-- Created: 2024-12-28
-- Purpose: 验证 Two-Tower 推荐系统是否正确设置

-- ============================================================
-- 1. 检查表是否存在
-- ============================================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Two-Tower System Verification';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;

-- 检查表、索引、函数、触发器和统计
DO $$
DECLARE
    user_features_count INT;
    user_interactions_count INT;
    recommendation_cache_count INT;
    profiles_count INT;
BEGIN
    -- 检查 user_features 表
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_features') THEN
        RAISE NOTICE '✅ user_features table exists';
    ELSE
        RAISE NOTICE '❌ user_features table NOT found';
    END IF;
    
    -- 检查 user_interactions 表
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_interactions') THEN
        RAISE NOTICE '✅ user_interactions table exists';
    ELSE
        RAISE NOTICE '❌ user_interactions table NOT found';
    END IF;
    
    -- 检查 recommendation_cache 表
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'recommendation_cache') THEN
        RAISE NOTICE '✅ recommendation_cache table exists';
    ELSE
        RAISE NOTICE '❌ recommendation_cache table NOT found';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Checking indexes...';
    
    -- user_features 索引
    IF EXISTS (SELECT FROM pg_indexes WHERE tablename = 'user_features' AND indexname = 'idx_user_features_industry') THEN
        RAISE NOTICE '  ✅ idx_user_features_industry';
    ELSE
        RAISE NOTICE '  ❌ idx_user_features_industry missing';
    END IF;
    
    IF EXISTS (SELECT FROM pg_indexes WHERE tablename = 'user_features' AND indexname = 'idx_user_features_intention') THEN
        RAISE NOTICE '  ✅ idx_user_features_intention';
    ELSE
        RAISE NOTICE '  ❌ idx_user_features_intention missing';
    END IF;
    
    -- user_interactions 索引
    IF EXISTS (SELECT FROM pg_indexes WHERE tablename = 'user_interactions' AND indexname = 'idx_interactions_user_type') THEN
        RAISE NOTICE '  ✅ idx_interactions_user_type';
    ELSE
        RAISE NOTICE '  ❌ idx_interactions_user_type missing';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Checking functions...';
    
    IF EXISTS (SELECT FROM pg_proc WHERE proname = 'extract_skills_from_development') THEN
        RAISE NOTICE '  ✅ extract_skills_from_development';
    ELSE
        RAISE NOTICE '  ❌ extract_skills_from_development missing';
    END IF;
    
    IF EXISTS (SELECT FROM pg_proc WHERE proname = 'extract_functions_from_direction') THEN
        RAISE NOTICE '  ✅ extract_functions_from_direction';
    ELSE
        RAISE NOTICE '  ❌ extract_functions_from_direction missing';
    END IF;
    
    IF EXISTS (SELECT FROM pg_proc WHERE proname = 'calculate_profile_completion') THEN
        RAISE NOTICE '  ✅ calculate_profile_completion';
    ELSE
        RAISE NOTICE '  ❌ calculate_profile_completion missing';
    END IF;
    
    IF EXISTS (SELECT FROM pg_proc WHERE proname = 'sync_user_features') THEN
        RAISE NOTICE '  ✅ sync_user_features';
    ELSE
        RAISE NOTICE '  ❌ sync_user_features missing';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Checking triggers...';
    
    IF EXISTS (SELECT FROM pg_trigger WHERE tgname = 'trigger_sync_user_features') THEN
        RAISE NOTICE '  ✅ trigger_sync_user_features';
    ELSE
        RAISE NOTICE '  ❌ trigger_sync_user_features missing';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Data statistics:';
    
    SELECT COUNT(*) INTO user_features_count FROM user_features;
    SELECT COUNT(*) INTO user_interactions_count FROM user_interactions;
    SELECT COUNT(*) INTO recommendation_cache_count FROM recommendation_cache;
    SELECT COUNT(*) INTO profiles_count FROM profiles;
    
    RAISE NOTICE '  Total profiles: %', profiles_count;
    RAISE NOTICE '  User features synced: %', user_features_count;
    RAISE NOTICE '  User interactions: %', user_interactions_count;
    RAISE NOTICE '  Cached recommendations: %', recommendation_cache_count;
    
    -- 检查同步率
    IF user_features_count > 0 THEN
        RAISE NOTICE '  Sync rate: %', ROUND((user_features_count::FLOAT / NULLIF(profiles_count, 0)::FLOAT * 100)::NUMERIC, 1) || '%';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Verification complete';
    RAISE NOTICE '========================================';
END $$;

-- ============================================================
-- 可选：测试数据同步
-- ============================================================
-- 如果需要详细测试，取消下面的注释
/*
DO $$
DECLARE
    test_user_id UUID;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Testing Sync Mechanism ===';
    
    SELECT user_id INTO test_user_id FROM profiles LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE 'No profiles found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Testing with user_id: %', test_user_id;
    
    IF EXISTS (SELECT FROM user_features WHERE user_id = test_user_id) THEN
        RAISE NOTICE '✅ User features exist for test user';
    ELSE
        RAISE NOTICE '❌ No user features found for test user';
    END IF;
    
    UPDATE profiles SET updated_at = NOW() WHERE user_id = test_user_id;
    RAISE NOTICE 'Sync triggered';
END $$;
*/
