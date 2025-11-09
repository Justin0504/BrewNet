-- Fix is_verified typing by converting boolean values to integers (0/1)

-- 1. Ensure existing data uses integers
ALTER TABLE public.user_features
    ALTER COLUMN is_verified DROP DEFAULT;

ALTER TABLE public.user_features
    ALTER COLUMN is_verified TYPE INTEGER
    USING CASE
        WHEN is_verified IS TRUE THEN 1
        ELSE 0
    END;

ALTER TABLE public.user_features
    ALTER COLUMN is_verified SET DEFAULT 0;

UPDATE public.user_features
SET is_verified = 0
WHERE is_verified IS NULL;

-- 2. Sync function: always persist 0/1 instead of boolean
CREATE OR REPLACE FUNCTION public.sync_user_features()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_features (
        user_id,
        location,
        time_zone,
        industry,
        experience_level,
        career_stage,
        main_intention,
        additional_intentions,
        sub_intentions,
        languages,
        skills,
        skills_to_learn,
        skills_to_teach,
        values,
        hobbies,
        years_of_experience,
        is_verified,
        updated_at
    )
    VALUES (
        NEW.user_id,
        NEW.core_identity->>'location',
        NEW.core_identity->>'time_zone',
        NEW.professional_background->>'industry',
        NEW.professional_background->>'experience_level',
        NEW.professional_background->>'career_stage',
        NEW.networking_intention->>'selected_intention',
        COALESCE(
            ARRAY(
                SELECT value::text
                FROM jsonb_array_elements_text(NEW.networking_intention->'additional_intentions')
            ),
            ARRAY[]::text[]
        ),
        COALESCE(
            ARRAY(
                SELECT value::text
                FROM jsonb_array_elements_text(NEW.networking_intention->'selected_sub_intentions')
            ),
            ARRAY[]::text[]
        ),
        COALESCE(
            ARRAY(
                SELECT value::text
                FROM jsonb_array_elements_text(NEW.professional_background->'languages_spoken')
            ),
            ARRAY[]::text[]
        ),
        COALESCE(
            ARRAY(
                SELECT value::text
                FROM jsonb_array_elements_text(NEW.professional_background->'skills')
            ),
            ARRAY[]::text[]
        ),
        COALESCE(
            ARRAY(
                SELECT elem->>'skill_name'
                FROM jsonb_array_elements(NEW.networking_intention->'skill_development'->'skills') AS elem
                WHERE elem->>'learn_in' = 'true'
            ),
            ARRAY[]::text[]
        ),
        COALESCE(
            ARRAY(
                SELECT elem->>'skill_name'
                FROM jsonb_array_elements(NEW.networking_intention->'skill_development'->'skills') AS elem
                WHERE elem->>'guide_in' = 'true'
            ),
            ARRAY[]::text[]
        ),
        COALESCE(
            ARRAY(
                SELECT value::text
                FROM jsonb_array_elements_text(NEW.personality_social->'values_tags')
            ),
            ARRAY[]::text[]
        ),
        COALESCE(
            ARRAY(
                SELECT value::text
                FROM jsonb_array_elements_text(NEW.personality_social->'hobbies')
            ),
            ARRAY[]::text[]
        ),
        COALESCE((NEW.professional_background->>'years_of_experience')::numeric, 0),
        CASE
            WHEN NEW.privacy_trust->>'verified_status' IN ('verifiedProfessional', 'verified') THEN 1
            ELSE 0
        END,
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET
        location = EXCLUDED.location,
        time_zone = EXCLUDED.time_zone,
        industry = EXCLUDED.industry,
        experience_level = EXCLUDED.experience_level,
        career_stage = EXCLUDED.career_stage,
        main_intention = EXCLUDED.main_intention,
        additional_intentions = EXCLUDED.additional_intentions,
        sub_intentions = EXCLUDED.sub_intentions,
        languages = EXCLUDED.languages,
        skills = EXCLUDED.skills,
        skills_to_learn = EXCLUDED.skills_to_learn,
        skills_to_teach = EXCLUDED.skills_to_teach,
        values = EXCLUDED.values,
        hobbies = EXCLUDED.hobbies,
        years_of_experience = EXCLUDED.years_of_experience,
        is_verified = EXCLUDED.is_verified,
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. (Optional) invalidate recommendation cache if needed
DELETE FROM public.recommendation_cache;
