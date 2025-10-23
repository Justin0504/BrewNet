-- Create profiles table SQL script
-- Execute this in Supabase Dashboard SQL Editor

-- Create profiles table with JSONB columns for complex profile data
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    core_identity JSONB NOT NULL,
    professional_background JSONB NOT NULL,
    networking_intent JSONB NOT NULL,
    personality_social JSONB NOT NULL,
    privacy_trust JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create policies for profiles table
CREATE POLICY "Users can view their own profile" ON profiles 
    FOR SELECT USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can insert their own profile" ON profiles 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Users can update their own profile" ON profiles 
    FOR UPDATE USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can delete their own profile" ON profiles 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample profile data for testing
INSERT INTO profiles (
    user_id,
    core_identity,
    professional_background,
    networking_intent,
    personality_social,
    privacy_trust
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    '{
        "name": "BrewNet Team",
        "email": "test@brewnet.com",
        "phone_number": null,
        "profile_image": null,
        "bio": "Building the future of professional networking",
        "pronouns": "they/them",
        "location": "San Francisco, CA",
        "personal_website": "https://brewnet.com",
        "github_url": "https://github.com/brewnet",
        "linkedin_url": "https://linkedin.com/company/brewnet",
        "time_zone": "America/Los_Angeles",
        "available_timeslot": {
            "sunday": {"morning": false, "noon": false, "afternoon": true, "evening": true, "night": false},
            "monday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "tuesday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "wednesday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "thursday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "friday": {"morning": true, "noon": true, "afternoon": true, "evening": true, "night": false},
            "saturday": {"morning": false, "noon": false, "afternoon": true, "evening": true, "night": false}
        }
    }',
    '{
        "current_company": "BrewNet",
        "job_title": "Founder & CEO",
        "industry": "Technology",
        "experience_level": "Senior",
        "education": "Computer Science, Stanford University",
        "years_of_experience": 8.0,
        "career_stage": "Founder",
        "skills": ["Swift", "iOS Development", "Product Management", "Leadership"],
        "certifications": ["AWS Certified", "Google Cloud Professional"],
        "languages_spoken": ["English", "Spanish"],
        "work_experiences": [
            {
                "company": "BrewNet",
                "position": "Founder & CEO",
                "start_date": "2020-01-01",
                "end_date": null,
                "description": "Building the future of professional networking"
            }
        ]
    }',
    '{
        "networking_intent": ["Find collaborators", "Share knowledge", "Build professional network"],
        "conversation_topics": ["Technology", "Startups", "Product Development", "Leadership"],
        "collaboration_interest": ["Startup ideas", "Side projects", "Mentoring"],
        "coffee_chat_goal": "Connect with like-minded professionals and explore collaboration opportunities",
        "preferred_chat_format": "Virtual",
        "available_timeslot": {
            "sunday": {"morning": false, "noon": false, "afternoon": true, "evening": true, "night": false},
            "monday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "tuesday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "wednesday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "thursday": {"morning": true, "noon": true, "afternoon": true, "evening": false, "night": false},
            "friday": {"morning": true, "noon": true, "afternoon": true, "evening": true, "night": false},
            "saturday": {"morning": false, "noon": false, "afternoon": true, "evening": true, "night": false}
        },
        "preferred_chat_duration": "30-45 minutes",
        "intro_prompt_answers": [
            {
                "prompt": "What''s your biggest professional challenge right now?",
                "answer": "Scaling our team while maintaining our company culture and product quality."
            },
            {
                "prompt": "What are you most excited about in your field?",
                "answer": "The potential for AI to revolutionize how professionals connect and collaborate."
            }
        ]
    }',
    '{
        "icebreaker_prompts": [
            {
                "prompt": "What''s the best piece of advice you''ve received?",
                "answer": "Always hire people who are smarter than you and give them the space to excel."
            },
            {
                "prompt": "What''s something you''re passionate about outside of work?",
                "answer": "I love hiking and photography - it helps me think clearly and stay creative."
            }
        ],
        "values_tags": ["Innovation", "Collaboration", "Transparency", "Growth"],
        "hobbies": ["Hiking", "Photography", "Reading", "Cooking"],
        "preferred_meeting_vibe": "Goal-driven",
        "communication_style": "Direct"
    }',
    '{
        "visibility_settings": {
            "company": "public",
            "email": "private",
            "phone_number": "private",
            "location": "public",
            "skills": "public",
            "interests": "public"
        },
        "verified_status": "verified_professional",
        "data_sharing_consent": true,
        "report_preferences": {
            "allow_reports": true,
            "report_categories": ["Inappropriate content", "Spam", "Harassment"]
        }
    }'
) ON CONFLICT (user_id) DO NOTHING;

-- Show creation result
SELECT 'Profiles table created successfully!' as status;
