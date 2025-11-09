-- 修复不完整的Profile数据
-- 确保所有必需字段都有有效值

-- 1. 修复缺失的core_identity字段
UPDATE profiles
SET core_identity = jsonb_set(
    COALESCE(core_identity, '{}'::jsonb),
    '{time_zone}',
    to_jsonb(COALESCE(core_identity->>'time_zone', 'America/Los_Angeles'))
)
WHERE core_identity IS NULL OR core_identity->>'time_zone' IS NULL;

-- 2. 修复缺失的professional_background.skills（空数组而不是null）
UPDATE profiles
SET professional_background = jsonb_set(
    professional_background,
    '{skills}',
    '[]'::jsonb
)
WHERE professional_background->'skills' IS NULL;

-- 3. 修复缺失的professional_background.certifications
UPDATE profiles
SET professional_background = jsonb_set(
    professional_background,
    '{certifications}',
    '[]'::jsonb
)
WHERE professional_background->'certifications' IS NULL;

-- 4. 修复缺失的professional_background.languages_spoken
UPDATE profiles
SET professional_background = jsonb_set(
    professional_background,
    '{languages_spoken}',
    '[]'::jsonb
)
WHERE professional_background->'languages_spoken' IS NULL;

-- 5. 修复缺失的professional_background.work_experiences
UPDATE profiles
SET professional_background = jsonb_set(
    professional_background,
    '{work_experiences}',
    '[]'::jsonb
)
WHERE professional_background->'work_experiences' IS NULL;

-- 6. 修复缺失的networking_intention.selected_sub_intentions（空数组而不是null）
UPDATE profiles
SET networking_intention = jsonb_set(
    networking_intention,
    '{selected_sub_intentions}',
    '[]'::jsonb
)
WHERE networking_intention->'selected_sub_intentions' IS NULL;

-- 7. 修复缺失的networking_intention.additional_intentions
UPDATE profiles
SET networking_intention = jsonb_set(
    networking_intention,
    '{additional_intentions}',
    '[]'::jsonb
)
WHERE networking_intention->'additional_intentions' IS NULL;

-- 8. 确保networking_preferences中有available_timeslot（如果在core_identity中，移动过来）
DO $$
DECLARE
    profile_record RECORD;
    timeslot_data jsonb;
BEGIN
    FOR profile_record IN 
        SELECT id, user_id, core_identity, networking_preferences
        FROM profiles
        WHERE core_identity ? 'available_timeslot'
           OR networking_preferences->'available_timeslot' IS NULL
    LOOP
        -- 如果networking_preferences缺少available_timeslot，但core_identity有
        IF profile_record.core_identity ? 'available_timeslot' THEN
            timeslot_data := profile_record.core_identity->'available_timeslot';
            
            -- 设置到networking_preferences
            UPDATE profiles
            SET networking_preferences = jsonb_set(
                networking_preferences,
                '{available_timeslot}',
                timeslot_data
            )
            WHERE id = profile_record.id;
            
            -- 从core_identity中移除
            UPDATE profiles
            SET core_identity = core_identity - 'available_timeslot'
            WHERE id = profile_record.id;
            
            RAISE NOTICE 'Moved available_timeslot from core_identity to networking_preferences for user %', profile_record.user_id;
        END IF;
        
        -- 如果networking_preferences仍然缺少available_timeslot，创建默认值
        IF (SELECT networking_preferences->'available_timeslot' FROM profiles WHERE id = profile_record.id) IS NULL THEN
            UPDATE profiles
            SET networking_preferences = jsonb_set(
                networking_preferences,
                '{available_timeslot}',
                '{
                    "sunday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "monday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "tuesday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "wednesday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "thursday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "friday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "saturday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false}
                }'::jsonb
            )
            WHERE id = profile_record.id;
            
            RAISE NOTICE 'Created default available_timeslot for user %', profile_record.user_id;
        END IF;
    END LOOP;
END $$;

-- 9. 修复personality_social中缺失的数组字段
UPDATE profiles
SET personality_social = jsonb_set(
    personality_social,
    '{icebreaker_prompts}',
    '[]'::jsonb
)
WHERE personality_social->'icebreaker_prompts' IS NULL;

