-- 创建 posts 表的 SQL 脚本
-- 请在 Supabase Dashboard 的 SQL Editor 中执行

CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT,
    question TEXT,
    tag TEXT NOT NULL,
    tag_color TEXT NOT NULL,
    background_color TEXT NOT NULL,
    author_id UUID NOT NULL,
    author_name TEXT NOT NULL,
    like_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 启用 Row Level Security
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- 创建策略（允许所有操作）
CREATE POLICY "Enable all operations for authenticated users" ON posts FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for anonymous users" ON posts FOR ALL USING (true);

-- 插入测试数据
INSERT INTO posts (id, title, content, question, tag, tag_color, background_color, author_id, author_name) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'After leading people in big companies, I found that this kind of ''junior'' is destined not to be promoted', '', 'What kind of talent can be promoted in big companies?', 'Experience Sharing', 'green', 'white', '550e8400-e29b-41d4-a716-446655440000', 'BrewNet Team'),
('550e8400-e29b-41d4-a716-446655440002', '◆◆ Standard Process ◆◆', '1. Thank him for his time\n2. Introduce yourself\n3. Then the other party will usually take the lead to introduce their experience\n4. Thank him for his introduction', 'How to do a coffee chat?', 'Experience Sharing', 'green', 'white', '550e8400-e29b-41d4-a716-446655440000', 'BrewNet Team'),
('550e8400-e29b-41d4-a716-446655440003', 'First wave of employees replaced by AI recount personal experience of mass layoffs', '"Always be prepared to leave your employer, because they are prepared to leave you." Brothers, this is it. I was just informed by my boss and HR that my entire career has been replaced by AI.', 'AIGC layoff wave?', 'Trend Direction', 'blue', 'white', '550e8400-e29b-41d4-a716-446655440000', 'BrewNet Team');

-- 显示创建结果
SELECT 'Posts table created successfully!' as status;
