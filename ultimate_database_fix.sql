-- 终极数据库修复脚本
-- 这个脚本将彻底解决所有数据库架构问题

-- ============================================
-- 1. 检查当前数据库状态
-- ============================================
SELECT '🔍 检查当前数据库状态...' as status;

-- 检查 users 表结构
SELECT 
    'users' as table_name,
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 检查 profiles 表结构
SELECT 
    'profiles' as table_name,
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- ============================================
-- 2. 完全重建 users 表（如果存在）
-- ============================================
SELECT '🔧 重建 users 表...' as status;

-- 删除现有表（如果存在）
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 重新创建 users 表，使用 TEXT 类型（无长度限制）
CREATE TABLE users (
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

-- ============================================
-- 3. 创建 profiles 表
-- ============================================
SELECT '🔧 创建 profiles 表...' as status;

CREATE TABLE profiles (
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

-- ============================================
-- 4. 启用行级安全
-- ============================================
SELECT '🔧 启用行级安全...' as status;

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 5. 创建策略
-- ============================================
SELECT '🔧 创建安全策略...' as status;

-- Users 表策略
CREATE POLICY "Enable all operations for authenticated users" ON users 
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable all operations for anonymous users" ON users 
    FOR ALL USING (true) WITH CHECK (true);

-- Profiles 表策略
CREATE POLICY "Users can view their own profile" ON profiles 
    FOR SELECT USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can insert their own profile" ON profiles 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Users can update their own profile" ON profiles 
    FOR UPDATE USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can delete their own profile" ON profiles 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- ============================================
-- 6. 创建触发器函数
-- ============================================
SELECT '🔧 创建触发器...' as status;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建触发器
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 7. 创建索引
-- ============================================
SELECT '🔧 创建索引...' as status;

-- Users 表索引
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_profile_setup_completed ON users(profile_setup_completed);

-- Profiles 表索引
CREATE INDEX idx_profiles_user_id ON profiles(user_id);
CREATE INDEX idx_profiles_created_at ON profiles(created_at);

-- ============================================
-- 8. 插入测试数据
-- ============================================
SELECT '🔧 插入测试数据...' as status;

-- 插入测试用户
INSERT INTO users (id, email, name, is_guest, profile_setup_completed) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'test@brewnet.com', 'BrewNet Team', false, true);

-- 插入测试资料
INSERT INTO profiles (
    user_id,
    core_identity,
    professional_background,
    networking_intent,
    personality_social,
    privacy_trust
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    '{
        "name": "BrewNet Team",
        "email": "test@brewnet.com",
        "phone_number": null,
        "profile_image": null,
        "bio": "Building the future of professional networking",
        "pronouns": "they/them",
        "location": "San Francisco, CA",
        "personal_website": "https://brewnet.com",
        "github_url": "https://github.com/brewnet",
        "linkedin_url": "https://linkedin.com/company/brewnet",
        "time_zone": "America/Los_Angeles",
        "available_timeslot": {
            "sunday": {"morning": false, "noon": false, "afternoon": true, "evening": true, "night": false},
            "monday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "tuesday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "wednesday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "thursday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "friday": {"morning": true, "noon": true, "afternoon": true, "evening": true, "night": false},
            "saturday": {"morning": false, "noon": false, "afternoon": true, "evening": true, "night": false}
        }
    }',
    '{
        "current_company": "BrewNet",
        "job_title": "Founder & CEO",
        "industry": "Technology",
        "experience_level": "Senior",
        "education": "Computer Science, Stanford University",
        "years_of_experience": 8.0,
        "career_stage": "Founder",
        "skills": ["Swift", "iOS Development", "Product Management", "Leadership"],
        "certifications": ["AWS Certified", "Google Cloud Professional"],
        "languages_spoken": ["English", "Spanish"],
        "work_experiences": [
            {
                "company": "BrewNet",
                "position": "Founder & CEO",
                "start_date": "2020-01-01",
                "end_date": null,
                "description": "Building the future of professional networking"
            }
        ]
    }',
    '{
        "networking_intent": ["Find collaborators", "Share knowledge", "Build professional network"],
        "conversation_topics": ["Technology", "Startups", "Product Development", "Leadership"],
        "collaboration_interest": ["Startup ideas", "Side projects", "Mentoring"],
        "coffee_chat_goal": "Connect with like-minded professionals and explore collaboration opportunities",
        "preferred_chat_format": "Virtual",
        "available_timeslot": {
            "sunday": {"morning": false, "noon": false, "afternoon": true, "evening": true, "night": false},
            "monday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "tuesday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "wednesday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "thursday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "friday": {"morning": true, "noon": true, "afternoon": true, "evening": true, "night": false},
            "saturday": {"morning": false, "noon": false, "afternoon": true, "evening": true, "night": false}
        },
        "preferred_chat_duration": "30-45 minutes",
        "intro_prompt_answers": [
            {
                "prompt": "What''s your biggest professional challenge right now?",
                "answer": "Scaling our team while maintaining our company culture and product quality."
            },
            {
                "prompt": "What are you most excited about in your field?",
                "answer": "The potential for AI to revolutionize how professionals connect and collaborate."
            }
        ]
    }',
    '{
        "icebreaker_prompts": [
            {
                "prompt": "What''s the best piece of advice you''ve received?",
                "answer": "Always hire people who are smarter than you and give them the space to excel."
            },
            {
                "prompt": "What''s something you''re passionate about outside of work?",
                "answer": "I love hiking and photography - it helps me think clearly and stay creative."
            }
        ],
        "values_tags": ["Innovation", "Collaboration", "Transparency", "Growth"],
        "hobbies": ["Hiking", "Photography", "Reading", "Cooking"],
        "preferred_meeting_vibe": "Goal-driven",
        "communication_style": "Direct"
    }',
    '{
        "visibility_settings": {
            "company": "public",
            "email": "private",
            "phone_number": "private",
            "location": "public",
            "skills": "public",
            "interests": "public"
        },
        "verified_status": "verified_professional",
        "data_sharing_consent": true,
        "report_preferences": {
            "allow_reports": true,
            "report_categories": ["Inappropriate content", "Spam", "Harassment"]
        }
    }'
);

-- ============================================
-- 9. 验证修复结果
-- ============================================
SELECT '✅ 验证修复结果...' as status;

-- 检查最终表结构
SELECT 
    'users' as table_name,
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 
    'profiles' as table_name,
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 检查数据是否正确插入
SELECT COUNT(*) as user_count FROM users;
SELECT COUNT(*) as profile_count FROM profiles;

SELECT '🎉 数据库修复完成！现在可以正常保存用户资料了。' as result;
