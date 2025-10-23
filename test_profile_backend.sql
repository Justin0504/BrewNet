-- Test Profile Backend SQL Script
-- Execute this in Supabase Dashboard SQL Editor to test profile functionality

-- 1. Test creating a profile
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
        "name": "Test User",
        "email": "test@example.com",
        "phone_number": "+1234567890",
        "profile_image": "https://example.com/avatar.jpg",
        "bio": "Software engineer passionate about clean code and user experience",
        "pronouns": "they/them",
        "location": "San Francisco, CA",
        "personal_website": "https://testuser.dev",
        "github_url": "https://github.com/testuser",
        "linkedin_url": "https://linkedin.com/in/testuser",
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
        "current_company": "Tech Corp",
        "job_title": "Senior Software Engineer",
        "industry": "Technology",
        "experience_level": "Senior",
        "education": "Computer Science, MIT",
        "years_of_experience": 5.0,
        "career_stage": "Mid-level",
        "skills": ["Swift", "iOS Development", "React", "Node.js", "Python"],
        "certifications": ["AWS Certified Developer", "Google Cloud Professional"],
        "languages_spoken": ["English", "Spanish", "French"],
        "work_experiences": [
            {
                "company": "Tech Corp",
                "position": "Senior Software Engineer",
                "start_date": "2020-01-01",
                "end_date": null,
                "description": "Leading mobile app development team"
            },
            {
                "company": "StartupXYZ",
                "position": "Software Engineer",
                "start_date": "2018-06-01",
                "end_date": "2019-12-31",
                "description": "Full-stack development for web applications"
            }
        ]
    }',
    '{
        "networking_intent": ["Find collaborators", "Share knowledge", "Build professional network"],
        "conversation_topics": ["Technology", "Mobile Development", "Startups", "Career Growth"],
        "collaboration_interest": ["Side projects", "Mentoring", "Open source"],
        "coffee_chat_goal": "Connect with other developers and explore new opportunities",
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
                "answer": "Balancing technical debt with new feature development while maintaining team velocity."
            },
            {
                "prompt": "What are you most excited about in your field?",
                "answer": "The potential for AI to revolutionize mobile app development and user experience."
            }
        ]
    }',
    '{
        "icebreaker_prompts": [
            {
                "prompt": "What''s the best piece of advice you''ve received?",
                "answer": "Always write code as if the person maintaining it is a violent psychopath who knows where you live."
            },
            {
                "prompt": "What''s something you''re passionate about outside of work?",
                "answer": "I love rock climbing and photography - both require patience and problem-solving skills."
            }
        ],
        "values_tags": ["Innovation", "Collaboration", "Learning", "Quality"],
        "hobbies": ["Rock Climbing", "Photography", "Reading", "Cooking"],
        "preferred_meeting_vibe": "Goal-driven",
        "communication_style": "Direct"
    }',
    '{
        "visibility_settings": {
            "company": "public",
            "email": "connections_only",
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
) ON CONFLICT (user_id) DO UPDATE SET
    core_identity = EXCLUDED.core_identity,
    professional_background = EXCLUDED.professional_background,
    networking_intent = EXCLUDED.networking_intent,
    personality_social = EXCLUDED.personality_social,
    privacy_trust = EXCLUDED.privacy_trust,
    updated_at = NOW();

-- 2. Test querying a profile
SELECT 
    id,
    user_id,
    core_identity->>'name' as name,
    core_identity->>'email' as email,
    core_identity->>'bio' as bio,
    professional_background->>'job_title' as job_title,
    professional_background->>'current_company' as company,
    professional_background->'skills' as skills,
    created_at,
    updated_at
FROM profiles 
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000';

-- 3. Test searching profiles by name
SELECT 
    id,
    user_id,
    core_identity->>'name' as name,
    core_identity->>'bio' as bio,
    professional_background->>'job_title' as job_title
FROM profiles 
WHERE core_identity->>'name' ILIKE '%Test%';

-- 4. Test searching profiles by skills
SELECT 
    id,
    user_id,
    core_identity->>'name' as name,
    professional_background->>'job_title' as job_title,
    professional_background->'skills' as skills
FROM profiles 
WHERE professional_background->'skills' ? 'Swift';

-- 5. Test updating a profile
UPDATE profiles 
SET 
    core_identity = jsonb_set(core_identity, '{bio}', '"Updated bio: Passionate about creating amazing user experiences"'),
    updated_at = NOW()
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000';

-- 6. Verify the update
SELECT 
    id,
    user_id,
    core_identity->>'name' as name,
    core_identity->>'bio' as bio,
    updated_at
FROM profiles 
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000';

-- 7. Test profile completion calculation
SELECT 
    user_id,
    core_identity->>'name' as name,
    CASE 
        WHEN core_identity->>'name' IS NOT NULL AND core_identity->>'name' != '' THEN 1 ELSE 0 
    END +
    CASE 
        WHEN core_identity->>'email' IS NOT NULL AND core_identity->>'email' != '' THEN 1 ELSE 0 
    END +
    CASE 
        WHEN professional_background->'skills' IS NOT NULL AND jsonb_array_length(professional_background->'skills') > 0 THEN 1 ELSE 0 
    END +
    CASE 
        WHEN networking_intent->'networking_intent' IS NOT NULL AND jsonb_array_length(networking_intent->'networking_intent') > 0 THEN 1 ELSE 0 
    END +
    CASE 
        WHEN personality_social->'values_tags' IS NOT NULL AND jsonb_array_length(personality_social->'values_tags') > 0 THEN 1 ELSE 0 
    END as completion_score,
    (CASE 
        WHEN core_identity->>'name' IS NOT NULL AND core_identity->>'name' != '' THEN 1 ELSE 0 
    END +
    CASE 
        WHEN core_identity->>'email' IS NOT NULL AND core_identity->>'email' != '' THEN 1 ELSE 0 
    END +
    CASE 
        WHEN professional_background->'skills' IS NOT NULL AND jsonb_array_length(professional_background->'skills') > 0 THEN 1 ELSE 0 
    END +
    CASE 
        WHEN networking_intent->'networking_intent' IS NOT NULL AND jsonb_array_length(networking_intent->'networking_intent') > 0 THEN 1 ELSE 0 
    END +
    CASE 
        WHEN personality_social->'values_tags' IS NOT NULL AND jsonb_array_length(personality_social->'values_tags') > 0 THEN 1 ELSE 0 
    END) * 20.0 as completion_percentage
FROM profiles 
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000';

-- 8. Test getting all profiles (for recommendations)
SELECT 
    id,
    user_id,
    core_identity->>'name' as name,
    core_identity->>'bio' as bio,
    professional_background->>'job_title' as job_title,
    professional_background->>'current_company' as company,
    professional_background->'skills' as skills,
    created_at
FROM profiles 
ORDER BY created_at DESC
LIMIT 10;

-- 9. Test profile statistics
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN core_identity->>'name' IS NOT NULL AND core_identity->>'name' != '' THEN 1 END) as profiles_with_names,
    COUNT(CASE WHEN professional_background->'skills' IS NOT NULL AND jsonb_array_length(professional_background->'skills') > 0 THEN 1 END) as profiles_with_skills,
    COUNT(CASE WHEN networking_intent->'networking_intent' IS NOT NULL AND jsonb_array_length(networking_intent->'networking_intent') > 0 THEN 1 END) as profiles_with_networking_intent
FROM profiles;

-- 10. Clean up test data (optional)
-- DELETE FROM profiles WHERE user_id = '550e8400-e29b-41d4-a716-446655440000';

SELECT 'Profile backend test completed successfully!' as status;
