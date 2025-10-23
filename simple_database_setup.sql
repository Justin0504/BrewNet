-- Simple Database Setup Script
-- This script creates tables with basic RLS policies

-- ============================================
-- 1. CREATE USERS TABLE
-- ============================================
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

-- Enable RLS for users
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Simple users policies
DROP POLICY IF EXISTS "Users can do everything" ON users;
CREATE POLICY "Users can do everything" ON users FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 2. CREATE PROFILES TABLE
-- ============================================
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

-- Enable RLS for profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Simple profiles policies
DROP POLICY IF EXISTS "Profiles can do everything" ON profiles;
CREATE POLICY "Profiles can do everything" ON profiles FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 3. CREATE POSTS TABLE
-- ============================================
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

-- Enable RLS for posts
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Simple posts policies
DROP POLICY IF EXISTS "Posts can do everything" ON posts;
CREATE POLICY "Posts can do everything" ON posts FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 4. CREATE LIKES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    post_id UUID NOT NULL REFERENCES posts(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- Enable RLS for likes
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- Simple likes policies
DROP POLICY IF EXISTS "Likes can do everything" ON likes;
CREATE POLICY "Likes can do everything" ON likes FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 5. CREATE SAVES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS saves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    post_id UUID NOT NULL REFERENCES posts(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- Enable RLS for saves
ALTER TABLE saves ENABLE ROW LEVEL SECURITY;

-- Simple saves policies
DROP POLICY IF EXISTS "Saves can do everything" ON saves;
CREATE POLICY "Saves can do everything" ON saves FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 6. CREATE MATCHES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    matched_user_id TEXT NOT NULL,
    matched_user_name TEXT NOT NULL,
    match_type TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for matches
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

-- Simple matches policies
DROP POLICY IF EXISTS "Matches can do everything" ON matches;
CREATE POLICY "Matches can do everything" ON matches FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 7. CREATE COFFEE_CHATS TABLE
-- ============================================
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

-- Enable RLS for coffee_chats
ALTER TABLE coffee_chats ENABLE ROW LEVEL SECURITY;

-- Simple coffee chats policies
DROP POLICY IF EXISTS "Coffee chats can do everything" ON coffee_chats;
CREATE POLICY "Coffee chats can do everything" ON coffee_chats FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 8. CREATE MESSAGES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id),
    receiver_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    message_type TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for messages
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Simple messages policies
DROP POLICY IF EXISTS "Messages can do everything" ON messages;
CREATE POLICY "Messages can do everything" ON messages FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 9. CREATE ANONYMOUS_POSTS TABLE
-- ============================================
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

-- Enable RLS for anonymous_posts
ALTER TABLE anonymous_posts ENABLE ROW LEVEL SECURITY;

-- Simple anonymous posts policies
DROP POLICY IF EXISTS "Anonymous posts can do everything" ON anonymous_posts;
CREATE POLICY "Anonymous posts can do everything" ON anonymous_posts FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 10. CREATE BASIC INDEXES
-- ============================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Profiles indexes
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);

-- Posts indexes
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at);
CREATE INDEX IF NOT EXISTS idx_posts_tag ON posts(tag);

-- Likes indexes
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);

-- Saves indexes
CREATE INDEX IF NOT EXISTS idx_saves_user_id ON saves(user_id);
CREATE INDEX IF NOT EXISTS idx_saves_post_id ON saves(post_id);

-- Matches indexes
CREATE INDEX IF NOT EXISTS idx_matches_user_id ON matches(user_id);
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON matches(created_at);

-- Coffee chats indexes
CREATE INDEX IF NOT EXISTS idx_coffee_chats_user_id ON coffee_chats(user_id);
CREATE INDEX IF NOT EXISTS idx_coffee_chats_scheduled_date ON coffee_chats(scheduled_date);

-- Messages indexes
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp);

-- Anonymous posts indexes
CREATE INDEX IF NOT EXISTS idx_anonymous_posts_created_at ON anonymous_posts(created_at);
CREATE INDEX IF NOT EXISTS idx_anonymous_posts_tag ON anonymous_posts(tag);

-- ============================================
-- 11. CREATE TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
DROP TRIGGER IF EXISTS update_posts_updated_at ON posts;
DROP TRIGGER IF EXISTS update_anonymous_posts_updated_at ON anonymous_posts;

CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at 
    BEFORE UPDATE ON posts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_anonymous_posts_updated_at 
    BEFORE UPDATE ON anonymous_posts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 12. INSERT SAMPLE DATA
-- ============================================

-- Insert sample user
INSERT INTO users (id, email, name, is_guest) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'test@brewnet.com', 'BrewNet Team', false)
ON CONFLICT (email) DO NOTHING;

-- ============================================
-- 13. VERIFICATION
-- ============================================
SELECT '✅ Simple database setup completed successfully!' as status;
