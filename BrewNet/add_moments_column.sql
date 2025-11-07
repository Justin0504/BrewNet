-- Add moments column to profiles table
-- This column stores user's moments (up to 6 photos with captions) as JSONB

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS moments JSONB;

-- Add a comment to document the column
COMMENT ON COLUMN profiles.moments IS 'User moments: array of up to 6 photos with captions. Structure: {"moments": [{"id": "uuid", "image_url": "string", "caption": "string"}]}';

-- Create an index for better query performance (optional, for filtering profiles with moments)
CREATE INDEX IF NOT EXISTS idx_profiles_moments ON profiles USING GIN (moments);

-- Note: The moments column is optional (nullable), so existing profiles will have NULL
-- Users can add moments during profile setup or edit

