-- =====================================================
-- Home 板块数据库依赖关系检查脚本
-- 在删除 Home 板块前，先检查依赖关系
-- =====================================================

-- 1. 检查所有表的存在性
SELECT 
    'Table Existence Check' as check_type,
    table_name,
    CASE 
        WHEN table_name IN ('posts', 'anonymous_posts', 'likes', 'saves', 'matches') 
        THEN 'Home 板块相关表'
        WHEN table_name IN ('coffee_chats', 'messages') 
        THEN 'Chat 板块相关表'
        WHEN table_name IN ('users', 'profiles') 
        THEN '核心用户表'
        ELSE '其他表'
    END as table_category
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_category, table_name;

-- 2. 检查外键依赖关系
SELECT 
    'Foreign Key Dependencies' as check_type,
    tc.table_name as referencing_table,
    kcu.column_name as referencing_column,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column,
    CASE 
        WHEN ccu.table_name IN ('posts', 'anonymous_posts', 'likes', 'saves') 
        THEN '⚠️ 依赖 Home 板块表'
        WHEN ccu.table_name IN ('matches', 'coffee_chats', 'messages') 
        THEN '✅ 依赖其他功能表'
        ELSE 'ℹ️ 其他依赖'
    END as dependency_type
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY dependency_type, tc.table_name;

-- 3. 检查各表的数据量
SELECT 
    'Data Volume Check' as check_type,
    'posts' as table_name, 
    COALESCE(COUNT(*), 0) as row_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '⚠️ 有数据，删除前请备份'
        ELSE '✅ 无数据，可安全删除'
    END as deletion_safety
FROM posts
UNION ALL
SELECT 
    'Data Volume Check',
    'anonymous_posts', 
    COALESCE(COUNT(*), 0),
    CASE 
        WHEN COUNT(*) > 0 THEN '⚠️ 有数据，删除前请备份'
        ELSE '✅ 无数据，可安全删除'
    END
FROM anonymous_posts
UNION ALL
SELECT 
    'Data Volume Check',
    'likes', 
    COALESCE(COUNT(*), 0),
    CASE 
        WHEN COUNT(*) > 0 THEN '⚠️ 有数据，删除前请备份'
        ELSE '✅ 无数据，可安全删除'
    END
FROM likes
UNION ALL
SELECT 
    'Data Volume Check',
    'saves', 
    COALESCE(COUNT(*), 0),
    CASE 
        WHEN COUNT(*) > 0 THEN '⚠️ 有数据，删除前请备份'
        ELSE '✅ 无数据，可安全删除'
    END
FROM saves
UNION ALL
SELECT 
    'Data Volume Check',
    'matches', 
    COALESCE(COUNT(*), 0),
    CASE 
        WHEN COUNT(*) > 0 THEN '⚠️ 有数据，可能被其他功能使用'
        ELSE '✅ 无数据'
    END
FROM matches;

-- 4. 检查 RLS 策略
SELECT 
    'RLS Policies Check' as check_type,
    tablename,
    policyname,
    CASE 
        WHEN tablename IN ('posts', 'anonymous_posts', 'likes', 'saves') 
        THEN 'Home 板块表策略'
        ELSE '其他表策略'
    END as policy_category
FROM pg_policies
WHERE tablename IN ('posts', 'anonymous_posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages')
ORDER BY policy_category, tablename;

-- 5. 检查索引
SELECT 
    'Index Check' as check_type,
    tablename,
    indexname,
    CASE 
        WHEN tablename IN ('posts', 'anonymous_posts', 'likes', 'saves') 
        THEN 'Home 板块表索引'
        ELSE '其他表索引'
    END as index_category
FROM pg_indexes
WHERE tablename IN ('posts', 'anonymous_posts', 'likes', 'saves', 'matches', 'coffee_chats', 'messages')
ORDER BY index_category, tablename;

-- 6. 最终建议
SELECT 
    'Final Recommendation' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM posts) OR EXISTS (SELECT 1 FROM anonymous_posts) OR EXISTS (SELECT 1 FROM likes) OR EXISTS (SELECT 1 FROM saves)
        THEN '⚠️ 建议：先备份数据，然后执行删除脚本'
        ELSE '✅ 可以安全执行删除脚本'
    END as recommendation;
