-- ========================================
-- Education 字段测试和修复 SQL 脚本
-- ========================================

-- 步骤 1: 验证表结构
-- professional_background 是 JSONB 类型，可以存储任何 JSON 数据
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles' 
    AND column_name = 'professional_background';

-- 步骤 2: 查看当前数据结构
-- 查看最近更新的 profiles，看看 professional_background 的完整结构
SELECT 
    user_id,
    jsonb_pretty(professional_background) as professional_background_structure,
    updated_at
FROM profiles
ORDER BY updated_at DESC
LIMIT 3;

-- 步骤 3: 检查 educations 字段是否存在
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN professional_background ? 'education' THEN 1 END) as has_old_education_field,
    COUNT(CASE WHEN professional_background ? 'educations' THEN 1 END) as has_new_educations_field,
    COUNT(CASE 
        WHEN jsonb_typeof(professional_background->'educations') = 'array' 
             AND jsonb_array_length(professional_background->'educations') > 0 
        THEN 1 
    END) as has_educations_with_data
FROM profiles;

-- 步骤 4: 测试添加 educations 数据（示例）
-- 这是一个测试查询，展示如何手动添加 educations 数据
-- 替换 'YOUR_USER_ID' 为实际用户 ID
/*
DO $$
DECLARE
    test_user_id UUID := 'YOUR_USER_ID';  -- 替换为实际用户 ID
BEGIN
    -- 更新用户的 professional_background，添加 educations 数组
    UPDATE profiles
    SET 
        professional_background = jsonb_set(
            COALESCE(professional_background, '{}'::jsonb),
            '{educations}',
            '[
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000",
                    "school_name": "Stanford University",
                    "start_year": 2016,
                    "end_year": 2020,
                    "degree": "Bachelor''s",
                    "field_of_study": "Computer Science"
                },
                {
                    "id": "660e8400-e29b-41d4-a716-446655440001",
                    "school_name": "Harvard University",
                    "start_year": 2020,
                    "end_year": 2022,
                    "degree": "Master''s",
                    "field_of_study": "Business Administration"
                }
            ]'::jsonb,
            true
        ),
        updated_at = NOW()
    WHERE user_id = test_user_id;
    
    -- 验证更新
    RAISE NOTICE 'Updated profile for user: %', test_user_id;
END $$;
*/

-- 步骤 5: 查看特定用户的数据
-- 替换 'YOUR_USER_ID' 为实际用户 ID 来查看该用户的数据
/*
SELECT 
    user_id,
    professional_background->>'current_company' as current_company,
    professional_background->>'job_title' as job_title,
    professional_background->>'education' as old_education,
    professional_background->'educations' as new_educations,
    jsonb_pretty(professional_background) as full_professional_background
FROM profiles
WHERE user_id = 'YOUR_USER_ID';
*/

-- 步骤 6: 批量检查所有用户的 educations 数据
SELECT 
    p.user_id,
    u.name as user_name,
    u.email,
    CASE 
        WHEN professional_background ? 'educations' THEN '有 educations 字段'
        ELSE '无 educations 字段'
    END as educations_field_status,
    CASE 
        WHEN jsonb_typeof(professional_background->'educations') = 'array' 
        THEN jsonb_array_length(professional_background->'educations')
        ELSE 0
    END as educations_count,
    professional_background->>'education' as old_education_value,
    p.updated_at
FROM profiles p
LEFT JOIN users u ON p.user_id = u.id
ORDER BY p.updated_at DESC
LIMIT 20;

-- 步骤 7: 创建一个函数来安全地添加 education
-- 这个函数可以在不覆盖现有数据的情况下添加新的 education
/*
CREATE OR REPLACE FUNCTION add_education_to_profile(
    p_user_id UUID,
    p_school_name TEXT,
    p_start_year INT,
    p_end_year INT,
    p_degree TEXT,
    p_field_of_study TEXT
) RETURNS void AS $$
DECLARE
    new_education jsonb;
    current_educations jsonb;
BEGIN
    -- 创建新的 education 对象
    new_education := jsonb_build_object(
        'id', gen_random_uuid(),
        'school_name', p_school_name,
        'start_year', p_start_year,
        'end_year', p_end_year,
        'degree', p_degree,
        'field_of_study', p_field_of_study
    );
    
    -- 获取当前的 educations 数组
    SELECT COALESCE(professional_background->'educations', '[]'::jsonb)
    INTO current_educations
    FROM profiles
    WHERE user_id = p_user_id;
    
    -- 添加新的 education 到数组
    current_educations := current_educations || new_education;
    
    -- 更新 profile
    UPDATE profiles
    SET 
        professional_background = jsonb_set(
            professional_background,
            '{educations}',
            current_educations,
            true
        ),
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    RAISE NOTICE 'Added education for user: %', p_user_id;
END;
$$ LANGUAGE plpgsql;
*/

