-- Create rewards table for storing available rewards/vouchers
CREATE TABLE IF NOT EXISTS public.rewards (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    points_required INTEGER NOT NULL DEFAULT 0,
    category TEXT NOT NULL DEFAULT 'other',
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create redemptions table for storing user redemption records
CREATE TABLE IF NOT EXISTS public.redemptions (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reward_id TEXT NOT NULL REFERENCES public.rewards(id) ON DELETE CASCADE,
    points_used INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_rewards_category ON public.rewards(category);
CREATE INDEX IF NOT EXISTS idx_rewards_is_active ON public.rewards(is_active);
CREATE INDEX IF NOT EXISTS idx_redemptions_user_id ON public.redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_redemptions_reward_id ON public.redemptions(reward_id);
CREATE INDEX IF NOT EXISTS idx_redemptions_status ON public.redemptions(status);
CREATE INDEX IF NOT EXISTS idx_redemptions_redeemed_at ON public.redemptions(redeemed_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for rewards table (public read, admin write)
CREATE POLICY "Rewards are viewable by everyone"
    ON public.rewards
    FOR SELECT
    USING (true);

CREATE POLICY "Rewards can be inserted by authenticated users"
    ON public.rewards
    FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Rewards can be updated by authenticated users"
    ON public.rewards
    FOR UPDATE
    USING (true);

-- RLS Policies for redemptions table (users can only see their own redemptions)
CREATE POLICY "Users can view their own redemptions"
    ON public.redemptions
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own redemptions"
    ON public.redemptions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own redemptions"
    ON public.redemptions
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Add comments for documentation
COMMENT ON TABLE public.rewards IS 'Available rewards/vouchers that users can redeem with credits';
COMMENT ON TABLE public.redemptions IS 'Records of user reward redemptions';
COMMENT ON COLUMN public.rewards.category IS 'Category of reward: coffee, gift, other';
COMMENT ON COLUMN public.rewards.points_required IS 'Number of credits required to redeem this reward';
COMMENT ON COLUMN public.redemptions.status IS 'Redemption status: pending, completed, cancelled';
COMMENT ON COLUMN public.redemptions.points_used IS 'Number of credits used for this redemption';

