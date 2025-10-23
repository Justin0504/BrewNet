-- Fix Users Table - Add Missing Columns
-- Execute this in Supabase Dashboard SQL Editor

-- ============================================
-- 1. CHECK CURRENT USERS TABLE STRUCTURE
-- ============================================
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- ============================================
-- 2. ADD MISSING COLUMNS IF THEY DON'T EXIST
-- ============================================

-- Add profile_setup_completed column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'profile_setup_completed'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE users ADD COLUMN profile_setup_completed BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added profile_setup_completed column to users table';
    ELSE
        RAISE NOTICE 'profile_setup_completed column already exists';
    END IF;
END $$;

-- Add other missing columns if needed
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'phone_number'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE users ADD COLUMN phone_number TEXT;
        RAISE NOTICE 'Added phone_number column to users table';
    ELSE
        RAISE NOTICE 'phone_number column already exists';
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'profile_image'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE users ADD COLUMN profile_image TEXT;
        RAISE NOTICE 'Added profile_image column to users table';
    ELSE
        RAISE NOTICE 'profile_image column already exists';
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'bio'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE users ADD COLUMN bio TEXT;
        RAISE NOTICE 'Added bio column to users table';
    ELSE
        RAISE NOTICE 'bio column already exists';
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'company'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE users ADD COLUMN company TEXT;
        RAISE NOTICE 'Added company column to users table';
    ELSE
        RAISE NOTICE 'company column already exists';
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'job_title'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE users ADD COLUMN job_title TEXT;
        RAISE NOTICE 'Added job_title column to users table';
    ELSE
        RAISE NOTICE 'job_title column already exists';
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'location'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE users ADD COLUMN location TEXT;
        RAISE NOTICE 'Added location column to users table';
    ELSE
        RAISE NOTICE 'location column already exists';
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'skills'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE users ADD COLUMN skills TEXT;
        RAISE NOTICE 'Added skills column to users table';
    ELSE
        RAISE NOTICE 'skills column already exists';
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'interests'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE users ADD COLUMN interests TEXT;
        RAISE NOTICE 'Added interests column to users table';
    ELSE
        RAISE NOTICE 'interests column already exists';
    END IF;
END $$;

-- ============================================
-- 3. VERIFY FINAL STRUCTURE
-- ============================================
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- ============================================
-- 4. TEST UPDATE OPERATION
-- ============================================
-- Test updating profile_setup_completed for existing user
UPDATE users 
SET profile_setup_completed = true 
WHERE id = '550e8400-e29b-41d4-a716-446655440000';

-- Verify the update
SELECT id, name, profile_setup_completed 
FROM users 
WHERE id = '550e8400-e29b-41d4-a716-446655440000';

SELECT '✅ Users table fixed successfully!' as status;
