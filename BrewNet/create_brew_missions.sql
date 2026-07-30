-- Brew Agent: standing missions (Stage 3 cloud sync)
-- Stage 2 ships with local-first storage (BrewMemoryStore / UserDefaults).
-- Run this in Supabase SQL Editor when enabling server-side proactive runs
-- (cron + push notifications), then sync BrewMemoryStore to this table.

CREATE TABLE IF NOT EXISTS brew_missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    goal TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',          -- active | paused | done
    preferences JSONB NOT NULL DEFAULT '[]'::jsonb, -- learned preference notes
    sent_invite_names JSONB NOT NULL DEFAULT '[]'::jsonb,
    declined_names JSONB NOT NULL DEFAULT '[]'::jsonb,
    times_run INTEGER NOT NULL DEFAULT 0,
    last_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_brew_missions_user ON brew_missions(user_id);
CREATE INDEX IF NOT EXISTS idx_brew_missions_due
    ON brew_missions(status, last_run_at) WHERE status = 'active';

ALTER TABLE brew_missions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own missions" ON brew_missions
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
