-- Add BrewNet Pro subscription fields to users table
-- This script adds columns to track Pro subscription status and like limits

-- Add Pro subscription tracking columns
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_pro BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS pro_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS pro_end TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS likes_remaining INTEGER DEFAULT 6,
ADD COLUMN IF NOT EXISTS likes_depleted_at TIMESTAMP WITH TIME ZONE;

-- Create index for efficient Pro user queries
CREATE INDEX IF NOT EXISTS idx_users_is_pro ON users(is_pro);
CREATE INDEX IF NOT EXISTS idx_users_pro_end ON users(pro_end);

-- Create a function to check and reset likes if 24h have passed
CREATE OR REPLACE FUNCTION reset_likes_if_expired()
RETURNS TRIGGER AS $$
BEGIN
    -- If user is not Pro and likes are depleted, check if 24h have passed
    IF NEW.is_pro = FALSE AND 
       NEW.likes_depleted_at IS NOT NULL AND 
       (CURRENT_TIMESTAMP - NEW.likes_depleted_at) >= INTERVAL '24 hours' THEN
        NEW.likes_remaining := 6;
        NEW.likes_depleted_at := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-reset likes
DROP TRIGGER IF EXISTS trigger_reset_likes ON users;
CREATE TRIGGER trigger_reset_likes
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION reset_likes_if_expired();

-- Create a function to automatically expire Pro subscriptions
CREATE OR REPLACE FUNCTION check_pro_expiration()
RETURNS void AS $$
BEGIN
    UPDATE users
    SET is_pro = FALSE,
        likes_remaining = 6  -- 过期后恢复为普通用户的 6 次点赞
    WHERE is_pro = TRUE 
    AND pro_end IS NOT NULL 
    AND pro_end < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Optional: Create a scheduled job to check Pro expirations (requires pg_cron extension)
-- If you have pg_cron enabled, uncomment the following:
-- SELECT cron.schedule('check-pro-expiration', '0 * * * *', 'SELECT check_pro_expiration();');

-- Verify the changes
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('is_pro', 'pro_start', 'pro_end', 'likes_remaining', 'likes_depleted_at')
ORDER BY column_name;

COMMENT ON COLUMN users.is_pro IS 'Whether the user has active Pro subscription';
COMMENT ON COLUMN users.pro_start IS 'Timestamp when Pro subscription started';
COMMENT ON COLUMN users.pro_end IS 'Timestamp when Pro subscription ends';
COMMENT ON COLUMN users.likes_remaining IS 'Number of likes remaining for non-Pro users (resets to 6 after 24h)';
COMMENT ON COLUMN users.likes_depleted_at IS 'Timestamp when likes were depleted to 0';

