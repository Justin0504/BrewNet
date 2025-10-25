-- =====================================================
-- BrewNet Supabase 数据库配置 SQL
-- 用于支持完整的用户Profile系统
-- =====================================================

-- 1. 创建 users 表（如果不存在）
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    phone_number TEXT,
    is_guest BOOLEAN DEFAULT FALSE,
    profile_image TEXT,
    bio TEXT,
    company TEXT,
    job_title TEXT,
    location TEXT,
    skills TEXT,
    interests TEXT,
    profile_setup_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 创建 profiles 表（核心Profile数据）
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    core_identity JSONB NOT NULL,
    professional_background JSONB NOT NULL,
    networking_intent JSONB NOT NULL,
    personality_social JSONB NOT NULL,
    privacy_trust JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 3. 创建 posts 表（用户发布的帖子）
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT,
    question TEXT,
    tag TEXT NOT NULL,
    tag_color TEXT NOT NULL,
    background_color TEXT NOT NULL,
    author_id UUID NOT NULL REFERENCES users(id),
    author_name TEXT NOT NULL,
    like_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. 创建 likes 表（帖子点赞）
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    post_id UUID NOT NULL REFERENCES posts(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- 5. 创建 saves 表（帖子收藏）
CREATE TABLE IF NOT EXISTS saves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    post_id UUID NOT NULL REFERENCES posts(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- 6. 创建 matches 表（用户匹配）
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    matched_user_id TEXT NOT NULL,
    matched_user_name TEXT NOT NULL,
    match_type TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. 创建 coffee_chats 表（咖啡聊天安排）
CREATE TABLE IF NOT EXISTS coffee_chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    title TEXT NOT NULL,
    participant_id TEXT NOT NULL,
    participant_name TEXT NOT NULL,
    scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
    location TEXT NOT NULL,
    status TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. 创建 messages 表（消息系统）
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id),
    receiver_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    message_type TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. 创建 anonymous_posts 表（匿名帖子）
CREATE TABLE IF NOT EXISTS anonymous_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT,
    question TEXT,
    tag TEXT NOT NULL,
    tag_color TEXT NOT NULL,
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 创建索引以提高查询性能
-- =====================================================

-- users 表索引
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_profile_setup ON users(profile_setup_completed);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- profiles 表索引
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);

-- posts 表索引
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_tag ON posts(tag);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at);
CREATE INDEX IF NOT EXISTS idx_posts_like_count ON posts(like_count);

-- likes 表索引
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);

-- saves 表索引
CREATE INDEX IF NOT EXISTS idx_saves_user_id ON saves(user_id);
CREATE INDEX IF NOT EXISTS idx_saves_post_id ON saves(post_id);

-- matches 表索引
CREATE INDEX IF NOT EXISTS idx_matches_user_id ON matches(user_id);
CREATE INDEX IF NOT EXISTS idx_matches_matched_user_id ON matches(matched_user_id);
CREATE INDEX IF NOT EXISTS idx_matches_is_active ON matches(is_active);

-- coffee_chats 表索引
CREATE INDEX IF NOT EXISTS idx_coffee_chats_user_id ON coffee_chats(user_id);
CREATE INDEX IF NOT EXISTS idx_coffee_chats_scheduled_date ON coffee_chats(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_coffee_chats_status ON coffee_chats(status);

-- messages 表索引
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp);
CREATE INDEX IF NOT EXISTS idx_messages_is_read ON messages(is_read);

-- anonymous_posts 表索引
CREATE INDEX IF NOT EXISTS idx_anonymous_posts_tag ON anonymous_posts(tag);
CREATE INDEX IF NOT EXISTS idx_anonymous_posts_created_at ON anonymous_posts(created_at);

-- =====================================================
-- 创建 RLS (Row Level Security) 策略
-- =====================================================

-- 启用 RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE coffee_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE anonymous_posts ENABLE ROW LEVEL SECURITY;

-- users 表策略
CREATE POLICY "Users can view their own data" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own data" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert their own data" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- profiles 表策略
CREATE POLICY "Users can view their own profile" ON profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- posts 表策略
CREATE POLICY "Anyone can view posts" ON posts
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own posts" ON posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update their own posts" ON posts
    FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Users can delete their own posts" ON posts
    FOR DELETE USING (auth.uid() = author_id);

-- likes 表策略
CREATE POLICY "Users can view all likes" ON likes
    FOR SELECT USING (true);

