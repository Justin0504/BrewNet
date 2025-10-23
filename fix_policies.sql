-- Fix Policy Conflicts Script
-- Run this if you get "policy already exists" errors

-- ============================================
-- DROP ALL EXISTING POLICIES
-- ============================================

-- Users policies
DROP POLICY IF EXISTS "Enable all operations for authenticated users" ON users;
DROP POLICY IF EXISTS "Enable all operations for anonymous users" ON users;

-- Profiles policies
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON profiles;

-- Posts policies
DROP POLICY IF EXISTS "Anyone can view posts" ON posts;
DROP POLICY IF EXISTS "Authenticated users can insert posts" ON posts;
DROP POLICY IF EXISTS "Users can update their own posts" ON posts;
DROP POLICY IF EXISTS "Users can delete their own posts" ON posts;

-- Likes policies
DROP POLICY IF EXISTS "Users can view all likes" ON likes;
DROP POLICY IF EXISTS "Users can insert their own likes" ON likes;
DROP POLICY IF EXISTS "Users can delete their own likes" ON likes;

-- Saves policies
DROP POLICY IF EXISTS "Users can view their own saves" ON saves;
DROP POLICY IF EXISTS "Users can insert their own saves" ON saves;
DROP POLICY IF EXISTS "Users can delete their own saves" ON saves;

-- Matches policies
DROP POLICY IF EXISTS "Users can view their own matches" ON matches;
DROP POLICY IF EXISTS "Users can insert their own matches" ON matches;
DROP POLICY IF EXISTS "Users can update their own matches" ON matches;
DROP POLICY IF EXISTS "Users can delete their own matches" ON matches;

-- Coffee chats policies
DROP POLICY IF EXISTS "Users can view their own coffee chats" ON coffee_chats;
DROP POLICY IF EXISTS "Users can insert their own coffee chats" ON coffee_chats;
DROP POLICY IF EXISTS "Users can update their own coffee chats" ON coffee_chats;
DROP POLICY IF EXISTS "Users can delete their own coffee chats" ON coffee_chats;

-- Messages policies
DROP POLICY IF EXISTS "Users can view messages they sent or received" ON messages;
DROP POLICY IF EXISTS "Users can insert messages" ON messages;
DROP POLICY IF EXISTS "Users can update messages they sent" ON messages;
DROP POLICY IF EXISTS "Users can delete messages they sent" ON messages;

-- Anonymous posts policies
DROP POLICY IF EXISTS "Anyone can view anonymous posts" ON anonymous_posts;
DROP POLICY IF EXISTS "Anyone can insert anonymous posts" ON anonymous_posts;
DROP POLICY IF EXISTS "Anyone can update anonymous posts" ON anonymous_posts;
DROP POLICY IF EXISTS "Anyone can delete anonymous posts" ON anonymous_posts;

-- ============================================
-- RECREATE ALL POLICIES
-- ============================================

-- Users policies
CREATE POLICY "Enable all operations for authenticated users" ON users 
    FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all operations for anonymous users" ON users 
    FOR ALL USING (true);

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON profiles 
    FOR SELECT USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can insert their own profile" ON profiles 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can update their own profile" ON profiles 
    FOR UPDATE USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own profile" ON profiles 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- Posts policies
CREATE POLICY "Anyone can view posts" ON posts FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert posts" ON posts 
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can update their own posts" ON posts 
    FOR UPDATE USING (auth.uid()::text = author_id::text);
CREATE POLICY "Users can delete their own posts" ON posts 
    FOR DELETE USING (auth.uid()::text = author_id::text);

-- Likes policies
CREATE POLICY "Users can view all likes" ON likes FOR SELECT USING (true);
CREATE POLICY "Users can insert their own likes" ON likes 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own likes" ON likes 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- Saves policies
CREATE POLICY "Users can view their own saves" ON saves 
    FOR SELECT USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can insert their own saves" ON saves 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own saves" ON saves 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- Matches policies
CREATE POLICY "Users can view their own matches" ON matches 
    FOR SELECT USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can insert their own matches" ON matches 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can update their own matches" ON matches 
    FOR UPDATE USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own matches" ON matches 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- Coffee chats policies
CREATE POLICY "Users can view their own coffee chats" ON coffee_chats 
    FOR SELECT USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can insert their own coffee chats" ON coffee_chats 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Users can update their own coffee chats" ON coffee_chats 
    FOR UPDATE USING (auth.uid()::text = user_id::text);
CREATE POLICY "Users can delete their own coffee chats" ON coffee_chats 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- Messages policies
CREATE POLICY "Users can view messages they sent or received" ON messages 
    FOR SELECT USING (auth.uid()::text = sender_id::text OR auth.uid()::text = receiver_id::text);
CREATE POLICY "Users can insert messages" ON messages 
    FOR INSERT WITH CHECK (auth.uid()::text = sender_id::text);
CREATE POLICY "Users can update messages they sent" ON messages 
    FOR UPDATE USING (auth.uid()::text = sender_id::text);
CREATE POLICY "Users can delete messages they sent" ON messages 
    FOR DELETE USING (auth.uid()::text = sender_id::text);

-- Anonymous posts policies
CREATE POLICY "Anyone can view anonymous posts" ON anonymous_posts FOR SELECT USING (true);
CREATE POLICY "Anyone can insert anonymous posts" ON anonymous_posts FOR INSERT USING (true);
CREATE POLICY "Anyone can update anonymous posts" ON anonymous_posts FOR UPDATE USING (true);
CREATE POLICY "Anyone can delete anonymous posts" ON anonymous_posts FOR DELETE USING (true);

-- ============================================
-- VERIFICATION
-- ============================================
SELECT '✅ All policies have been recreated successfully!' as status;
