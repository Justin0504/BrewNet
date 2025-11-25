-- 更新 profiles 表中所有记录的 privacy_trust.visibility_settings.timeslot 为 "public"
-- 
-- 这个脚本会：
-- 1. 检查 privacy_trust 是否存在
-- 2. 检查 visibility_settings 是否存在
-- 3. 更新 timeslot 字段为 "public"
-- 4. 保留其他字段不变

UPDATE profiles
SET privacy_trust = jsonb_set(
    COALESCE(privacy_trust, '{}'::jsonb),
    '{visibility_settings,timeslot}',
    '"public"',
    true
)
WHERE privacy_trust IS NOT NULL
  AND privacy_trust ? 'visibility_settings';

-- 如果 privacy_trust 存在但没有 visibility_settings，则添加它
UPDATE profiles
SET privacy_trust = jsonb_set(
    COALESCE(privacy_trust, '{}'::jsonb),
    '{visibility_settings}',
    COALESCE(privacy_trust->'visibility_settings', '{}'::jsonb) || '{"timeslot": "public"}'::jsonb,
    true
)
WHERE privacy_trust IS NOT NULL
  AND NOT (privacy_trust ? 'visibility_settings');

-- 验证更新结果（可选，用于检查）
-- SELECT 
--     user_id,
--     privacy_trust->'visibility_settings'->>'timeslot' as timeslot_value
-- FROM profiles
-- WHERE privacy_trust IS NOT NULL
-- ORDER BY user_id;