CREATE POLICY "Users can manage their own likes" ON likes
    FOR ALL USING (auth.uid() = user_id);

-- saves 表策略
CREATE POLICY "Users can view their own saves" ON saves
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own saves" ON saves
    FOR ALL USING (auth.uid() = user_id);

-- matches 表策略
CREATE POLICY "Users can view their own matches" ON matches
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own matches" ON matches
    FOR ALL USING (auth.uid() = user_id);

-- coffee_chats 表策略
CREATE POLICY "Users can view their own coffee chats" ON coffee_chats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own coffee chats" ON coffee_chats
    FOR ALL USING (auth.uid() = user_id);

-- messages 表策略
CREATE POLICY "Users can view their own messages" ON messages
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send messages" ON messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their own messages" ON messages
    FOR UPDATE USING (auth.uid() = sender_id);

-- anonymous_posts 表策略
CREATE POLICY "Anyone can view anonymous posts" ON anonymous_posts
    FOR SELECT USING (true);

CREATE POLICY "Anyone can insert anonymous posts" ON anonymous_posts
    FOR INSERT WITH CHECK (true);

-- =====================================================
-- 创建触发器函数
-- =====================================================

-- 创建更新 updated_at 字段的触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为所有表添加 updated_at 触发器
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_anonymous_posts_updated_at BEFORE UPDATE ON anonymous_posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 创建存储过程
-- =====================================================

-- 创建获取用户推荐资料的存储过程
CREATE OR REPLACE FUNCTION get_recommended_profiles(
    current_user_id UUID,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    core_identity JSONB,
    professional_background JSONB,
    networking_intent JSONB,
    personality_social JSONB,
    privacy_trust JSONB,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.user_id,
        p.core_identity,
        p.professional_background,
        p.networking_intent,
        p.personality_social,
        p.privacy_trust,
        p.created_at,
        p.updated_at
    FROM profiles p
    WHERE p.user_id != current_user_id
    ORDER BY p.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建搜索用户的存储过程
CREATE OR REPLACE FUNCTION search_users(
    search_query TEXT,
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    email TEXT,
    company TEXT,
    job_title TEXT,
    location TEXT,
    skills TEXT,
    interests TEXT,
    profile_setup_completed BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.name,
        u.email,
        u.company,
        u.job_title,
        u.location,
        u.skills,
        u.interests,
        u.profile_setup_completed
    FROM users u
    WHERE 
        u.name ILIKE '%' || search_query || '%' OR
        u.company ILIKE '%' || search_query || '%' OR
        u.job_title ILIKE '%' || search_query || '%' OR
        u.skills ILIKE '%' || search_query || '%' OR
        u.interests ILIKE '%' || search_query || '%'
    ORDER BY u.name
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 创建示例数据（可选）
-- =====================================================

-- 插入示例用户（仅用于测试）
-- INSERT INTO users (id, email, name, profile_setup_completed) VALUES
-- ('550e8400-e29b-41d4-a716-446655440000', 'test@example.com', 'Test User', true);

-- =====================================================
-- 完成配置
-- =====================================================

-- 显示配置完成信息
DO $$
BEGIN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'BrewNet Supabase 数据库配置完成！';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE '已创建的表:';
    RAISE NOTICE '- users (用户基础信息)';
    RAISE NOTICE '- profiles (用户详细资料)';
    RAISE NOTICE '- posts (用户帖子)';
    RAISE NOTICE '- likes (点赞记录)';
    RAISE NOTICE '- saves (收藏记录)';
    RAISE NOTICE '- matches (用户匹配)';
    RAISE NOTICE '- coffee_chats (咖啡聊天)';
    RAISE NOTICE '- messages (消息系统)';
    RAISE NOTICE '- anonymous_posts (匿名帖子)';
    RAISE NOTICE '';
    RAISE NOTICE '已配置的功能:';
    RAISE NOTICE '- 行级安全策略 (RLS)';
    RAISE NOTICE '- 性能优化索引';
    RAISE NOTICE '- 自动更新时间戳';
    RAISE NOTICE '- 用户推荐存储过程';
    RAISE NOTICE '- 用户搜索存储过程';
    RAISE NOTICE '';
    RAISE NOTICE '现在可以开始使用 BrewNet 应用了！';
    RAISE NOTICE '=====================================================';
END $$;
