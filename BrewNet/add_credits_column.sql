-- Add credits column to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS credits INTEGER DEFAULT 0;

-- Optional: Add an index if you frequently query by credits
CREATE INDEX IF NOT EXISTS idx_users_credits
ON users(credits);

-- Optional: Add a comment to document the column
COMMENT ON COLUMN users.credits IS 'Total credits earned from completed coffee chats (10 credits per completed chat)';