UPDATE profiles
SET personality_social = jsonb_set(
    personality_social,
    '{values_tags}',
    '[]'::jsonb
)
WHERE personality_social->'values_tags' IS NULL;

UPDATE profiles
SET personality_social = jsonb_set(
    personality_social,
    '{hobbies}',
    '[]'::jsonb
)
WHERE personality_social->'hobbies' IS NULL;

-- 10. 确保personality_social有preferred_meeting_vibe（默认为Casual）
UPDATE profiles
SET personality_social = jsonb_set(
    personality_social,
    '{preferred_meeting_vibe}',
    '"Casual"'::jsonb
)
WHERE personality_social->>'preferred_meeting_vibe' IS NULL;

-- 11. 确保personality_social有preferred_meeting_vibes数组
UPDATE profiles
SET personality_social = jsonb_set(
    personality_social,
    '{preferred_meeting_vibes}',
    jsonb_build_array(personality_social->>'preferred_meeting_vibe')
)
WHERE personality_social->'preferred_meeting_vibes' IS NULL;

-- 12. 修复privacy_trust中缺失的字段
UPDATE profiles
SET privacy_trust = jsonb_set(
    COALESCE(privacy_trust, '{}'::jsonb),
    '{data_sharing_consent}',
    'false'::jsonb
)
WHERE privacy_trust IS NULL OR privacy_trust->'data_sharing_consent' IS NULL;

-- 13. 确保privacy_trust有visibility_settings
UPDATE profiles
SET privacy_trust = jsonb_set(
    privacy_trust,
    '{visibility_settings}',
    '{
        "company": "public",
        "email": "private",
        "phone_number": "private",
        "location": "public",
        "skills": "public",
        "interests": "public",
        "timeslot": "connections_only"
    }'::jsonb
)
WHERE privacy_trust->'visibility_settings' IS NULL;

-- 14. 确保privacy_trust有verified_status
UPDATE profiles
SET privacy_trust = jsonb_set(
    privacy_trust,
    '{verified_status}',
    '"unverified"'::jsonb
)
WHERE privacy_trust->>'verified_status' IS NULL;

-- 15. 确保privacy_trust有report_preferences
UPDATE profiles
SET privacy_trust = jsonb_set(
    privacy_trust,
    '{report_preferences}',
    '{
        "allow_reports": true,
        "report_categories": []
    }'::jsonb
)
WHERE privacy_trust->'report_preferences' IS NULL;

-- 16. 验证修复后的数据
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN 
        core_identity IS NOT NULL 
        AND professional_background IS NOT NULL 
        AND networking_intention IS NOT NULL 
        AND networking_preferences IS NOT NULL
        AND personality_social IS NOT NULL
        AND privacy_trust IS NOT NULL
        AND networking_preferences->'available_timeslot' IS NOT NULL
    THEN 1 END) as complete_profiles
FROM profiles;

-- 17. 列出仍然不完整的profiles
SELECT 
    user_id,
    core_identity->'name' as name,
    CASE WHEN core_identity IS NULL THEN '❌' ELSE '✅' END as has_core_identity,
    CASE WHEN professional_background IS NULL THEN '❌' ELSE '✅' END as has_professional_bg,
    CASE WHEN networking_intention IS NULL THEN '❌' ELSE '✅' END as has_networking_intention,
    CASE WHEN networking_preferences IS NULL THEN '❌' ELSE '✅' END as has_networking_prefs,
    CASE WHEN networking_preferences->'available_timeslot' IS NULL THEN '❌' ELSE '✅' END as has_timeslot,
    CASE WHEN personality_social IS NULL THEN '❌' ELSE '✅' END as has_personality_social,
    CASE WHEN privacy_trust IS NULL THEN '❌' ELSE '✅' END as has_privacy_trust
FROM profiles
WHERE 
    core_identity IS NULL 
    OR professional_background IS NULL 
    OR networking_intention IS NULL 
    OR networking_preferences IS NULL
    OR networking_preferences->'available_timeslot' IS NULL
    OR personality_social IS NULL
    OR privacy_trust IS NULL
ORDER BY updated_at DESC
LIMIT 20;

