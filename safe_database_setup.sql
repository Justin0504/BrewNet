-- Safe Database Setup Script
-- This script creates tables in the correct order to avoid dependency issues

-- ============================================
-- 1. CREATE USERS TABLE (Base table)
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

-- Users policies
DROP POLICY IF EXISTS "Enable all operations for authenticated users" ON users;
DROP POLICY IF EXISTS "Enable all operations for anonymous users" ON users;
CREATE POLICY "Enable all operations for authenticated users" ON users 
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for anonymous users" ON users 
    FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 2. CREATE PROFILES TABLE (Depends on users)
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

-- Profiles policies
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON profiles;
CREATE POLICY "Users can view their own profile" ON profiles 
    FOR SELECT USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can insert their own profile" ON profiles 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can update their own profile" ON profiles 
    FOR UPDATE USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own profile" ON profiles 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- ============================================
-- 3. CREATE POSTS TABLE (Depends on users)
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

-- Posts policies
DROP POLICY IF EXISTS "Anyone can view posts" ON posts;
DROP POLICY IF EXISTS "Authenticated users can insert posts" ON posts;
DROP POLICY IF EXISTS "Users can update their own posts" ON posts;
DROP POLICY IF EXISTS "Users can delete their own posts" ON posts;
CREATE POLICY "Anyone can view posts" ON posts FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert posts" ON posts 
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can update their own posts" ON posts 
    FOR UPDATE USING (auth.uid()::text = author_id::text) WITH CHECK (auth.uid()::text = author_id::text);
CREATE POLICY "Users can delete their own posts" ON posts 
    FOR DELETE USING (auth.uid()::text = author_id::text);

-- ============================================
-- 4. CREATE LIKES TABLE (Depends on users and posts)
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

-- Likes policies
DROP POLICY IF EXISTS "Users can view all likes" ON likes;
DROP POLICY IF EXISTS "Users can insert their own likes" ON likes;
DROP POLICY IF EXISTS "Users can delete their own likes" ON likes;
CREATE POLICY "Users can view all likes" ON likes FOR SELECT USING (true);
CREATE POLICY "Users can insert their own likes" ON likes 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own likes" ON likes 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- ============================================
-- 5. CREATE SAVES TABLE (Depends on users and posts)
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

-- Saves policies
DROP POLICY IF EXISTS "Users can view their own saves" ON saves;
DROP POLICY IF EXISTS "Users can insert their own saves" ON saves;
DROP POLICY IF EXISTS "Users can delete their own saves" ON saves;
CREATE POLICY "Users can view their own saves" ON saves 
    FOR SELECT USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can insert their own saves" ON saves 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own saves" ON saves 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- ============================================
-- 6. CREATE MATCHES TABLE (Depends on users)
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

-- Matches policies
DROP POLICY IF EXISTS "Users can view their own matches" ON matches;
DROP POLICY IF EXISTS "Users can insert their own matches" ON matches;
DROP POLICY IF EXISTS "Users can update their own matches" ON matches;
DROP POLICY IF EXISTS "Users can delete their own matches" ON matches;
CREATE POLICY "Users can view their own matches" ON matches 
    FOR SELECT USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can insert their own matches" ON matches 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can update their own matches" ON matches 
    FOR UPDATE USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own matches" ON matches 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- ============================================
-- 7. CREATE COFFEE_CHATS TABLE (Depends on users)
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

-- Coffee chats policies
DROP POLICY IF EXISTS "Users can view their own coffee chats" ON coffee_chats;
DROP POLICY IF EXISTS "Users can insert their own coffee chats" ON coffee_chats;
DROP POLICY IF EXISTS "Users can update their own coffee chats" ON coffee_chats;
DROP POLICY IF EXISTS "Users can delete their own coffee chats" ON coffee_chats;
CREATE POLICY "Users can view their own coffee chats" ON coffee_chats 
    FOR SELECT USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can insert their own coffee chats" ON coffee_chats 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can update their own coffee chats" ON coffee_chats 
    FOR UPDATE USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own coffee chats" ON coffee_chats 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- ============================================
-- 8. CREATE MESSAGES TABLE (Depends on users)
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

-- Messages policies
DROP POLICY IF EXISTS "Users can view messages they sent or received" ON messages;
DROP POLICY IF EXISTS "Users can insert messages" ON messages;
DROP POLICY IF EXISTS "Users can update messages they sent" ON messages;
DROP POLICY IF EXISTS "Users can delete messages they sent" ON messages;
CREATE POLICY "Users can view messages they sent or received" ON messages 
    FOR SELECT USING (auth.uid()::text = sender_id::text OR auth.uid()::text = receiver_id::text);
CREATE POLICY "Users can insert messages" ON messages 
    FOR INSERT WITH CHECK (auth.uid()::text = sender_id::text);
CREATE POLICY "Users can update messages they sent" ON messages 
    FOR UPDATE USING (auth.uid()::text = sender_id::text);
CREATE POLICY "Users can delete messages they sent" ON messages 
    FOR DELETE USING (auth.uid()::text = sender_id::text);

-- ============================================
-- 9. CREATE ANONYMOUS_POSTS TABLE (No dependencies)
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

-- Anonymous posts policies
DROP POLICY IF EXISTS "Anyone can view anonymous posts" ON anonymous_posts;
DROP POLICY IF EXISTS "Anyone can insert anonymous posts" ON anonymous_posts;
DROP POLICY IF EXISTS "Anyone can update anonymous posts" ON anonymous_posts;
DROP POLICY IF EXISTS "Anyone can delete anonymous posts" ON anonymous_posts;
CREATE POLICY "Anyone can view anonymous posts" ON anonymous_posts FOR SELECT USING (true);
CREATE POLICY "Anyone can insert anonymous posts" ON anonymous_posts FOR INSERT USING (true);
CREATE POLICY "Anyone can update anonymous posts" ON anonymous_posts FOR UPDATE USING (true);
CREATE POLICY "Anyone can delete anonymous posts" ON anonymous_posts FOR DELETE USING (true);

-- ============================================
-- 10. CREATE INDEXES
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
SELECT '✅ Safe database setup completed successfully!' as status;
