-- =====================================================
-- Home 板块数据库删除脚本
-- 删除 Discovery, Following, Anonymous Zone 相关的所有表
-- ⚠️ 执行前请先运行 home_dependency_check.sql 检查依赖关系
-- ⚠️ 建议先备份数据库！
-- =====================================================

-- 1. 删除 RLS 策略（如果存在）
DROP POLICY IF EXISTS "Users can view all posts" ON posts;
DROP POLICY IF EXISTS "Users can insert their own posts" ON posts;
DROP POLICY IF EXISTS "Users can update their own posts" ON posts;
DROP POLICY IF EXISTS "Users can delete their own posts" ON posts;

DROP POLICY IF EXISTS "Users can view all anonymous posts" ON anonymous_posts;
DROP POLICY IF EXISTS "Users can insert anonymous posts" ON anonymous_posts;
DROP POLICY IF EXISTS "Users can update anonymous posts" ON anonymous_posts;
DROP POLICY IF EXISTS "Users can delete anonymous posts" ON anonymous_posts;

DROP POLICY IF EXISTS "Users can view all likes" ON likes;
DROP POLICY IF EXISTS "Users can insert their own likes" ON likes;
DROP POLICY IF EXISTS "Users can delete their own likes" ON likes;

DROP POLICY IF EXISTS "Users can view all saves" ON saves;
DROP POLICY IF EXISTS "Users can insert their own saves" ON saves;
DROP POLICY IF EXISTS "Users can delete their own saves" ON saves;

-- 2. 删除索引（如果存在）
DROP INDEX IF EXISTS idx_posts_author_id;
DROP INDEX IF EXISTS idx_posts_created_at;
DROP INDEX IF EXISTS idx_posts_tag;
DROP INDEX IF EXISTS idx_likes_user_id;
DROP INDEX IF EXISTS idx_likes_post_id;
DROP INDEX IF EXISTS idx_saves_user_id;
DROP INDEX IF EXISTS idx_saves_post_id;
DROP INDEX IF EXISTS idx_anonymous_posts_created_at;
DROP INDEX IF EXISTS idx_anonymous_posts_tag;

-- 3. 删除外键约束（如果存在）
-- 注意：CASCADE 会自动删除依赖的外键约束
ALTER TABLE IF EXISTS likes DROP CONSTRAINT IF EXISTS fk_likes_user_id;
ALTER TABLE IF EXISTS likes DROP CONSTRAINT IF EXISTS fk_likes_post_id;
ALTER TABLE IF EXISTS saves DROP CONSTRAINT IF EXISTS fk_saves_user_id;
ALTER TABLE IF EXISTS saves DROP CONSTRAINT IF EXISTS fk_saves_post_id;
ALTER TABLE IF EXISTS posts DROP CONSTRAINT IF EXISTS fk_posts_author_id;

-- 4. 删除 Home 板块相关的表
-- 使用 CASCADE 确保删除所有依赖关系
DROP TABLE IF EXISTS likes CASCADE;
DROP TABLE IF EXISTS saves CASCADE;
DROP TABLE IF EXISTS posts CASCADE;
DROP TABLE IF EXISTS anonymous_posts CASCADE;

-- 5. 验证删除结果
SELECT 
    'Deletion Verification' as check_type,
    table_name,
    CASE 
        WHEN table_name IN ('posts', 'anonymous_posts', 'likes', 'saves') 
        THEN '❌ 删除失败 - 表仍然存在'
        ELSE '✅ 表已成功删除或不存在'
    END as deletion_status
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_name IN ('posts', 'anonymous_posts', 'likes', 'saves');

-- 6. 检查保留的表
SELECT 
    'Remaining Tables Check' as check_type,
    table_name,
    CASE 
        WHEN table_name IN ('matches', 'coffee_chats', 'messages') 
        THEN '✅ 保留 - 其他功能需要'
        WHEN table_name IN ('users', 'profiles') 
        THEN '✅ 保留 - 核心用户表'
        ELSE 'ℹ️ 其他表'
    END as table_status
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_status, table_name;

-- 7. 最终确认
SELECT 
    'Final Confirmation' as check_type,
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('posts', 'anonymous_posts', 'likes', 'saves'))
        THEN '✅ Home 板块数据库删除完成 - 所有相关表已删除'
        ELSE '❌ Home 板块数据库删除未完成 - 仍有表存在'
    END as final_status;