-- 使用示例：
/*
SELECT add_education_to_profile(
    'YOUR_USER_ID'::UUID,
    'MIT',
    2016,
    2020,
    'Bachelor''s',
    'Computer Science'
);
*/

-- 步骤 8: 验证 JSONB 可以正确存储和检索 educations
-- 这是一个完整的测试 JSONB 结构
SELECT jsonb_pretty('{
    "current_company": "Google",
    "job_title": "Software Engineer",
    "industry": "Technology",
    "experience_level": "Mid",
    "education": "MIT · B.S. in Computer Science",
    "educations": [
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "school_name": "MIT",
            "start_year": 2016,
            "end_year": 2020,
            "degree": "Bachelor''s",
            "field_of_study": "Computer Science"
        },
        {
            "id": "660e8400-e29b-41d4-a716-446655440001",
            "school_name": "Stanford",
            "start_year": 2020,
            "end_year": null,
            "degree": "Master''s",
            "field_of_study": "Artificial Intelligence"
        }
    ],
    "years_of_experience": 5.0,
    "career_stage": "Mid-level",
    "skills": ["Swift", "iOS", "Python"],
    "certifications": [],
    "languages_spoken": ["English", "Mandarin"],
    "work_experiences": [
        {
            "id": "770e8400-e29b-41d4-a716-446655440002",
            "company_name": "Google",
            "start_year": 2020,
            "end_year": null,
            "position": "Software Engineer",
            "highlighted_skills": ["Swift", "iOS"],
            "responsibilities": "Develop iOS applications"
        }
    ]
}'::jsonb) as complete_professional_background_example;

-- 步骤 9: 诊断特定用户的问题
-- 这个查询帮助诊断为什么 educations 没有保存
/*
WITH user_check AS (
    SELECT 
        user_id,
        professional_background,
        professional_background ? 'educations' as has_educations_key,
        jsonb_typeof(professional_background->'educations') as educations_type,
        CASE 
            WHEN jsonb_typeof(professional_background->'educations') = 'array'
            THEN jsonb_array_length(professional_background->'educations')
            ELSE NULL
        END as educations_array_length
    FROM profiles
    WHERE user_id = 'YOUR_USER_ID'
)
SELECT 
    user_id,
    has_educations_key,
    educations_type,
    educations_array_length,
    CASE 
        WHEN NOT has_educations_key THEN '问题: educations 字段不存在'
        WHEN educations_type != 'array' THEN '问题: educations 不是数组类型'
        WHEN educations_array_length = 0 THEN '问题: educations 数组为空'
        WHEN educations_array_length IS NULL THEN '问题: educations 为 null'
        ELSE '正常: educations 有数据'
    END as diagnosis
FROM user_check;
*/

-- 步骤 10: 清理和重置（谨慎使用！）
-- 如果需要清除所有 educations 数据重新开始
/*
UPDATE profiles
SET professional_background = professional_background - 'educations'
WHERE professional_background ? 'educations';
*/

-- ========================================
-- 使用说明：
-- ========================================
-- 1. 首先运行步骤 1-3 来验证表结构和当前数据状态
-- 2. 运行步骤 6 查看所有用户的 educations 数据情况
-- 3. 如果需要手动添加测试数据，使用步骤 4（替换 YOUR_USER_ID）
-- 4. 使用步骤 5 查看特定用户的完整数据
-- 5. 如果需要批量操作，可以使用步骤 7 创建辅助函数
-- 6. 步骤 9 帮助诊断特定用户的问题
-- ========================================

