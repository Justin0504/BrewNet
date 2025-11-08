-- Add boost and superboost columns to users table
-- This allows tracking of boost counts for each user

-- Add superboost_count column (默认为0)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS superboost_count INTEGER DEFAULT 0;

-- Add boost_count column (默认为0)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS boost_count INTEGER DEFAULT 0;

-- Add active_boost_expiry column to track when current boost expires
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS active_boost_expiry TIMESTAMPTZ;

-- Add active_superboost_expiry column to track when current superboost expires
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS active_superboost_expiry TIMESTAMPTZ;

-- Add boost_last_used column to track when boost was last used
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS boost_last_used TIMESTAMPTZ;

-- Add superboost_last_used column to track when superboost was last used
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS superboost_last_used TIMESTAMPTZ;

-- Add comment for documentation
COMMENT ON COLUMN users.superboost_count IS 'Number of superboosts available to the user';
COMMENT ON COLUMN users.boost_count IS 'Number of regular boosts available to the user';
COMMENT ON COLUMN users.active_boost_expiry IS 'Timestamp when the current active boost expires';
COMMENT ON COLUMN users.active_superboost_expiry IS 'Timestamp when the current active superboost expires';
COMMENT ON COLUMN users.boost_last_used IS 'Timestamp when boost was last activated';
COMMENT ON COLUMN users.superboost_last_used IS 'Timestamp when superboost was last activated';

-- Create index for efficient querying of active boosts
CREATE INDEX IF NOT EXISTS idx_users_active_boost_expiry 
ON users(active_boost_expiry) 
WHERE active_boost_expiry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_active_superboost_expiry 
ON users(active_superboost_expiry) 
WHERE active_superboost_expiry IS NOT NULL;

