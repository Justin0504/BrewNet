-- ============================================
-- Add first_like_today column to users table
-- ============================================
-- This tracks the date of the user's first like/swipe each day
-- Used to show "Add Message" prompt only on the first like of each day

-- Step 1: Add the column if it doesn't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS first_like_today DATE;

-- Step 2: Add comment to explain the column
COMMENT ON COLUMN users.first_like_today IS 'Date of user''s first like/swipe of the day. Used to trigger "Add Message" prompt only once per day.';

-- Step 3: Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_users_first_like_today 
ON users(first_like_today);

-- Step 4: Ensure RLS policies allow updates to this column
-- Check existing UPDATE policies
DO $$
BEGIN
    -- If you have RLS enabled, ensure authenticated users can update their own first_like_today
    -- This assumes you have a policy allowing users to update their own data
    -- Adjust the policy name and conditions based on your existing setup
    
    -- Example: If you don't have an UPDATE policy, create one
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'users' 
        AND policyname = 'Users can update own data'
    ) THEN
        -- Create a policy that allows users to update their own data
        -- UNCOMMENT AND ADJUST IF NEEDED:
        -- CREATE POLICY "Users can update own data"
        -- ON users FOR UPDATE
        -- TO authenticated
        -- USING (auth.uid() = id)
        -- WITH CHECK (auth.uid() = id);
        
        RAISE NOTICE 'Please ensure you have an UPDATE policy for users table';
    END IF;
END $$;

-- Step 5: Verification queries
-- Check if column exists and its properties
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name = 'first_like_today';

-- Check current values (show sample)
SELECT 
    id, 
    name, 
    first_like_today, 
    likes_remaining,
    created_at
FROM users
ORDER BY created_at DESC
LIMIT 5;

-- Check RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'users'
AND cmd IN ('UPDATE', 'ALL')
ORDER BY policyname;

-- ============================================
-- Manual Testing (OPTIONAL)
-- ============================================
-- Uncomment to test update on a specific user:
-- 
-- UPDATE users 
-- SET first_like_today = CURRENT_DATE 
-- WHERE id = 'YOUR_USER_ID_HERE';
-- 
-- SELECT id, name, first_like_today 
-- FROM users 
-- WHERE id = 'YOUR_USER_ID_HERE';

