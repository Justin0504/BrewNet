-- =====================================================
-- BrewNet Headhunting 数据库升级脚本 V2.0
-- 功能：支持全文搜索和向量检索
-- 创建日期：2024-11-21
-- =====================================================

-- ===== Phase 1: 全文搜索支持 =====

-- 1. 启用 PostgreSQL 全文搜索扩展（如果未启用）
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. 为 user_features 表添加搜索文本列
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'searchable_text') THEN
        ALTER TABLE user_features ADD COLUMN searchable_text TEXT;
        RAISE NOTICE 'Added searchable_text column to user_features table';
    END IF;

    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'searchable_text_tsv') THEN
        ALTER TABLE user_features ADD COLUMN searchable_text_tsv tsvector;
        RAISE NOTICE 'Added searchable_text_tsv column to user_features table';
    END IF;
    
    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'concept_tags') THEN
        ALTER TABLE user_features ADD COLUMN concept_tags JSONB DEFAULT '[]'::jsonb;
        RAISE NOTICE 'Added concept_tags column to user_features table';
    END IF;
END $$;

-- 3. 创建函数：从 profiles 表生成可搜索文本
CREATE OR REPLACE FUNCTION generate_searchable_text(user_id_param UUID)
RETURNS TEXT AS $$
DECLARE
    profile_data JSONB;
    searchable TEXT := '';
    v_core_identity JSONB;
    v_professional JSONB;
    v_personality JSONB;
    educations JSONB;
    experiences JSONB;
BEGIN
    -- 获取用户的 profile
    SELECT 
        p.core_identity,
        p.professional_background,
        p.personality_social
    INTO 
        v_core_identity,
        v_professional,
        v_personality
    FROM profiles p
    WHERE p.user_id = user_id_param;
    
    IF v_professional IS NULL THEN
        RETURN '';
    END IF;
    
    -- 提取核心字段（高权重区域）
    -- Zone A: Current Title, Company, Industry, Top Skills
    searchable := COALESCE(v_professional->>'job_title', '') || ' ' ||
                  COALESCE(v_professional->>'current_company', '') || ' ' ||
                  COALESCE(v_professional->>'industry', '') || ' ';
    
    -- 添加技能（前10个）
    IF v_professional->'skills' IS NOT NULL THEN
        searchable := searchable || 
            (SELECT string_agg(value::text, ' ') 
             FROM jsonb_array_elements_text(v_professional->'skills') 
             LIMIT 10) || ' ';
    END IF;
    
    -- Zone B: Bio, Location, Education, Past Experience
    IF v_core_identity IS NOT NULL THEN
        searchable := searchable ||
            COALESCE(v_core_identity->>'bio', '') || ' ' ||
            COALESCE(v_core_identity->>'location', '') || ' ' ||
            COALESCE(v_core_identity->>'name', '') || ' ';
    END IF;
    
    -- 教育经历
    educations := v_professional->'educations';
    IF educations IS NOT NULL THEN
        searchable := searchable ||
            (SELECT string_agg(
                COALESCE(edu->>'school_name', '') || ' ' ||
                COALESCE(edu->>'field_of_study', '') || ' ' ||
                COALESCE(edu->>'degree', ''),
                ' '
            ) FROM jsonb_array_elements(educations) edu) || ' ';
    END IF;
    
    -- 工作经历（最近5个）
    experiences := v_professional->'work_experiences';
    IF experiences IS NOT NULL THEN
        searchable := searchable ||
            (SELECT string_agg(
                COALESCE(exp_item->>'company_name', '') || ' ' ||
                COALESCE(exp_item->>'position', ''),
                ' '
            ) FROM (
                SELECT jsonb_array_elements(experiences) as exp_item LIMIT 5
            ) sub) || ' ';
    END IF;
    
    -- Zone C: Hobbies, Values
    IF v_personality IS NOT NULL THEN
        searchable := searchable ||
            COALESCE(v_personality->>'self_introduction', '') || ' ';
            
        IF v_personality->'hobbies' IS NOT NULL THEN
            searchable := searchable ||
                (SELECT string_agg(value::text, ' ') 
                 FROM jsonb_array_elements_text(v_personality->'hobbies')) || ' ';
        END IF;
        
        IF v_personality->'values_tags' IS NOT NULL THEN
            searchable := searchable ||
                (SELECT string_agg(value::text, ' ') 
                 FROM jsonb_array_elements_text(v_personality->'values_tags')) || ' ';
        END IF;
    END IF;
    
    RETURN lower(searchable);
END;
$$ LANGUAGE plpgsql;

-- 4. 创建函数：生成概念标签
CREATE OR REPLACE FUNCTION generate_concept_tags(user_id_param UUID)
RETURNS JSONB AS $$
DECLARE
    v_professional JSONB;
    current_company TEXT;
    educations JSONB;
    tags JSONB := '[]'::jsonb;
    school_name TEXT;
