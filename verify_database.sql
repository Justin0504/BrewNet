-- BrewNet Database Verification Script
-- Run this to check if your database is properly set up

-- ============================================
-- 1. CHECK ALL TABLES EXIST
-- ============================================
SELECT 
    'Tables Check' as category,
    table_name,
    CASE 
        WHEN table_name IN ('users', 'profiles', 'posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages', 'anonymous_posts') 
        THEN '✅ EXISTS' 
        ELSE '❌ MISSING' 
    END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('users', 'profiles', 'posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages', 'anonymous_posts')
ORDER BY table_name;

-- ============================================
-- 2. CHECK ROW LEVEL SECURITY
-- ============================================
SELECT 
    'RLS Check' as category,
    tablename,
    CASE 
        WHEN rowsecurity THEN '✅ ENABLED' 
        ELSE '❌ DISABLED' 
    END as rls_status
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'profiles', 'posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages', 'anonymous_posts')
ORDER BY tablename;

-- ============================================
-- 3. CHECK POLICIES
-- ============================================
SELECT 
    'Policies Check' as category,
    tablename,
    COUNT(*) as policy_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ HAS POLICIES' 
        ELSE '❌ NO POLICIES' 
    END as status
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'profiles', 'posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages', 'anonymous_posts')
GROUP BY tablename
ORDER BY tablename;

-- ============================================
-- 4. CHECK INDEXES
-- ============================================
SELECT 
    'Indexes Check' as category,
    tablename,
    COUNT(*) as index_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ HAS INDEXES' 
        ELSE '❌ NO INDEXES' 
    END as status
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'profiles', 'posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages', 'anonymous_posts')
GROUP BY tablename
ORDER BY tablename;

-- ============================================
-- 5. CHECK TRIGGERS
-- ============================================
SELECT 
    'Triggers Check' as category,
    event_object_table as table_name,
    COUNT(*) as trigger_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ HAS TRIGGERS' 
        ELSE '❌ NO TRIGGERS' 
    END as status
FROM information_schema.triggers 
WHERE event_object_schema = 'public' 
AND event_object_table IN ('users', 'profiles', 'posts', 'anonymous_posts')
GROUP BY event_object_table
ORDER BY event_object_table;

-- ============================================
-- 6. CHECK SAMPLE DATA
-- ============================================
SELECT 
    'Sample Data Check' as category,
    'users' as table_name,
    COUNT(*) as record_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ HAS DATA' 
        ELSE '❌ NO DATA' 
    END as status
FROM users
UNION ALL
SELECT 
    'Sample Data Check' as category,
    'profiles' as table_name,
    COUNT(*) as record_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ HAS DATA' 
        ELSE '❌ NO DATA' 
    END as status
FROM profiles;

-- ============================================
-- 7. TEST PROFILE QUERY
-- ============================================
SELECT 
    'Profile Test' as category,
    'Profile Query Test' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM profiles 
            WHERE core_identity->>'name' IS NOT NULL 
            AND core_identity->>'email' IS NOT NULL
        ) THEN '✅ PROFILES WORKING' 
        ELSE '❌ PROFILES NOT WORKING' 
    END as status;

-- ============================================
-- 8. SUMMARY
-- ============================================
SELECT 
    '🎯 SUMMARY' as category,
    'Database Status' as item,
    CASE 
        WHEN (
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('users', 'profiles', 'posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages', 'anonymous_posts')
        ) = 9 
        THEN '✅ ALL TABLES EXIST' 
        ELSE '❌ MISSING TABLES' 
    END as status;
