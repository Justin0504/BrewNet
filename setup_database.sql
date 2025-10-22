-- BrewNet 数据库表创建脚本
-- 请在 Supabase SQL Editor 中执行以下代码

-- 创建用户表
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建帖子表
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

-- 创建点赞表
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    post_id UUID NOT NULL REFERENCES posts(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- 创建保存表
CREATE TABLE IF NOT EXISTS saves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    post_id UUID NOT NULL REFERENCES posts(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- 创建匹配表
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    matched_user_id TEXT NOT NULL,
    matched_user_name TEXT NOT NULL,
    match_type TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建咖啡聊天表
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

-- 创建消息表
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id),
    receiver_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    message_type TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建匿名帖子表
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

-- 启用 Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE coffee_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE anonymous_posts ENABLE ROW LEVEL SECURITY;

-- 创建基本策略（允许所有操作，可根据需要调整）
CREATE POLICY "Enable all operations for authenticated users" ON users FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for authenticated users" ON posts FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for authenticated users" ON likes FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for authenticated users" ON saves FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for authenticated users" ON matches FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for authenticated users" ON coffee_chats FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for authenticated users" ON messages FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for authenticated users" ON anonymous_posts FOR ALL USING (auth.role() = 'authenticated');

-- 允许匿名访问（用于测试）
CREATE POLICY "Enable all operations for anonymous users" ON anonymous_posts FOR ALL USING (true);

-- 插入一些测试数据
INSERT INTO posts (id, title, content, question, tag, tag_color, background_color, author_id, author_name) VALUES
('1', 'After leading people in big companies, I found that this kind of ''junior'' is destined not to be promoted', '', 'What kind of talent can be promoted in big companies?', 'Experience Sharing', 'green', 'white', gen_random_uuid(), 'BrewNet Team'),
('2', '◆◆ Standard Process ◆◆', '1. Thank him for his time\n2. Introduce yourself\n3. Then the other party will usually take the lead to introduce their experience\n4. Thank him for his introduction', 'How to do a coffee chat?', 'Experience Sharing', 'green', 'white', gen_random_uuid(), 'BrewNet Team'),
('3', 'First wave of employees replaced by AI recount personal experience of mass layoffs', '"Always be prepared to leave your employer, because they are prepared to leave you." Brothers, this is it. I was just informed by my boss and HR that my entire career has been replaced by AI.', 'AIGC layoff wave?', 'Trend Direction', 'blue', 'white', gen_random_uuid(), 'BrewNet Team');

INSERT INTO anonymous_posts (id, title, content, question, tag, tag_color) VALUES
(gen_random_uuid(), 'My manager is toxic but I need this job', 'I''ve been dealing with a really difficult manager for 6 months. They constantly criticize my work in front of others and take credit for my ideas. I need this job for financial reasons but it''s affecting my mental health.', 'How do you deal with toxic managers?', 'Workplace', 'red'),
(gen_random_uuid(), 'Should I quit my stable job to start a business?', 'I have a good salary and benefits, but I''m not passionate about my work. I have a business idea that I''m excited about, but I''m scared of the financial risk.', 'What would you do in my situation?', 'Career', 'blue');

-- 显示创建结果
SELECT 'Database tables created successfully!' as status;