BEGIN
    -- 获取用户的 professional_background
    SELECT p.professional_background INTO v_professional
    FROM profiles p
    WHERE p.user_id = user_id_param;
    
    IF v_professional IS NULL THEN
        RETURN tags;
    END IF;
    
    -- 提取当前公司
    current_company := lower(COALESCE(v_professional->>'current_company', ''));
    
    -- 公司标签
    IF current_company LIKE '%google%' OR current_company LIKE '%alphabet%' OR
       current_company LIKE '%facebook%' OR current_company LIKE '%meta%' OR
       current_company LIKE '%amazon%' OR current_company LIKE '%apple%' OR
       current_company LIKE '%microsoft%' OR current_company LIKE '%netflix%' THEN
        tags := tags || '["tag_big_tech", "tag_faang"]'::jsonb;
    END IF;
    
    IF current_company LIKE '%mckinsey%' OR current_company LIKE '%bain%' OR 
       current_company LIKE '%bcg%' THEN
        tags := tags || '["tag_mbb", "tag_consulting"]'::jsonb;
    END IF;
    
    IF current_company LIKE '%goldman%' OR current_company LIKE '%morgan stanley%' OR
       current_company LIKE '%jpmorgan%' OR current_company LIKE '%blackrock%' THEN
        tags := tags || '"tag_finance"'::jsonb;
    END IF;
    
    IF current_company LIKE '%stripe%' OR current_company LIKE '%databricks%' OR
       current_company LIKE '%figma%' OR current_company LIKE '%notion%' THEN
        tags := tags || '["tag_unicorn", "tag_startup"]'::jsonb;
    END IF;
    
    IF current_company LIKE '%startup%' OR v_professional->>'career_stage' = 'founder' THEN
        tags := tags || '"tag_startup"'::jsonb;
    END IF;
    
    -- 学校标签
    educations := v_professional->'educations';
    IF educations IS NOT NULL THEN
        FOR school_name IN 
            SELECT lower(edu->>'school_name') 
            FROM jsonb_array_elements(educations) edu
        LOOP
            IF school_name LIKE '%harvard%' OR school_name LIKE '%yale%' OR 
               school_name LIKE '%princeton%' OR school_name LIKE '%columbia%' OR
               school_name LIKE '%penn%' OR school_name LIKE '%brown%' OR
               school_name LIKE '%dartmouth%' OR school_name LIKE '%cornell%' THEN
                tags := tags || '"tag_ivy_league"'::jsonb;
                EXIT;
            END IF;
        END LOOP;
    END IF;
    
    RETURN tags;
END;
$$ LANGUAGE plpgsql;

-- 5. 创建或更新触发器函数：自动维护搜索文本和概念标签
CREATE OR REPLACE FUNCTION update_searchable_text_trigger()
RETURNS TRIGGER AS $$
DECLARE
    profile_user_id UUID;
BEGIN
    -- 从 profiles 表获取 user_id
    IF TG_TABLE_NAME = 'profiles' THEN
        profile_user_id := NEW.user_id;
    ELSE
        profile_user_id := NEW.user_id;
    END IF;
    
    -- 更新 user_features 表
    UPDATE user_features
    SET 
        searchable_text = generate_searchable_text(profile_user_id),
        searchable_text_tsv = to_tsvector('english', generate_searchable_text(profile_user_id)),
        concept_tags = generate_concept_tags(profile_user_id),
        updated_at = NOW()
    WHERE user_id = profile_user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. 在 profiles 表上创建触发器（profile 更新时自动更新搜索文本）
DROP TRIGGER IF EXISTS trigger_update_searchable_text ON profiles;
CREATE TRIGGER trigger_update_searchable_text
AFTER INSERT OR UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_searchable_text_trigger();

-- 7. 创建全文搜索索引（GIN 索引）
CREATE INDEX IF NOT EXISTS idx_user_features_searchable_text_gin 
ON user_features 
USING gin(searchable_text_tsv);

-- 8. 创建 Trigram 索引（用于模糊搜索）
CREATE INDEX IF NOT EXISTS idx_user_features_searchable_text_trgm 
ON user_features 
USING gin(searchable_text gin_trgm_ops);

-- 9. 创建概念标签索引
CREATE INDEX IF NOT EXISTS idx_user_features_concept_tags 
ON user_features 
USING gin(concept_tags);

-- 10. 创建复合索引（用于过滤）
CREATE INDEX IF NOT EXISTS idx_user_features_location_industry 
ON user_features(location, industry);

CREATE INDEX IF NOT EXISTS idx_user_features_career_stage_experience 
ON user_features(career_stage, years_of_experience);

