-- Verify first_like_today column exists and test data
-- Run this script to diagnose the issue

-- 1. Check if column exists
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name = 'first_like_today';

-- 2. Check current values (show 5 users)
SELECT id, email, name, first_like_today, likes_remaining, created_at
FROM users
ORDER BY created_at DESC
LIMIT 5;

-- 3. Test update on a specific user (replace 'USER_ID_HERE' with actual user ID)
-- UPDATE users 
-- SET first_like_today = CURRENT_DATE 
-- WHERE id = 'USER_ID_HERE';
-- SELECT id, name, first_like_today FROM users WHERE id = 'USER_ID_HERE';

-- 4. Check RLS policies that might block updates
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'users'
AND cmd IN ('UPDATE', 'ALL');

-- 5. Grant permissions if needed (uncomment if column exists but can't update)
-- ALTER TABLE users ALTER COLUMN first_like_today SET DEFAULT NULL;
-- GRANT UPDATE (first_like_today) ON users TO authenticated;
-- GRANT UPDATE (first_like_today) ON users TO anon;

