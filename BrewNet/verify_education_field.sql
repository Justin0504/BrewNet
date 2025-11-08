-- 验证和测试 education 字段存储的 SQL 脚本

-- 1. 检查 profiles 表的 professional_background 字段
SELECT 
    user_id,
    professional_background->>'education' as old_education_field,
    professional_background->'educations' as educations_array,
    jsonb_array_length(
        CASE 
            WHEN jsonb_typeof(professional_background->'educations') = 'array' 
            THEN professional_background->'educations'
            ELSE '[]'::jsonb
        END
    ) as educations_count,
    created_at,
    updated_at
FROM profiles
ORDER BY updated_at DESC
LIMIT 10;

-- 2. 查看 professional_background 的完整结构示例
SELECT 
    user_id,
    jsonb_pretty(professional_background) as professional_background_json
FROM profiles
WHERE professional_background IS NOT NULL
LIMIT 3;

-- 3. 检查是否有任何 educations 数据
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN professional_background->'educations' IS NOT NULL THEN 1 END) as profiles_with_educations_field,
    COUNT(CASE WHEN jsonb_array_length(
        CASE 
            WHEN jsonb_typeof(professional_background->'educations') = 'array' 
            THEN professional_background->'educations'
            ELSE '[]'::jsonb
        END
    ) > 0 THEN 1 END) as profiles_with_educations_data
FROM profiles;

-- 4. 测试更新：添加示例 education 数据（不会真正执行，只是示例）
/*
UPDATE profiles
SET professional_background = jsonb_set(
    professional_background,
    '{educations}',
    '[
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "school_name": "Stanford University",
            "start_year": 2016,
            "end_year": 2020,
            "degree": "Bachelor'\''s",
            "field_of_study": "Computer Science"
        }
    ]'::jsonb,
    true
)
WHERE user_id = 'YOUR_USER_ID_HERE';
*/

-- 5. 验证 JSONB 字段可以存储 educations 数组
SELECT 
    '{
        "current_company": "Google",
        "job_title": "Engineer",
        "education": "MIT",
        "educations": [
            {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "school_name": "MIT",
                "start_year": 2016,
                "end_year": 2020,
                "degree": "Bachelor'\''s",
                "field_of_study": "Computer Science"
            }
        ],
        "skills": ["Swift", "iOS"],
        "certifications": [],
        "languages_spoken": ["English"],
        "work_experiences": []
    }'::jsonb as test_json;

-- 6. 检查特定用户的 education 数据
-- 替换 'YOUR_USER_ID' 为实际的用户 ID
/*
SELECT 
    user_id,
    professional_background->'education' as old_education,
    professional_background->'educations' as new_educations,
    jsonb_pretty(professional_background) as full_data
FROM profiles
WHERE user_id = 'YOUR_USER_ID';
*/

-- 7. 统计各字段的存在情况
SELECT 
    'education (old)' as field_name,
    COUNT(*) as count,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM profiles) as percentage
FROM profiles
WHERE professional_background->>'education' IS NOT NULL
UNION ALL
SELECT 
    'educations (new)' as field_name,
    COUNT(*) as count,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM profiles) as percentage
FROM profiles
WHERE professional_background->'educations' IS NOT NULL
UNION ALL
SELECT 
    'educations with data' as field_name,
    COUNT(*) as count,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM profiles) as percentage
FROM profiles
WHERE jsonb_array_length(
    CASE 
        WHEN jsonb_typeof(professional_background->'educations') = 'array' 
        THEN professional_background->'educations'
        ELSE '[]'::jsonb
    END
) > 0;