-- ===== Phase 2: 初始化现有数据 =====

-- 为所有现有用户生成搜索文本和概念标签
UPDATE user_features uf
SET 
    searchable_text = generate_searchable_text(uf.user_id),
    searchable_text_tsv = to_tsvector('english', generate_searchable_text(uf.user_id)),
    concept_tags = generate_concept_tags(uf.user_id),
    updated_at = NOW()
WHERE EXISTS (
    SELECT 1 FROM profiles p WHERE p.user_id = uf.user_id
);

-- ===== Phase 3: 优化查询性能 =====

-- 1. 分析表统计信息
ANALYZE user_features;
ANALYZE profiles;

-- 2. 创建辅助函数：全文搜索（供 Swift 调用）
CREATE OR REPLACE FUNCTION headhunting_fulltext_search(
    search_query TEXT,
    exclude_user_ids UUID[] DEFAULT ARRAY[]::UUID[],
    limit_count INTEGER DEFAULT 200
)
RETURNS TABLE(
    user_id UUID,
    searchable_text TEXT,
    concept_tags JSONB,
    rank_score REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uf.user_id,
        uf.searchable_text,
        uf.concept_tags,
        ts_rank(uf.searchable_text_tsv, plainto_tsquery('english', search_query)) as rank_score
    FROM user_features uf
    WHERE 
        uf.searchable_text_tsv @@ plainto_tsquery('english', search_query)
        AND uf.user_id <> ALL(exclude_user_ids)
    ORDER BY rank_score DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- 3. 创建辅助函数：按学校搜索
CREATE OR REPLACE FUNCTION headhunting_search_by_school(
    school_name TEXT,
    exclude_user_ids UUID[] DEFAULT ARRAY[]::UUID[],
    limit_count INTEGER DEFAULT 100
)
RETURNS TABLE(user_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT p.user_id
    FROM profiles p,
         jsonb_array_elements(p.professional_background->'educations') AS edu
    WHERE 
        lower(edu->>'school_name') LIKE '%' || lower(school_name) || '%'
        AND p.user_id <> ALL(exclude_user_ids)
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- 4. 创建辅助函数：按公司搜索
CREATE OR REPLACE FUNCTION headhunting_search_by_company(
    company_name TEXT,
    exclude_user_ids UUID[] DEFAULT ARRAY[]::UUID[],
    limit_count INTEGER DEFAULT 100
)
RETURNS TABLE(user_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT p.user_id
    FROM profiles p
    WHERE 
        lower(p.professional_background->>'current_company') LIKE '%' || lower(company_name) || '%'
        AND p.user_id <> ALL(exclude_user_ids)
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- 5. 创建辅助函数：按概念标签搜索
CREATE OR REPLACE FUNCTION headhunting_search_by_concept(
    concept_tag TEXT,
    exclude_user_ids UUID[] DEFAULT ARRAY[]::UUID[],
    limit_count INTEGER DEFAULT 100
)
RETURNS TABLE(user_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT uf.user_id
    FROM user_features uf
    WHERE 
        uf.concept_tags ? concept_tag
        AND uf.user_id <> ALL(exclude_user_ids)
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- ===== Phase 4: 向量检索支持（可选，需要 pgvector 扩展） =====

-- 注意：这部分是可选的，需要先安装 pgvector 扩展
-- 如果你的 Supabase 实例支持 pgvector，可以执行以下语句

/*
-- 1. 启用 pgvector 扩展
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. 添加向量列
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.columns
                   WHERE table_name = 'user_features' AND column_name = 'profile_embedding') THEN
        ALTER TABLE user_features ADD COLUMN profile_embedding vector(768);
        RAISE NOTICE 'Added profile_embedding column to user_features table';
    END IF;
END $$;

-- 3. 创建向量索引（使用 IVFFlat 或 HNSW）
CREATE INDEX IF NOT EXISTS idx_user_features_embedding_ivfflat 
ON user_features 
USING ivfflat (profile_embedding vector_cosine_ops)
WITH (lists = 100);

-- 或者使用更快的 HNSW 索引（需要 pgvector >= 0.5.0）
-- CREATE INDEX IF NOT EXISTS idx_user_features_embedding_hnsw 
-- ON user_features 
-- USING hnsw (profile_embedding vector_cosine_ops);

-- 4. 创建向量检索函数
CREATE OR REPLACE FUNCTION headhunting_vector_search(
    query_embedding vector(768),
    exclude_user_ids UUID[] DEFAULT ARRAY[]::UUID[],
    limit_count INTEGER DEFAULT 100
)
RETURNS TABLE(
    user_id UUID,
    similarity DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uf.user_id,
        1 - (uf.profile_embedding <=> query_embedding) as similarity
    FROM user_features uf
    WHERE 
        uf.profile_embedding IS NOT NULL
        AND uf.user_id <> ALL(exclude_user_ids)
    ORDER BY uf.profile_embedding <=> query_embedding
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;
*/

-- ===== Phase 5: 性能优化索引 =====

-- 为常用过滤字段创建索引
CREATE INDEX IF NOT EXISTS idx_user_features_activity_connect 
ON user_features(activity_score, connect_score)
WHERE activity_score >= 3 AND connect_score >= 3;

CREATE INDEX IF NOT EXISTS idx_profiles_user_id 
ON profiles(user_id);

-- 创建物化视图（用于快速全文搜索）
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_searchable_profiles AS
SELECT 
    uf.user_id,
    uf.searchable_text,
    uf.searchable_text_tsv,
    uf.concept_tags,
    uf.location,
    uf.industry,
    uf.career_stage,
    uf.years_of_experience,
    uf.activity_score,
    uf.connect_score,
    uf.mentor_score,
    p.professional_background,
    p.core_identity
FROM user_features uf
JOIN profiles p ON p.user_id = uf.user_id
WHERE 
    p.professional_background IS NOT NULL
    AND p.core_identity IS NOT NULL;

-- 在物化视图上创建索引
CREATE INDEX IF NOT EXISTS idx_mv_searchable_tsv 
ON mv_searchable_profiles 
USING gin(searchable_text_tsv);

CREATE INDEX IF NOT EXISTS idx_mv_concept_tags 
ON mv_searchable_profiles 
USING gin(concept_tags);

-- 创建刷新物化视图的函数（定期调用）
CREATE OR REPLACE FUNCTION refresh_searchable_profiles()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_searchable_profiles;
    RAISE NOTICE 'Materialized view refreshed';
END;
$$ LANGUAGE plpgsql;

-- ===== 验证 =====

-- 检查索引是否创建成功
SELECT 
    tablename, 
    indexname, 
    indexdef 
FROM pg_indexes 
WHERE tablename IN ('user_features', 'mv_searchable_profiles')
ORDER BY tablename, indexname;

-- 检查触发器是否创建成功
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'profiles'
ORDER BY event_object_table, trigger_name;

-- 测试搜索函数
SELECT * FROM headhunting_fulltext_search('stanford product manager', ARRAY[]::UUID[], 10);

-- 统计信息
SELECT 
    'Total profiles' as metric,
    COUNT(*) as value
FROM profiles
UNION ALL
SELECT 
    'Profiles with searchable text' as metric,
    COUNT(*) as value
FROM user_features
WHERE searchable_text IS NOT NULL
UNION ALL
SELECT 
    'Profiles with concept tags' as metric,
    COUNT(*) as value
FROM user_features
WHERE jsonb_array_length(concept_tags) > 0;

-- ===== 使用示例 =====

/*
-- 1. 全文搜索示例
SELECT * FROM headhunting_fulltext_search(
    'stanford alumni product manager',
    ARRAY['current-user-uuid']::UUID[],  -- 排除当前用户
    50  -- 返回50个结果
);

-- 2. 按学校搜索示例
SELECT * FROM headhunting_search_by_school(
    'stanford',
    ARRAY['current-user-uuid']::UUID[],
    50
);

-- 3. 按公司搜索示例
SELECT * FROM headhunting_search_by_company(
    'google',
    ARRAY['current-user-uuid']::UUID[],
    50
);

-- 4. 按概念标签搜索示例
SELECT * FROM headhunting_search_by_concept(
    'tag_big_tech',
    ARRAY['current-user-uuid']::UUID[],
    50
);

-- 5. 组合搜索示例（全文 + 概念标签）
SELECT DISTINCT uf.user_id
FROM user_features uf
WHERE 
    (uf.searchable_text_tsv @@ plainto_tsquery('english', 'product manager') OR
     uf.concept_tags ? 'tag_big_tech')
    AND uf.user_id != 'current-user-uuid'
LIMIT 100;
*/

-- ===== 维护任务 =====

-- 定期刷新物化视图（建议每小时或每天执行一次）
-- SELECT refresh_searchable_profiles();

-- 重建索引（如果性能下降）
-- REINDEX INDEX CONCURRENTLY idx_user_features_searchable_text_gin;

-- 更新统计信息
-- ANALYZE user_features;

-- 显示完成信息
DO $$
BEGIN
    RAISE NOTICE '✅ Headhunting database upgrade completed!';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Verify indexes: SELECT * FROM pg_indexes WHERE tablename = ''user_features'';';
    RAISE NOTICE '2. Test search: SELECT * FROM headhunting_fulltext_search(''test query'', ARRAY[]::UUID[], 10);';
    RAISE NOTICE '3. Schedule materialized view refresh (recommended: hourly)';
END $$;
